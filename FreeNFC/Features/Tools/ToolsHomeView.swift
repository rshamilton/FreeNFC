import SwiftUI

struct ToolsHomeView: View {
    var body: some View {
        List {
            Section("Content") {
                toolLink("Erase", "eraser", .blue) { EraseView() }
                toolLink("Format", "sparkles.rectangle.stack", .indigo) { FormatView() }
            }

            Section("Security") {
                toolLink("Lock Tag", "lock", .red) { LockView() }
                toolLink("Password Protection", "key", .orange) { PasswordView() }
            }

            Section("Advanced") {
                toolLink("Memory Editor", "square.grid.3x3.square", .purple) { MemoryEditorView() }
                toolLink("Manual Commands", "terminal", .green) { ManualCommandView() }
                toolLink("Full .bin Dump", "externaldrive", .teal) { BinDumpView() }
            }

            Section {
                toolLink("iPhone as Computer Reader", "laptopcomputer.and.iphone", .gray) { ComputerBridgeView() }
            } footer: {
                Text("Use this iPhone as an NFC reader for your Mac over Wi-Fi.")
            }
        }
        .navigationTitle("Tools")
    }

    @ViewBuilder
    private func toolLink<Destination: View>(_ title: String, _ icon: String, _ color: Color, @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            Label {
                Text(title)
            } icon: {
                Image(systemName: icon).foregroundStyle(color)
            }
        }
    }
}
