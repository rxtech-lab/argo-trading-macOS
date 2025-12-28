//
//  ToolbarErrorView.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 12/27/25.
//

import SwiftUI

struct ToolbarErrorView: View {
    let toolbarStatus: ToolbarRunningStatus

    @State private var showErrorPopover = false

    var body: some View {
        if case .error(_, let errors, _) = toolbarStatus, errors.count > 0 {
            HStack {
                Button {
                    showErrorPopover.toggle()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.red)

                    Text("\(errors.count)")
                }
            }
            .popover(isPresented: $showErrorPopover) {
                errorPopoverView(errors: errors)
                    .padding()
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder
    func errorPopoverView(errors: [String]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(errors, id: \.self) { error in
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.red)

                        Text("\(error)")

                        Spacer()
                    }
                }
            }
            .frame(idealWidth: 400, maxWidth: 400, maxHeight: 400)
        }
    }
}
