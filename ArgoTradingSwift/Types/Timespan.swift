//
//  Timespan.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 4/20/25.
//

/**
    A Swift enum representing different timespans for data retrieval.
 */
enum Timespan: String, CaseIterable, Identifiable {
    case oneSecond = "1s"
    case oneMinute = "1m"
    case threeMinutes = "3m"
    case fiveMinutes = "5m"
    case fifteenMinutes = "15m"
    case thirtyMinutes = "30m"
    case oneHour = "1h"
    case twoHours = "2h"
    case fourHours = "4h"
    case sixHours = "6h"
    case eightHours = "8h"
    case twelveHours = "12h"
    case oneDay = "1d"
    case threeDays = "3d"
    case oneWeek = "1w"
    case oneMonth = "1M"

    var id: String {
        return self.rawValue
    }
}
