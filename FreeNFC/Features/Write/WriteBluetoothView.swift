import CoreNFC
import SwiftUI

struct WriteBluetoothView: View {
    @State private var address = ""
    @State private var deviceName = ""

    var body: some View {
        Form {
            Section {
                TextField("Bluetooth Address (AA:BB:CC:DD:EE:FF)", text: $address)
                    .keyboardType(.asciiCapable)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))
                TextField("Device Name (optional)", text: $deviceName)
            } footer: {
                Text("Writes a standard Bluetooth OOB pairing record. iPhone doesn't auto-pair from reading a tag \u{2014} Apple has no public API for that \u{2014} but the record is spec-compliant, so Android phones and dedicated BT/NFC pairing hardware can use it.")
            }

            Section {
                AddRecordButton(
                    title: "Bluetooth Pairing",
                    icon: "dot.radiowaves.left.and.right",
                    color: .blue,
                    subtitle: deviceName.isEmpty ? (address.isEmpty ? "Empty" : address) : deviceName,
                    buildPayload: buildPayload
                )
            }
        }
        .navigationTitle("Write Bluetooth Pairing")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func buildPayload() throws -> NFCNDEFPayload {
        let data = try BluetoothOOBBuilder.build(address: address, deviceName: deviceName)
        return NDEFWriter.mime(type: BluetoothOOBBuilder.mimeType, data: data)
    }
}
