import SwiftUI

let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String

struct NewDocumentView: View {
    @State private var dataFolder: String = ""
    @State private var strategyFolder: String = ""
    @State private var resultFolder: String = ""
    
    @Environment(\.newDocument) private var newDocument
    @Environment(\.)
    
    var body: some View {
        HStack(spacing: 0) {
            // Left panel - Hero section
            VStack(alignment: .leading, spacing: 20) {
                Spacer()
                
                Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .foregroundStyle(.blue, .white.opacity(0.8))
                
                Text("Welcome to\nArgo Trading")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineSpacing(4)
                
                Text("Set up your project to start analyzing the markets with powerful tools and strategies.")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
                    .lineSpacing(4)
                    .frame(maxWidth: 320)
                
                Spacer()
                
                Text("Version \(appVersion!)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(40)
            .frame(width: 360)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue, Color.purple.opacity(0.8)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            // Right panel - Setup form
            VStack(alignment: .leading) {
                Text("Project Setup")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.bottom, 4)
                
                Text("Choose locations for your trading project components")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 30)
                
                VStack(spacing: 20) {
                    FolderSelectionView(
                        title: "Data Folder",
                        description: "Store your market data and historical prices",
                        icon: "folder.fill",
                        selectedPath: $dataFolder
                    )
                    
                    FolderSelectionView(
                        title: "Strategy Folder",
                        description: "Manage your trading strategies and algorithms",
                        icon: "folder.fill",
                        selectedPath: $strategyFolder
                    )
                    
                    FolderSelectionView(
                        title: "Results Folder",
                        description: "Save your trading results and analysis",
                        icon: "folder.fill",
                        selectedPath: $resultFolder
                    )
                }
                
                Spacer()
                
                // Action buttons
                HStack {
                    Spacer()
                    Button(action: {
                        createDocument()
                    }) {
                        Text("Create Project")
                            .frame(width: 100)
                    }
                    .disabled(dataFolder.isEmpty || strategyFolder.isEmpty || resultFolder.isEmpty)
                    .buttonStyle(.borderedProminent)
                }
                .padding(.top, 20)
            }
            .padding(40)
            .frame(minWidth: 0, maxWidth: .infinity)
            .background(Color(.windowBackgroundColor))
        }
        .frame(width: 820, height: 520)
    }
}

// Custom folder selection view
struct FolderSelectionView: View {
    let title: String
    let description: String
    let icon: String
    @Binding var selectedPath: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                FilePickerField(
                    title: title,
                    description: description,
                    selectedPath: $selectedPath
                )
                .padding(.top, 2)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.controlBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
        )
    }
}

extension NewDocumentView {
    func createDocument() {
        let dataFolder = URL(fileURLWithPath: dataFolder)
        let strategyFolder = URL(fileURLWithPath: strategyFolder)
        let resultFolder = URL(fileURLWithPath: resultFolder)
        
        let document = ArgoTradingDocument(dataFolder: dataFolder, strategyFolder: strategyFolder, resultFolder: resultFolder)
        newDocument(document)
    }
}
