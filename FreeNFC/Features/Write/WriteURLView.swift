import CoreNFC
import SwiftUI

struct WriteURLView: View {
    @State private var text = ""

    var body: some View {
        Form {
            Section {
                TextField("example.com or https://example.com", text: $text)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } footer: {
                Text("If you leave off \u{201C}http://\u{201D} or \u{201C}https://\u{201D}, it's added automatically.")
            }

            Section {
                AddRecordButton(title: "Link", icon: "link", color: .blue, subtitle: text.isEmpty ? "Empty" : text, buildPayload: buildPayload)
            }
        }
        .navigationTitle("Write Link")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func buildPayload() throws -> NFCNDEFPayload {
        let url = try InputValidators.normalizeWebURL(text)
        guard let payload = NDEFWriter.uri(url.absoluteString) else {
            throw NFCError.custom("Couldn't build that link record.")
        }
        return payload
    }
}
