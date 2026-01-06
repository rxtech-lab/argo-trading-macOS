//
//  DataInfoView.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 12/21/25.
//
import LightweightChart
import SwiftUI

struct DataInfoView: View {
    let fileUrl: URL
    let items: [PriceData]

    var body: some View {
        Form {
            Text("File: \(fileUrl.lastPathComponent)")
            Text("Total Items: \(items.count)")
        }
        .padding()
        .formStyle(.grouped)
    }
}
