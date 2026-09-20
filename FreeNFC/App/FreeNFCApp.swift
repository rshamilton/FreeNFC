import SwiftUI
import SwiftData

@main
struct FreeNFCApp: App {
    let modelContainer: ModelContainer = {
        let schema = Schema(AppSchema.models)
        let configuration = ModelConfiguration(schema: schema)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }()

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(modelContainer)
    }
}
