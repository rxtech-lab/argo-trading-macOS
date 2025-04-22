import SwiftUI

let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String

enum WelcomeScreenPath: Hashable {
    case firstScreen
    case secondScreen
    case thridScreen(TemplateItem)
}

struct NewDocumentView: View {
    @Environment(\.openDocument) private var openDocument
    @Environment(AlertManager.self) private var alertManager
    @State private var navigationPath: [WelcomeScreenPath] = []

    var body: some View {
        NavigationStack(path: $navigationPath) {
            NewDocumentFirstScreen {
                navigationPath.append(.secondScreen)
            } onOpenExistingProject: {
                pickAndOpenDocument()
            }
            .navigationDestination(for: WelcomeScreenPath.self) { path in
                switch path {
                case .firstScreen:
                    EmptyView()

                case .secondScreen:
                    NewDocumentSecondScreen(navigationPath: $navigationPath)

                case .thridScreen(let template):
                    ProjectCreationScreen(template: template)
                }
            }
        }
    }
}

extension NewDocumentView {
    func pickAndOpenDocument() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.argoTradingDocument]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true

        openPanel.begin { result in
            switch result {
            case .OK:
                if let url = openPanel.url {
                    Task {
                        do {
                            try await openDocument(at: url)
                        } catch {
                            alertManager.showAlert(message: error.localizedDescription)
                        }
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
