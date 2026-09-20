import CoreNFC

struct APDUResponse {
    let data: Data
    let sw1: UInt8
    let sw2: UInt8
    var statusWord: UInt16 { (UInt16(sw1) << 8) | UInt16(sw2) }
    var isSuccess: Bool { statusWord == 0x9000 }
}

/// Raw APDU passthrough for ISO 7816-4 (smart-card style) tags, used by the Manual Commands tool.
extension NFCISO7816Tag {
    /// Sends a full raw APDU byte string (CLA INS P1 P2 [Lc Data] [Le]).
    func sendRawAPDU(_ bytes: Data) async throws -> APDUResponse {
        guard let apdu = NFCISO7816APDU(data: bytes) else {
            throw NFCError.custom("That isn't a valid APDU. Expected CLA INS P1 P2 [Lc Data] [Le].")
        }
        let (data, sw1, sw2) = try await sendCommand(apdu: apdu)
        return APDUResponse(data: data, sw1: sw1, sw2: sw2)
    }
}
