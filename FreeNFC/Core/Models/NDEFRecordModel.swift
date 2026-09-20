import CoreNFC
import Foundation

/// A display-friendly, Codable-safe wrapper around one NFCNDEFPayload record.
struct NDEFRecordModel: Identifiable, Codable, Hashable {
    let id: UUID
    let typeNameFormatRawValue: UInt8
    let type: Data
    let identifier: Data
    let payload: Data

    init(payload record: NFCNDEFPayload) {
        self.id = UUID()
        self.typeNameFormatRawValue = record.typeNameFormat.rawValue
        self.type = record.type
        self.identifier = record.identifier
        self.payload = record.payload
    }

    var typeNameFormat: NFCTypeNameFormat {
        NFCTypeNameFormat(rawValue: typeNameFormatRawValue) ?? .unknown
    }

    var typeString: String { String(data: type, encoding: .utf8) ?? type.hexString }

    var kindLabel: String {
        switch typeNameFormat {
        case .nfcWellKnown:
            if typeString == "T" { return "Text" }
            if typeString == "U" { return "URI / Link" }
            return "Well-Known (\(typeString))"
        case .media: return "Media (\(typeString))"
        case .absoluteURI: return "Absolute URI"
        case .nfcExternal: return "External (\(typeString))"
        case .empty: return "Empty"
        case .unknown: return "Unknown"
        case .unchanged: return "Unchanged"
        @unknown default: return "Unknown"
        }
    }

    var iconName: String {
        switch typeNameFormat {
        case .nfcWellKnown where typeString == "U": return "link"
        case .nfcWellKnown where typeString == "T": return "textformat"
        case .media: return "doc.richtext"
        case .nfcExternal: return "app.badge"
        default: return "shippingbox"
        }
    }

    /// Best-effort human-readable string for well-known Text/URI records, else a printable
    /// ASCII/UTF8 fallback for MIME text-ish payloads.
    var displayString: String? {
        if typeNameFormat == .nfcWellKnown, typeString == "T" {
            return Self.decodeText(payload)
        }
        if typeNameFormat == .nfcWellKnown, typeString == "U" {
            return Self.decodeURI(payload)
        }
        if typeNameFormat == .absoluteURI {
            return String(data: payload, encoding: .utf8)
        }
        if let s = String(data: payload, encoding: .utf8), typeString.hasPrefix("text/") || typeString.contains("vcard") {
            return s
        }
        return nil
    }

    var rawHexString: String { payload.hexString }
    var fullRecordHexString: String { (type + identifier + payload).hexString }

    /// Printable-ASCII rendering of the payload, for the record detail screen.
    var payloadASCII: String { HexUtils.asciiPreview(payload) }

    /// Human name for the record's type-name-format (TNF) field.
    var typeNameFormatLabel: String {
        switch typeNameFormat {
        case .empty: return "Empty (0x00)"
        case .nfcWellKnown: return "NFC Well-Known (0x01)"
        case .media: return "Media / MIME (0x02)"
        case .absoluteURI: return "Absolute URI (0x03)"
        case .nfcExternal: return "NFC External (0x04)"
        case .unknown: return "Unknown (0x05)"
        case .unchanged: return "Unchanged (0x06)"
        @unknown default: return "Unrecognized"
        }
    }

    /// A URL this record points at, when it has one, so the detail screen can offer to open it.
    var openableURL: URL? {
        guard let displayString else { return nil }
        if typeNameFormat == .nfcWellKnown, typeString == "U" { return URL(string: displayString) }
        if typeNameFormat == .absoluteURI { return URL(string: displayString) }
        return nil
    }

    // MARK: - NDEF well-known record decoding

    private static func decodeText(_ payload: Data) -> String? {
        guard let status = payload.first else { return nil }
        let isUTF16 = (status & 0x80) != 0
        let langLength = Int(status & 0x3F)
        guard payload.count > 1 + langLength else { return nil }
        let textData = payload.subdata(in: (1 + langLength)..<payload.count)
        return String(data: textData, encoding: isUTF16 ? .utf16 : .utf8)
    }

    private static let uriPrefixes: [String] = [
        "", "http://www.", "https://www.", "http://", "https://",
        "tel:", "mailto:", "ftp://anonymous:anonymous@", "ftp://ftp.",
        "ftps://", "sftp://", "smb://", "nfs://", "ftp://", "dav://",
        "news:", "telnet://", "imap:", "rtsp://", "urn:", "pop:",
        "sip:", "sips:", "tftp:", "btspp://", "btl2cap://", "btgoep://",
        "tcpobex://", "irdaobex://", "file://", "urn:epc:id:", "urn:epc:tag:",
        "urn:epc:pat:", "urn:epc:raw:", "urn:epc:", "urn:nfc:"
    ]

    private static func decodeURI(_ payload: Data) -> String? {
        guard let code = payload.first else { return nil }
        let rest = payload.count > 1 ? payload.subdata(in: 1..<payload.count) : Data()
        let suffix = String(data: rest, encoding: .utf8) ?? ""
        let prefix = uriPrefixes.indices.contains(Int(code)) ? uriPrefixes[Int(code)] : ""
        return prefix + suffix
    }
}
