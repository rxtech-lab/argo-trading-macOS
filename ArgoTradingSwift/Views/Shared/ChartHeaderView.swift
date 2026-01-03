//
//  ChartHeaderView.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/27/25.
//

import SwiftUI

/// Reusable chart header with title and zoom controls
struct ChartHeaderView: View {
    let title: String
    @Binding var zoomScale: CGFloat
    let minZoom: CGFloat
    let maxZoom: CGFloat

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
        }
    }
}
