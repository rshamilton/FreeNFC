import SwiftUI

struct RootTabView: View {
    @StateObject private var nfc = NFCSessionManager()
    @StateObject private var writeStore = WriteComposerStore()

    var body: some View {
        TabView {
            NavigationStack { ReadView() }
                .tabItem { Label("Read", systemImage: "doc.text.magnifyingglass") }

            NavigationStack { WriteHomeView() }
                .environmentObject(writeStore)
                .tabItem { Label("Write", systemImage: "square.and.pencil") }

            NavigationStack { DuplicateHomeView() }
                .tabItem { Label("Duplicate", systemImage: "doc.on.doc") }

            NavigationStack { ToolsHomeView() }
                .tabItem { Label("Tools", systemImage: "wrench.and.screwdriver") }

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .environmentObject(nfc)
    }
}
