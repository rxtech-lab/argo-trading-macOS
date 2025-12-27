//
//  Error+Extension.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 12/27/25.
//

import Foundation

extension Error {
    /**
     Varifies if the error is due to a cancelled context operation from go
     */
    var isContextCancelled: Bool {
        let desc = self.localizedDescription.lowercased()
        return desc.contains("context canceled") || desc.contains("operation was cancelled")
    }
}
