//
//  FileCommand.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 4/20/25.
//

import SwiftUI

struct DatasetCommand: Commands {
    @Environment(DatasetDownloadService.self) var downloadService

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Download dataset") {
                downloadService.showDownloadView = true
            }
        }
    }
}
