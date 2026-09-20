import CoreNFC
import SwiftUI

struct WritePhoneView: View {
    enum Mode: String, CaseIterable { case call = "Call", text = "Text (SMS)" }

    @State private var mode: Mode = .call
    @State private var number = ""
    @State private var message = ""

    var body: some View {
        Form {
            Section {
                Picker("Type", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
            }

            Section {
                TextField("Phone Number", text: $number)
                    .keyboardType(.phonePad)
                if mode == .text {
                    TextField("Message (optional)", text: $message, axis: .vertical)
                        .lineLimit(2...4)
                }
            }

            Section {
                AddRecordButton(title: mode.rawValue, icon: "phone", color: .green, subtitle: number.isEmpty ? "Empty" : number, buildPayload: buildPayload)
            }
        }
        .navigationTitle("Write Phone / SMS")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func buildPayload() throws -> NFCNDEFPayload {
        let uriString: String
        switch mode {
        case .call: uriString = try InputValidators.buildTel(number)
        case .text: uriString = try InputValidators.buildSMS(number, body: message)
        }
        guard let payload = NDEFWriter.uri(uriString) else {
            throw NFCError.custom("Couldn't build that record.")
        }
        return payload
    }
}
