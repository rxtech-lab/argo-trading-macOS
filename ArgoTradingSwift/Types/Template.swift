//
//  Template.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 4/22/25.
//
import Foundation

struct TemplateItem: Identifiable, Equatable, Hashable {
    let id = UUID()
    let name: String
    let icon: String // SF Symbol name
    let category: TemplateCategory
}

enum TemplateCategory: String, CaseIterable {
    case application = "Application"
    case frameworkLibrary = "Framework & Library"
    case other = "Other"
}
