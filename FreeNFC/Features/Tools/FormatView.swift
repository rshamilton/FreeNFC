import CoreNFC
import SwiftUI

struct FormatView: View {
    @EnvironmentObject private var nfc: NFCSessionManager
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var showConfirm = false

    var body: some View {
        VStack(spacing: 16) {
            if let errorMessage {
                StatusBanner(kind: .error, message: errorMessage).padding(.horizontal)
            }
            if let successMessage {
                StatusBanner(kind: .success, message: successMessage).padding(.horizontal)
            }
            NFCScanPrompt(
                title: "Format Tag",
                subtitle: "Initializes a blank MIFARE Ultralight / NTAG tag so it's ready for NDEF reads and writes. Already-formatted tags don't need this \u{2014} use Erase instead.",
                systemImage: "sparkles.rectangle.stack",
                isScanning: nfc.isScanning,
                actionTitle: "Scan Tag to Format",
                action: { showConfirm = true }
            )
        }
        .navigationTitle("Format")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Format Tag", isPresented: $showConfirm, titleVisibility: .visible) {
            Button("Hold Near Tag to Format", role: .destructive) { Task { await format() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This overwrites the tag's capability container and content.")
        }
    }

    private func format() async {
        errorMessage = nil
        successMessage = nil
        let outcome = await nfc.perform(alertMessage: "Hold your iPhone near the tag to format it.") { tag, session in
            guard case .miFare(let mifareTag) = tag, TagFamilyResolver.family(for: tag) == .ultralightOrNTAG else {
                throw NFCError.custom("Formatting is only available for MIFARE Ultralight / NTAG tags right now.")
            }
            try await mifareTag.ulFormatAsNDEF()
        }
        switch outcome {
        case .success: successMessage = "Tag formatted and ready for NDEF."
        case .failure(let error):
            if !NFCSessionManager.isUserCancellation(error) {
                errorMessage = NFCSessionManager.friendlyMessage(for: error)
            }
        }
    }
}
