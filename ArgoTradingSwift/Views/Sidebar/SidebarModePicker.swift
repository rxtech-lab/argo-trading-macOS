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
                Label(mode.title, systemImage: mode.icon)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }
}
