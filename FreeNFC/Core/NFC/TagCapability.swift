import CoreNFC

/// What family a scanned tag belongs to, and which power-tools are meaningful for it.
/// iPhone's public CoreNFC API cannot authenticate MIFARE Classic sectors (Apple blocks the
/// crypto1 command for security reasons), so Classic tags are UID/detect-only everywhere in the app.
enum TagFamily: String, Codable {
    case ultralightOrNTAG = "MIFARE Ultralight / NTAG"
    case mifareClassic = "MIFARE Classic"
    case iso15693 = "ISO 15693 (Vicinity)"
    case iso7816 = "ISO 7816 (Smart Card)"
    case felica = "FeliCa"
    case unknown = "Unknown"

    var supportsRawMemoryAccess: Bool {
        switch self {
        case .ultralightOrNTAG, .iso15693: return true
        case .mifareClassic, .iso7816, .felica, .unknown: return false
        }
    }

    var supportsPassword: Bool {
        self == .ultralightOrNTAG
    }

    var supportsLock: Bool {
        self == .ultralightOrNTAG || self == .iso15693
    }

    var supportsManualCommands: Bool {
        self != .unknown
    }

    var iconName: String {
        switch self {
        case .ultralightOrNTAG: return "wave.3.right.circle.fill"
        case .mifareClassic: return "lock.circle.fill"
        case .iso15693: return "dot.radiowaves.left.and.right"
        case .iso7816: return "creditcard.circle.fill"
        case .felica: return "circle.hexagongrid.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
}

enum TagFamilyResolver {
    /// The tag's UID (or FeliCa's IDm, which serves the same role).
    static func uidData(for tag: NFCTag) -> Data {
        switch tag {
        case .miFare(let t): return t.identifier
        case .iso15693(let t): return t.identifier
        case .iso7816(let t): return t.identifier
        case .feliCa(let t): return t.currentIDm
        @unknown default: return Data()
        }
    }

    static func family(for tag: NFCTag) -> TagFamily {
        switch tag {
        case .miFare(let mifareTag):
            switch mifareTag.mifareFamily {
            case .ultralight: return .ultralightOrNTAG
            case .plus, .desfire: return .iso7816
            case .unknown: return .mifareClassic
            @unknown default: return .unknown
            }
        case .iso15693:
            return .iso15693
        case .iso7816:
            return .iso7816
        case .feliCa:
            return .felica
        @unknown default:
            return .unknown
        }
    }
}
