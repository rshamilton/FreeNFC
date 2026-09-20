import CoreNFC
import Foundation

/// Everything the Read screen (and Duplicate's "save source tag" step) knows about one scan.
struct ScannedTag: Identifiable, Codable, Hashable {
    let id: UUID
    let uid: String
    let familyRawValue: String
    let techDetail: String?
    let ndefStatusRawValue: UInt?
    let ndefCapacity: Int?
    let records: [NDEFRecordModel]
    let dump: TagDump?
    /// Chip identity, signature, lock bytes and configuration. Optional so tags saved by older
    /// versions of the app still decode.
    let details: TagDetails?
    let dateScanned: Date

    init(
        uid: String,
        family: TagFamily,
        techDetail: String?,
        ndefStatus: NFCNDEFStatus?,
        ndefCapacity: Int?,
        records: [NDEFRecordModel],
        dump: TagDump?,
        details: TagDetails? = nil,
        dateScanned: Date = Date()
    ) {
        self.id = UUID()
        self.uid = uid
        self.familyRawValue = family.rawValue
        self.techDetail = techDetail
        self.ndefStatusRawValue = ndefStatus?.rawValue
        self.ndefCapacity = ndefCapacity
        self.records = records
        self.dump = dump
        self.details = details
        self.dateScanned = dateScanned
    }

    var family: TagFamily { TagFamily(rawValue: familyRawValue) ?? .unknown }

    var ndefStatus: NFCNDEFStatus? {
        ndefStatusRawValue.flatMap { NFCNDEFStatus(rawValue: $0) }
    }

    var ndefStatusLabel: String {
        switch ndefStatus {
        case .readWrite: return "Read / Write"
        case .readOnly: return "Read-Only"
        case .notSupported: return "Not NDEF Formatted"
        case .none: return "Unknown"
        @unknown default: return "Unknown"
        }
    }

    var allRawBytesHexString: String {
        if let dump { return dump.flatData.hexString }
        return records.map(\.fullRecordHexString).joined(separator: "\n")
    }
}
