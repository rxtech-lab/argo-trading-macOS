//
//  WalletService.swift
//  ArgoTradingSwift
//

import ArgoTrading
import Foundation
import UserNotifications

/// Shared access to the user's selected display currency. Engine callbacks
/// (which fire on background threads outside any view) read this to know
/// which currency to refetch with.
enum WalletDisplayPreferences {
    static let userDefaultsKey = "walletBaseCurrency"
    static let defaultCurrency = "USD"

    static var currentCurrency: String {
        UserDefaults.standard.string(forKey: userDefaultsKey) ?? defaultCurrency
    }
}

@MainActor
@Observable
final class WalletService {
    weak var tradingService: TradingService?

    var balance: WalletBalance?
    var buyingPower: WalletBalance?
    var assets: [WalletAsset] = []
    var orders: [WalletOrder] = []

    var supportedCurrencies: [String] = []
    var isLoading = false
    var lastError: String?
    var lastUpdated: Date?

    /// Number of orders received since the user last viewed the Orders tab.
    /// Reset to 0 by `markOrdersViewed()`. Drives the toolbar badge UI.
    var newOrdersCount: Int = 0

    private var seenOrderIDs: Set<String> = []
    private var hasLoadedOrdersBaseline = false

    private var refreshTask: Task<Void, Never>?
    private static let debounceInterval: Duration = .milliseconds(150)
    private static var hasRequestedNotificationAuthorization = false

    func loadSupportedCurrencies() {
        guard supportedCurrencies.isEmpty else { return }
        if let collection = SwiftargoGetSupportedBaseCurrencies() as? SwiftargoStringCollection {
            supportedCurrencies = collection.stringArray
        }
        if supportedCurrencies.isEmpty {
            supportedCurrencies = ["USD"]
        }
    }

    func clear() {
        refreshTask?.cancel()
        refreshTask = nil
        balance = nil
        buyingPower = nil
        assets = []
        orders = []
        isLoading = false
        lastError = nil
        lastUpdated = nil
        newOrdersCount = 0
        seenOrderIDs = []
        hasLoadedOrdersBaseline = false
    }

    /// Resets the new-orders badge. Call when the user opens the Orders tab.
    func markOrdersViewed() {
        newOrdersCount = 0
    }

    func scheduleRefresh(baseCurrency: String) {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            try? await Task.sleep(for: Self.debounceInterval)
            guard let self else { return }
            if Task.isCancelled { return }
            await self.refresh(baseCurrency: baseCurrency)
        }
    }

    func refresh(baseCurrency: String) async {
        guard let bridge = walletBridge() else {
            clear()
            return
        }

        let symbols = tradingService?.currentSymbols ?? []
        isLoading = true
        lastError = nil

        let outcome = await Self.fetch(bridge: bridge, baseCurrency: baseCurrency, symbols: symbols)
        if Task.isCancelled { return }

        isLoading = false
        lastUpdated = Date()

        if let buyingPower = outcome.buyingPower {
            self.buyingPower = buyingPower
        }
        if let balance = outcome.balance {
            self.balance = balance
        }
        if let assets = outcome.assets {
            self.assets = assets
        }
        if let orders = outcome.orders {
            self.orders = orders
            processOrderDiff(orders)
        }
        if let error = outcome.error {
            lastError = error
        }
    }

    /// Compares the refreshed order list against previously-seen IDs. On the
    /// first refresh we just take a baseline (no notifications). On later
    /// refreshes any order whose ID isn't in `seenOrderIDs` is treated as new,
    /// bumps the badge counter, and triggers a notification with sound.
    private func processOrderDiff(_ orders: [WalletOrder]) {
        let currentIDs = Set(orders.map(\.id))
        guard hasLoadedOrdersBaseline else {
            seenOrderIDs = currentIDs
            hasLoadedOrdersBaseline = true
            return
        }
        let newIDs = currentIDs.subtracting(seenOrderIDs)
        guard !newIDs.isEmpty else { return }

        seenOrderIDs.formUnion(currentIDs)
        newOrdersCount += newIDs.count
        let newOrders = orders.filter { newIDs.contains($0.id) }
        Task { await notify(newOrders: newOrders) }
    }

    private func notify(newOrders: [WalletOrder]) async {
        do {
            try await Self.requestNotificationAuthorizationIfNeeded()
        } catch {
            return
        }
        for order in newOrders {
            let content = UNMutableNotificationContent()
            let side = order.side.uppercased()
            content.title = String(localized: "Order \(side): \(order.symbol)")
            content.body = Self.notificationBody(for: order)
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "wallet-order-\(order.id)",
                content: content,
                trigger: nil
            )
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    private static func requestNotificationAuthorizationIfNeeded() async throws {
        guard !hasRequestedNotificationAuthorization else { return }
        _ = try await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
        hasRequestedNotificationAuthorization = true
    }

    private static func notificationBody(for order: WalletOrder) -> String {
        let qty = decimalFormatter.string(from: NSNumber(value: order.executedQty))
            ?? "\(order.executedQty)"
        let price = decimalFormatter.string(from: NSNumber(value: order.executedPrice))
            ?? "\(order.executedPrice)"
        return [
            "Status: \(order.status)",
            "Quantity: \(qty)",
            "Price: \(price)",
            "Time: \(timeFormatter.string(from: order.executedAt))",
        ].joined(separator: "\n")
    }

    private static let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 8
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()

    private func walletBridge() -> SwiftargoWalletBridge? {
        guard let engine = tradingService?.walletAccessibleEngine else { return nil }
        do {
            return try engine.wallet()
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    private struct FetchOutcome {
        var buyingPower: WalletBalance?
        var balance: WalletBalance?
        var assets: [WalletAsset]?
        var orders: [WalletOrder]?
        var error: String?
    }

    nonisolated private static func fetch(
        bridge: SwiftargoWalletBridge,
        baseCurrency: String,
        symbols: [String]
    ) async -> FetchOutcome {
        await Task.detached { () -> FetchOutcome in
            var outcome = FetchOutcome()
            var errors: [String] = []

            switch callBridge({ err in bridge.getBalanceJSON("buying_power", baseCurrency: baseCurrency, error: err) }) {
            case .success(let json):
                do { outcome.buyingPower = try decodeBalance(json) } catch {
                    errors.append("Buying power: \(error.localizedDescription)")
                }
            case .failure(let error):
                errors.append("Buying power: \(error.localizedDescription)")
            }

            switch callBridge({ err in bridge.getBalanceJSON("balance", baseCurrency: baseCurrency, error: err) }) {
            case .success(let json):
                do { outcome.balance = try decodeBalance(json) } catch {
                    errors.append("Balance: \(error.localizedDescription)")
                }
            case .failure(let error):
                errors.append("Balance: \(error.localizedDescription)")
            }

            switch callBridge({ err in bridge.getAssetsJSON(baseCurrency, error: err) }) {
            case .success(let json):
                do { outcome.assets = try decodeAssets(json) } catch {
                    errors.append("Assets: \(error.localizedDescription)")
                }
            case .failure(let error):
                errors.append("Assets: \(error.localizedDescription)")
            }

            outcome.orders = fetchOrders(bridge: bridge, symbols: symbols, errors: &errors)

            if !errors.isEmpty {
                outcome.error = errors.joined(separator: " · ")
            }
            return outcome
        }.value
    }

    nonisolated private static func fetchOrders(
        bridge: SwiftargoWalletBridge,
        symbols: [String],
        errors: inout [String]
    ) -> [WalletOrder] {
        let queries = symbols.isEmpty ? [""] : symbols
        var merged: [WalletOrder] = []
        for symbol in queries {
            let filterJSON: String
            if symbol.isEmpty {
                filterJSON = "{\"limit\":100}"
            } else {
                let escaped = symbol.replacingOccurrences(of: "\"", with: "\\\"")
                filterJSON = "{\"symbol\":\"\(escaped)\",\"limit\":100}"
            }
            switch callBridge({ err in bridge.getHistoricalOrdersJSON(filterJSON, error: err) }) {
            case .success(let json):
                do {
                    merged.append(contentsOf: try decodeOrders(json))
                } catch {
                    errors.append("Orders[\(symbol.isEmpty ? "*" : symbol)]: \(error.localizedDescription)")
                }
            case .failure(let error):
                errors.append("Orders[\(symbol.isEmpty ? "*" : symbol)]: \(error.localizedDescription)")
            }
        }
        return merged.sorted { $0.executedAt > $1.executedAt }
    }

    /// Wraps a `(NSErrorPointer) -> String` bridge call into a Swift Result.
    /// gomobile-generated `NSString * _Nonnull` selectors can't auto-bridge
    /// to `throws`, so we adopt the `NSError**` pattern manually.
    nonisolated private static func callBridge(_ block: (NSErrorPointer) -> String) -> Result<String, NSError> {
        var error: NSError?
        let result = block(&error)
        if let error {
            return .failure(error)
        }
        return .success(result)
    }

    nonisolated private static func decodeBalance(_ json: String) throws -> WalletBalance? {
        guard let data = json.data(using: .utf8), !data.isEmpty else { return nil }
        return try WalletJSON.decoder.decode(WalletBalance.self, from: data)
    }

    nonisolated private static func decodeAssets(_ json: String) throws -> [WalletAsset] {
        guard let data = json.data(using: .utf8), !data.isEmpty else { return [] }
        if json == "null" { return [] }
        return try WalletJSON.decoder.decode([WalletAsset].self, from: data)
    }

    nonisolated private static func decodeOrders(_ json: String) throws -> [WalletOrder] {
        guard let data = json.data(using: .utf8), !data.isEmpty else { return [] }
        if json == "null" { return [] }
        return try WalletJSON.decoder.decode([WalletOrder].self, from: data)
    }
}
