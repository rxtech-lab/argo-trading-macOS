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
    var toolbarStatusService: ToolbarStatusService?
    var currentTicker: String = ""
    var marketDownloader: SwiftargoMarketDownloader?

    var progressPercentage: String {
        if totalProgress > 0 {
            return String(format: "%.0f%%", currentProgress / totalProgress * 100)
        } else {
            return "0%"
        }
    }

    func onDownloadProgress(_ current: Double, total: Double, message: String?) {
        guard isDownloading else { return }

        currentProgress = current
        totalProgress = total
        if let message = message {
            currentMessage = message
        }

        toolbarStatusService?.toolbarRunningStatus = .downloading(
            label: currentTicker,
            progress: Progress(current: Int(current), total: Int(total))
        )
    }

    func cancel() {
        marketDownloader?.cancel()
        marketDownloader = nil
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        toolbarStatusService?.toolbarRunningStatus = .idle
    }
}
