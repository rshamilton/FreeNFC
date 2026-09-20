import CoreNFC
import SwiftUI

struct EraseView: View {
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
                title: "Erase Tag",
                subtitle: "Replaces the tag's NDEF content with an empty record. The tag stays formatted and reusable.",
                systemImage: "eraser",
                isScanning: nfc.isScanning,
                actionTitle: "Scan Tag to Erase",
                action: { showConfirm = true }
            )
        }
        .navigationTitle("Erase")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Erase Tag", isPresented: $showConfirm, titleVisibility: .visible) {
            Button("Hold Near Tag to Erase", role: .destructive) { Task { await erase() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears the tag's content. It can't be undone.")
        }
    }

    private func erase() async {
        errorMessage = nil
        successMessage = nil
        let emptyRecord = NFCNDEFPayload(format: .empty, type: Data(), identifier: Data(), payload: Data())
        let outcome = await nfc.perform(alertMessage: "Hold your iPhone near the tag to erase it.") { tag, session in
            try await NDEFWriter.write(NFCNDEFMessage(records: [emptyRecord]), to: tag)
        }
        switch outcome {
        case .success: successMessage = "Tag erased."
        case .failure(let error):
            if !NFCSessionManager.isUserCancellation(error) {
                errorMessage = NFCSessionManager.friendlyMessage(for: error)
            }
        }
    }
}
