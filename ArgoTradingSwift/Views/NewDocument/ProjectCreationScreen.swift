//
//  FinalScreen.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 4/22/25.
//
import SwiftUI

struct ProjectCreationScreen: View {
    let template: TemplateItem

    @Environment(\.dismiss) var dismiss
    @Environment(\.dismissWindow) var dismissWindow
    @Environment(\.openDocument) var openDocument
    @Environment(AlertManager.self) var alertManager

    @State private var projectName: String = ""

    var body: some View {
        VStack(alignment: .leading) {
            Text(template.name)
                .font(.headline)
                .padding(.horizontal)
            Form {
                TextField("Project Name", text: $projectName)
            }
            .frame(width: 800, height: 450)
            .padding()
            .border(Color.gray.opacity(0.2), width: 1)
            .padding()

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
                    createDocument()
                } label: {
                    Text("Next")
                        .frame(width: 80)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(projectName.isEmpty)
            }
            .padding()
        }
        .padding()
    }
}

extension ProjectCreationScreen {
    func createDocument() {
        // show save panel
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.argoTradingDocument]
        savePanel.nameFieldStringValue = "\(projectName)"
        savePanel.begin { result in
            switch result {
            case .OK:
                if let url = savePanel.url {
                    do {
                        let parentDirectory = url.deletingLastPathComponent()
                        let dataFolder = parentDirectory.appending(path: "data")
                        let strategyFolder = parentDirectory.appending(path: "strategy")
                        let resultFolder = parentDirectory.appending(path: "result")

                        let document = ArgoTradingDocument(
                            dataFolder: dataFolder, strategyFolder: strategyFolder, resultFolder: resultFolder
                        )
                        // serialize the document to the URL
                        let data = try JSONEncoder().encode(document)
                        try data.write(to: url)

                        Task {
                            do {
                                // dismiss the current window
                                dismissWindow()
                                try await openDocument(at: url)
                            } catch {
                                alertManager.showAlert(message: error.localizedDescription)
                            }
                        }

                    } catch {
                        print("Error saving document: \(error)")
                    }
                }
            case .cancel:
                break
            default:
                break
            }
        }
    }
}

#Preview {
    ProjectCreationScreen(template: .init(name: "A", icon: "folder.fill", category: .application))
}
