import Foundation

/// Builds an NFC Forum "Bluetooth Secure Simple Pairing" OOB record (the standard MIME record
/// type devices use to hand off pairing info over NFC). Note: iPhone doesn't auto-pair from
/// reading this off a plain tag the way some Android phones do -- there's no public API for
/// it -- but the record itself is built to spec, so Android phones and dedicated BT/NFC
/// pairing hardware can use it normally.
enum BluetoothOOBBuilder {
    static let mimeType = "application/vnd.bluetooth.ep.oob"

    static func build(address: String, deviceName: String) throws -> Data {
        let addressBytes = try parseAddress(address)

        var eir = Data()
        let trimmedName = deviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            let nameData = Data(trimmedName.utf8)
            guard nameData.count <= 248 else { throw NFCError.custom("Device name is too long.") }
            eir.append(UInt8(nameData.count + 1))
            eir.append(0x09) // Complete Local Name
            eir.append(nameData)
        }

        // BD_ADDR is transmitted least-significant byte first.
        var payload = Data(addressBytes.reversed())
        payload.append(eir)

        let totalLength = UInt16(2 + payload.count) // includes the 2-byte length field itself
        var result = Data()
        result.append(UInt8(totalLength & 0xFF))
        result.append(UInt8((totalLength >> 8) & 0xFF))
        result.append(payload)
        return result
    }

    private static func parseAddress(_ address: String) throws -> [UInt8] {
        let hex = address.filter { $0 != ":" && $0 != "-" && !$0.isWhitespace }
        guard hex.count == 12, let data = HexUtils.data(fromHex: hex) else {
            throw NFCError.custom("Enter a Bluetooth address like AA:BB:CC:DD:EE:FF.")
        }
        return Array(data)
    }
}
