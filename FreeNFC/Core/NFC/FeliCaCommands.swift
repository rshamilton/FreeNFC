import CoreNFC

/// Raw FeliCa command passthrough, used by the Manual Commands tool.
extension NFCFeliCaTag {
    /// Sends a raw FeliCa command packet (length byte is added automatically by CoreNFC).
    func sendRawFeliCa(_ bytes: Data) async throws -> Data {
        try await sendFeliCaCommand(commandPacket: bytes)
    }
}
