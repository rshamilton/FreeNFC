import CoreNFC
import SwiftUI

struct WriteTextView: View {
    @State private var text = ""

    var body: some View {
        Form {
            Section("Text") {
                TextEditor(text: $text)
                    .frame(minHeight: 120)
            }

            Section {
                AddRecordButton(title: "Text", icon: "textformat", color: .blue, subtitle: text.isEmpty ? "Empty" : text, buildPayload: buildPayload)
            }
        }
        .navigationTitle("Write Text")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func buildPayload() throws -> NFCNDEFPayload {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ValidationError.empty("Text") }
        guard let payload = NDEFWriter.text(trimmed) else { throw NFCError.custom("Couldn't build that text record.") }
        return payload
    }
}
