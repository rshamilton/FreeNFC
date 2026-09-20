import CoreNFC
import SwiftUI

struct WriteEmailView: View {
    @State private var to = ""
    @State private var subject = ""
    @State private var body_ = ""

    var body: some View {
        Form {
            Section {
                TextField("Email Address", text: $to)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Subject (optional)", text: $subject)
                TextField("Body (optional)", text: $body_, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section {
                AddRecordButton(title: "Email", icon: "envelope", color: .red, subtitle: to.isEmpty ? "Empty" : to, buildPayload: buildPayload)
            }
        }
        .navigationTitle("Write Email")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func buildPayload() throws -> NFCNDEFPayload {
        let mailto = try InputValidators.buildMailto(to: to, subject: subject, body: body_)
        guard let payload = NDEFWriter.uri(mailto) else {
            throw NFCError.custom("Couldn't build that email record.")
        }
        return payload
    }
}
