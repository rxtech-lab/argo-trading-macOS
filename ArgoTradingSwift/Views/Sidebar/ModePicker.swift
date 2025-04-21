//
//  ModePicker.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 4/21/25.
//

import SwiftUI

struct ModePicker: View {
    @Bindable var navigationService: NavigationService

    var body: some View {
        Group {
            VStack {
                Divider()
                HStack {
                    ForEach(EditorMode.allCases) { mode in
                        Image(systemName: mode.icon)
                            .resizable()
                            .help(mode.rawValue)
                            .scaledToFit()
                            .frame(width: 12, height: 12)
                            .foregroundStyle(navigationService.selectedMode == mode ? .blue : .secondary)
                            .tag(mode)
                            .onTapGesture {
                                navigationService.selectedMode = mode
                            }
                    }
                }

                Divider()
            }
            .removeListPadding()
            List(selection: $navigationService.path) {
                switch navigationService.selectedMode {
                case .Backtest:
                    BacktestSection()
                default:
                    EmptyView()
                }
            }
        }
    }
}
