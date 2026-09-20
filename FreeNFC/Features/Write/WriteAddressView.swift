import CoreNFC
import SwiftUI

struct WriteAddressView: View {
    @State private var address = ""

    var body: some View {
        Form {
            Section {
                TextField("Place name or street address", text: $address, axis: .vertical)
                    .lineLimit(1...3)
            } footer: {
                Text("Writes a Maps link that searches for this address or place \u{2014} handy when you don't have exact coordinates.")
            }

            Section {
                AddRecordButton(title: "Address", icon: "map.circle.fill", color: .red, subtitle: address.isEmpty ? "Empty" : address, buildPayload: buildPayload)
            }
        }
        .navigationTitle("Write Address")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func buildPayload() throws -> NFCNDEFPayload {
        let uri = try InputValidators.buildMapsSearch(address)
        guard let payload = NDEFWriter.uri(uri) else {
            throw NFCError.custom("Couldn't build that address record.")
        }
        return payload
    }
}
