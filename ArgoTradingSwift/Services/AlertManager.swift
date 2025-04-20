//
//  AlertManager.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 4/20/25.
//

import SwiftUI

extension View {}

struct AlertModifier: ViewModifier {
    let alertManager: AlertManager
    init(alertManager: AlertManager) {
        self.alertManager = alertManager
    }

    func body(content: Content) -> some View {
        content
            .alert(
                alertManager.alertTitle,
                isPresented: alertManager.isAlertPresentedBinding,
                actions: {
                    Button("OK", role: .cancel) {
                        alertManager.hideAlert()
                    }
                },
                message: {
                    Text(
                        alertManager.alertMessage.count > 1000
                            ? alertManager.alertMessage.prefix(997) + "..." : alertManager.alertMessage)
                }
            )
    }
}

extension View {
    func alertManager(_ alertManager: AlertManager) -> some View {
        modifier(AlertModifier(alertManager: alertManager))
    }
}

@Observable public class AlertManager: @unchecked Sendable {
    public var isAlertPresented: Bool = false
    public var isAlertPresentedBinding: Binding<Bool> {
        .init(get: { self.isAlertPresented }, set: { self.isAlertPresented = $0 })
    }

    private var error: (any LocalizedError)?
    private var message: String?

    public init() {}

    public var alertTitle: String {
        return "Error"
    }

    public var alertMessage: String {
        error?.errorDescription ?? message ?? "Unknown error"
    }

    public func showAlert(_ error: LocalizedError) {
        self.error = error
        isAlertPresented = true
    }

    public func showAlert(message: String) {
        self.message = message
        isAlertPresented = true
    }

    public func hideAlert() {
        isAlertPresented = false
        error = nil
    }
}
