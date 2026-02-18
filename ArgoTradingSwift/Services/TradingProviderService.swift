//
//  TradingProviderService.swift
//  ArgoTradingSwift
//
//  Created by Claude on 2/18/26.
//

import Foundation

@Observable
class TradingProviderService {
    var showProviderEditor = false
    var showManageProviders = false
    var isEditing = false
    var editingProvider: TradingProvider?

    func showCreateEditor() {
        editingProvider = nil
        isEditing = false
        showProviderEditor = true
    }

    func showEditEditor(for provider: TradingProvider) {
        editingProvider = provider
        isEditing = true
        showProviderEditor = true
    }

    func dismissEditor() {
        showProviderEditor = false
        editingProvider = nil
        isEditing = false
    }

    func showManageProvidersSheet() {
        showManageProviders = true
    }

    func dismissManageProviders() {
        showManageProviders = false
    }
}
