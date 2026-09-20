import CoreNFC
import SwiftUI

struct WriteWhatsAppView: View {
    @State private var number = ""
    @State private var message = ""

    var body: some View {
        Form {
            Section {
                TextField("Phone number (with country code)", text: $number)
                    .keyboardType(.phonePad)
                TextField("Message (optional)", text: $message, axis: .vertical)
                    .lineLimit(2...5)
            } footer: {
                Text("Opens a WhatsApp chat with this number. Include the country code, e.g. +1 555 123 4567.")
            }

            Section {
                AddRecordButton(title: "WhatsApp", icon: "message.circle.fill", color: .green, subtitle: number.isEmpty ? "Empty" : number, buildPayload: buildPayload)
            }
        }
        .navigationTitle("Write WhatsApp")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func buildPayload() throws -> NFCNDEFPayload {
        let uri = try InputValidators.buildWhatsApp(number, message: message)
        guard let payload = NDEFWriter.uri(uri) else {
            throw NFCError.custom("Couldn't build that WhatsApp record.")
        }
        return payload
    }
}
