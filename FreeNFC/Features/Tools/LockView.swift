import CoreNFC
import SwiftUI

struct LockView: View {
    @EnvironmentObject private var nfc: NFCSessionManager
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var showFirstConfirm = false
    @State private var showFinalConfirm = false

    var body: some View {
        VStack(spacing: 16) {
            if let errorMessage {
                StatusBanner(kind: .error, message: errorMessage).padding(.horizontal)
            }
            if let successMessage {
                StatusBanner(kind: .success, message: successMessage).padding(.horizontal)
            }
            NFCScanPrompt(
                title: "Lock Tag",
                subtitle: "Permanently makes the tag read-only. This cannot be undone \u{2014} the tag can never be written to, erased, or formatted again.",
                systemImage: "lock",
                isScanning: nfc.isScanning,
                actionTitle: "Scan Tag to Lock",
                action: { showFirstConfirm = true },
                isDestructive: true
            )
        }
        .navigationTitle("Lock")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Lock Tag Permanently?", isPresented: $showFirstConfirm, titleVisibility: .visible) {
            Button("Continue", role: .destructive) { showFinalConfirm = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This is permanent and cannot be reversed by this app or any other.")
        }
        .confirmationDialog("Are You Absolutely Sure?", isPresented: $showFinalConfirm, titleVisibility: .visible) {
            Button("Yes, Lock This Tag Forever", role: .destructive) { Task { await lock() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Once locked, this tag will be read-only forever.")
        }
    }

    private func lock() async {
        errorMessage = nil
        successMessage = nil
        let outcome = await nfc.perform(alertMessage: "Hold your iPhone near the tag to lock it.") { tag, session in
            try await ndefTag(from: tag).writeLock()
        }
        switch outcome {
        case .success: successMessage = "Tag locked permanently."
        case .failure(let error):
            if !NFCSessionManager.isUserCancellation(error) {
                errorMessage = NFCSessionManager.friendlyMessage(for: error)
            }
        }
    }
}
