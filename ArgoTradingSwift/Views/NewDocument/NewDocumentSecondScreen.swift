//
//  WelcomeSecondScreen.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 4/22/25.
//

import SwiftUI

struct NewDocumentSecondScreen: View {
    let sampleTemplates: [TemplateItem] = [
        // Application templates
        TemplateItem(name: "Empty", icon: "square.dashed", category: .application),
    ]

    @Binding var navigationPath: [WelcomeScreenPath]

    var body: some View {
        ProjectTemplateSelector(templates: sampleTemplates, navigationPath: $navigationPath)
    }
}
