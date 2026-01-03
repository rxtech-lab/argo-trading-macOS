//
//  IndicatorConfig.swift
//  ArgoTradingSwift
//
//  Created by Claude on 1/3/26.
//

import Foundation

/// Configuration for a single indicator instance
struct IndicatorConfig: Codable, Identifiable, Hashable {
    let id: UUID
    let type: IndicatorType
    var isEnabled: Bool
    var parameters: [String: Int]
    var color: String

    init(type: IndicatorType, isEnabled: Bool = false) {
        self.id = UUID()
        self.type = type
        self.isEnabled = isEnabled
        self.color = type.defaultColor
        self.parameters = type.defaultParameters
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: IndicatorConfig, rhs: IndicatorConfig) -> Bool {
        lhs.id == rhs.id &&
            lhs.isEnabled == rhs.isEnabled &&
            lhs.parameters == rhs.parameters &&
            lhs.color == rhs.color
    }
}

/// Container for all indicator configurations
struct IndicatorSettings: Codable, Equatable {
    var indicators: [IndicatorConfig]

    /// Get enabled indicators only
    var enabledIndicators: [IndicatorConfig] {
        indicators.filter { $0.isEnabled }
    }

    /// Default settings with all indicators disabled
    static var `default`: IndicatorSettings {
        IndicatorSettings(
            indicators: IndicatorType.allCases.map { IndicatorConfig(type: $0, isEnabled: false) }
        )
    }

    /// Encode to JSON Data for AppStorage
    func toData() -> Data? {
        try? JSONEncoder().encode(self)
    }

    /// Decode from JSON Data
    static func fromData(_ data: Data?) -> IndicatorSettings {
        guard let data = data,
              let settings = try? JSONDecoder().decode(IndicatorSettings.self, from: data)
        else {
            return .default
        }
        return settings
    }
}
