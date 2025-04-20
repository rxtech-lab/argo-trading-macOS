import SwiftUI

struct PolygonApiKeyField: View {
    @SceneStorage("polygon-api-key") var apiKey: String = ""
    
    var body: some View {
        TextField("Polygon API Key", text: $apiKey)
            .disableAutocorrection(true)
    }
}
