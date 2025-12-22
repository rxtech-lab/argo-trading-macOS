//
//  SidebarModePicker.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/22/25.
//

import SwiftUI

struct SidebarModePicker: View {
    @Bindable var navigationService: NavigationService

    var body: some View {
        Picker("Mode", selection: $navigationService.selectedMode) {
            ForEach(EditorMode.allCases) { mode in
                Image(systemName: mode.icon)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
}
