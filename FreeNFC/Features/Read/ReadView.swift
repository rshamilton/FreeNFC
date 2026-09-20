import CoreNFC
import SwiftData
import SwiftUI

struct ReadView: View {
    @EnvironmentObject private var nfc: NFCSessionManager
    @Environment(\.modelContext) private var modelContext
    @AppStorage("autoSaveScans") private var autoSaveScans: Bool = false

    @State private var scannedTag: ScannedTag?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            if let errorMessage {
                StatusBanner(kind: .error, message: errorMessage)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            NFCScanPrompt(
                title: "Read a Tag",
                subtitle: "Detects chip architecture, decodes NDEF records, inspects security configuration, and dumps raw memory.",
                systemImage: "doc.text.magnifyingglass",
                isScanning: nfc.isScanning,
                actionTitle: "Scan Tag",
                action: { Task { await startScan() } }
            )
        }
        .navigationTitle("Read")
        .navigationDestination(item: $scannedTag) { tag in
            ReadResultView(tag: tag)
        }
        .animation(.easeInOut, value: errorMessage)
    }

    private func startScan() async {
        errorMessage = nil
        let outcome = await TagScanner.scan(using: nfc, alertMessage: "Hold your iPhone near the tag to read it.")
        switch outcome {
        case .success(let tag):
            FeedbackManager.shared.success()
            if autoSaveScans {
                let autoSaveName = "\(tag.family.rawValue) (\(tag.uid.prefix(8)))"
                let saved = SavedTag(name: autoSaveName, scannedTag: tag)
                modelContext.insert(saved)
            }
            scannedTag = tag
        case .failure(let error):
            if !NFCSessionManager.isUserCancellation(error) {
                FeedbackManager.shared.error()
                errorMessage = NFCSessionManager.friendlyMessage(for: error)
            }
        }
    }
}
