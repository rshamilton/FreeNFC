import CoreNFC

/// Parses an NFCNDEFMessage into display-friendly records. Works against the NFCNDEFTag
/// protocol, which every tag type CoreNFC hands us (MIFARE, ISO15693, ISO7816, FeliCa) adopts,
/// so read/write flows don't need to branch on tag family.
enum NDEFReader {
    static func status(of tag: NFCNDEFTag) async throws -> (status: NFCNDEFStatus, capacity: Int) {
        let (status, capacity) = try await tag.queryNDEFStatus()
        return (status, capacity)
    }

    static func readMessage(from tag: NFCNDEFTag) async throws -> NFCNDEFMessage? {
        try await tag.readNDEF()
    }

    static func records(from message: NFCNDEFMessage?) -> [NDEFRecordModel] {
        guard let message else { return [] }
        return message.records.map(NDEFRecordModel.init)
    }
}
