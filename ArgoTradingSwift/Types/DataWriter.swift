//
//  DataWriter.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 4/20/25.
//
import SwiftUI

enum DataWriter: String, CaseIterable, Identifiable {
    case duckdb

    var id: String { self.rawValue }

    @ViewBuilder
    var writerField: some View {
        switch self {
        case .duckdb:
            EmptyView()
        }
    }
}
