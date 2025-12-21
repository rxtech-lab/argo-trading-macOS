//
//  DownloadService.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 4/20/25.
//
import ArgoTrading
import SwiftUI

@Observable
class DatasetDownloadService: NSObject, SwiftargoMarketDownloaderHelperProtocol {
    var showDownloadView: Bool = false
    var currentProgress: Double = 0.0
    var currentMessage: String = ""
    var totalProgress: Double = 0.0
    var isDownloading: Bool = false
    var downloadTask: Task<Void, Never>?

    var progressPercentage: String {
        if totalProgress > 0 {
            return String(format: "%.0f%%", currentProgress / totalProgress * 100)
        } else {
            return "0%"
        }
    }

    func onDownloadProgress(_ current: Double, total: Double, message: String?) {
        currentProgress = current
        totalProgress = total
        if let message = message {
            currentMessage = message
        }
    }

    func cancel() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
    }
}
