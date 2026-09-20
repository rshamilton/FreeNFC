import CoreNFC
import SwiftUI

struct WriteCustomView: View {
    private let tnfOptions: [(String, NFCTypeNameFormat)] = [
        ("Well-Known", .nfcWellKnown),
        ("Media (MIME)", .media),
        ("Absolute URI", .absoluteURI),
        ("External", .nfcExternal),
        ("Empty", .empty),
        ("Unknown", .unknown),
    ]

    @State private var tnfIndex = 1
    @State private var typeString = "text/plain"
    @State private var identifierHex = ""
    @State private var payloadIsHex = false
    @State private var payloadText = ""
    @State private var payloadHex = ""

    var body: some View {
        Form {
            Section("Record Header") {
                Picker("TNF", selection: $tnfIndex) {
                    ForEach(tnfOptions.indices, id: \.self) { Text(tnfOptions[$0].0).tag($0) }
                }
                TextField("Type (e.g. text/plain, U, T)", text: $typeString)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Identifier (hex, optional)", text: $identifierHex)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))
            }

            Section("Payload") {
                Toggle("Enter as Hex Bytes", isOn: $payloadIsHex)
                if payloadIsHex {
                    TextField("48 65 6C 6C 6F", text: $payloadHex)
                        .font(.system(.body, design: .monospaced))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    TextField("Payload text", text: $payloadText, axis: .vertical)
                        .lineLimit(2...5)
                }
            }

            Section {
                AddRecordButton(title: "Custom Record", icon: "curlybraces", color: .gray, subtitle: typeString.isEmpty ? "Empty" : typeString, buildPayload: buildPayload)
            }
        }
        .navigationTitle("Custom Raw Record")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func buildPayload() throws -> NFCNDEFPayload {
        guard !typeString.isEmpty || tnfOptions[tnfIndex].1 == .empty else {
            throw ValidationError.empty("Type")
        }

        let identifier: Data
        if identifierHex.isEmpty {
            identifier = Data()
        } else if let parsed = HexUtils.data(fromHex: identifierHex) {
            identifier = parsed
        } else {
            throw NFCError.custom("Identifier must be valid hex bytes.")
        }

        let payload: Data
        if payloadIsHex {
            guard let parsed = HexUtils.data(fromHex: payloadHex) else {
                throw NFCError.custom("Payload must be valid hex bytes.")
            }
            payload = parsed
        } else {
            payload = Data(payloadText.utf8)
        }

        return NDEFWriter.custom(
            tnf: tnfOptions[tnfIndex].1,
            type: Data(typeString.utf8),
            identifier: identifier,
            payload: payload
        )
    }
}
