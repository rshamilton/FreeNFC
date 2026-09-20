import CoreNFC
import SwiftUI

/// The "add this record" action every record-builder screen ends with. Builds and validates
/// the record, appends it to the in-progress list, then returns to Write's compose screen so
/// more records can be added before the final write.
struct AddRecordButton: View {
    let title: String
    let icon: String
    let color: Color
    let subtitle: String
    let buildPayload: () throws -> NFCNDEFPayload

    @EnvironmentObject private var store: WriteComposerStore
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 12) {
            if let errorMessage {
                StatusBanner(kind: .error, message: errorMessage)
            }
            PrimaryActionButton(title: "Add Record", systemImage: "plus.circle.fill") {
                add()
            }
        }
    }

    private func add() {
        errorMessage = nil
        do {
            let payload = try buildPayload()
            store.add(title: title, subtitle: subtitle, icon: icon, color: color, payload: payload)
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Check your input."
        }
    }
}
