//
//  StringCollection+Extension.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 1/4/26.
//

import ArgoTrading

extension SwiftargoStringCollection {
    var stringArray: [String] {
        var result: [String] = []
        for index in 0 ..< self.size() {
            result.append(self.get(index))
        }
        return result
    }
}
