//
//  ProjectTemplateView.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 4/22/25.
//

import SwiftUI

// MARK: - Views

struct ProjectTemplateSelector: View {
    let templates: [TemplateItem]
    @State private var selectedTemplate: TemplateItem?
    @State private var searchText: String = ""

    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.dismiss) private var dismiss
    @Binding var navigationPath: [WelcomeScreenPath]

    var filteredTemplates: [TemplateItem] {
        if searchText.isEmpty {
            return templates
        } else {
            return templates.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var groupedTemplates: [TemplateCategory: [TemplateItem]] {
        Dictionary(grouping: filteredTemplates) { $0.category }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Choose a template for your new project:")
                .font(.headline)
                .padding(.top, 20)
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(TemplateCategory.allCases, id: \.self) { category in
                        if let categoryTemplates = groupedTemplates[category],
                           !categoryTemplates.isEmpty
                        {
                            VStack(alignment: .leading) {
                                Text(category.rawValue)
                                    .font(.headline)
                                    .padding(.horizontal)
                                    .padding(.top, 10)

                                Divider()

                                LazyVGrid(
                                    columns: [
                                        GridItem(.flexible()),
                                        GridItem(.flexible()),
                                        GridItem(.flexible()),
                                        GridItem(.flexible()),
                                        GridItem(.flexible()),
                                    ], spacing: 10
                                ) {
                                    ForEach(categoryTemplates) { template in
                                        templateItemView(template: template)
                                    }
                                }
                                .padding()
                            }
                        }
                    }
                }
            }
            .border(Color.gray.opacity(0.2), width: 1)
            .padding()

            Spacer()
            // Bottom navigation
            HStack {
                Button {
                    dismissWindow()
                } label: {
                    Text("Cancel")
                        .frame(width: 80)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("Previous")
                        .frame(width: 80)
                }

                Button {
                    guard let selectedTemplate = selectedTemplate else { return }
                    navigationPath.append(.thridScreen(selectedTemplate))
                } label: {
                    Text("Next")
                        .frame(width: 80)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(selectedTemplate == nil)
            }
            .padding()
        }
        .frame(maxWidth: 800, minHeight: 600)
        .padding()
        .searchable(text: $searchText, prompt: "Search templates")
        .navigationBarBackButtonHidden()
    }

    private func templateItemView(template: TemplateItem) -> some View {
        VStack {
            Image(systemName: template.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .foregroundColor(.blue)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            selectedTemplate?.id == template.id ? Color.blue : Color.clear,
                            lineWidth: 2
                        )
                )

            Text(template.name)
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .frame(height: 40)
        }
        .frame(width: 100, height: 100)
        .padding(8)
        .background(selectedTemplate?.id == template.id ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
        .onTapGesture {
            if selectedTemplate == template {
                navigationPath.append(.thridScreen(template))
            }
            selectedTemplate = template
        }
    }
}
