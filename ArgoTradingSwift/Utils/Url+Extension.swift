//
//  Url+Extension.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 12/27/25.
//

import Foundation

extension URL {
    /**
        Converts the URL to a path string without the "file://" prefix.
     */
    func toPathStringWithoutFilePrefix() -> String {
        self.path
    }
}
