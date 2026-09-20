import SwiftUI

struct CloneTargetView: View {
    let savedTag: SavedTag

    @EnvironmentObject private var nfc: NFCSessionManager
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var showConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section("Source") {
                    LabeledContent("Name", value: savedTag.name)
                    LabeledContent("Type", value: savedTag.family.rawValue)
                    if let tag = savedTag.scannedTag {
                        LabeledContent("Records", value: "\(tag.records.count)")
                        if let bytes = tag.dump?.totalBytes {
                            LabeledContent("Memory", value: "\(bytes) bytes")
                        }
                    }
                }
                Section {
                    Text("The target must be the same tag type (\(savedTag.family.rawValue)) and blank or overwritable. Its existing content will be replaced.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 12) {
                if let errorMessage {
                    StatusBanner(kind: .error, message: errorMessage).padding(.horizontal)
                }
                if let successMessage {
                    StatusBanner(kind: .success, message: successMessage).padding(.horizontal)
                }
                PrimaryActionButton(title: "Scan Target Tag & Write", isBusy: nfc.isScanning) {
                    showConfirm = true
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .navigationTitle("Write to New Tag")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Write to Target Tag", isPresented: $showConfirm, titleVisibility: .visible) {
            Button("Hold Near Target Tag") { Task { await clone() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This replaces the target tag's current content with \u{201C}\(savedTag.name)\u{201D}.")
        }
    }

    private func clone() async {
        errorMessage = nil
        successMessage = nil
        guard let source = savedTag.scannedTag else {
            errorMessage = "Couldn't load the saved tag."
            return
        }
        let outcome = await nfc.perform(alertMessage: "Hold your iPhone near the new (target) tag.") { tag, session in
            try await CloneEngine.clone(source, onto: tag)
        }
        switch outcome {
        case .success:
            successMessage = "Duplicated successfully."
        case .failure(let error):
            if !NFCSessionManager.isUserCancellation(error) {
                errorMessage = NFCSessionManager.friendlyMessage(for: error)
            }
        }
    }
}
