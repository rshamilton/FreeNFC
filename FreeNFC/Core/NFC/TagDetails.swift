import CoreNFC
import Foundation

/// Everything extra we can pull off a tag beyond its NDEF records — chip identity, signature,
/// counters, lock bytes, capability container and configuration. Populated best-effort: any
/// field the tag refuses to answer stays nil rather than failing the whole scan.
struct TagDetails: Codable, Hashable {
    // MIFARE Ultralight / NTAG
    var versionBytes: Data?          // GET_VERSION (8 bytes)
    var signature: Data?             // READ_SIG (32 bytes, ECC originality signature)
    var readCounter: Int?            // READ_CNT (NFC counter)
    var capabilityContainer: Data?   // page 3
    var staticLockBytes: Data?       // page 2, bytes 2-3
    var dynamicLockBytes: Data?      // dynamic lock page
    var configPage0: Data?           // CFG0: MIRROR / MIRROR_PAGE / AUTH0
    var configPage1: Data?           // CFG1: ACCESS byte

    // Shared / other families
    var historicalBytes: Data?
    var applicationIdentifier: String?          // ISO 7816 initially-selected AID
    var applicationData: Data?
    var proprietaryApplicationDataCoding: Bool?
    var icManufacturerCode: Int?                // ISO 15693
    var icSerialNumber: Data?                   // ISO 15693
    var systemCode: Data?                       // FeliCa
    var dsfid: Int?
    var afi: Int?
    var blockSize: Int?
    var blockCount: Int?
    var icReference: Int?

    var isEmpty: Bool {
        versionBytes == nil && signature == nil && readCounter == nil && capabilityContainer == nil
            && historicalBytes == nil && applicationIdentifier == nil && icManufacturerCode == nil
            && systemCode == nil && dsfid == nil
    }

    // MARK: - GET_VERSION decoding (NTAG21x / Ultralight EV1)

    var vendorName: String? {
        guard let versionBytes, versionBytes.count >= 2 else { return nil }
        return versionBytes[1] == 0x04 ? "NXP Semiconductors" : String(format: "0x%02X", versionBytes[1])
    }

    var productTypeName: String? {
        guard let versionBytes, versionBytes.count >= 3 else { return nil }
        switch versionBytes[2] {
        case 0x03: return "MIFARE Ultralight"
        case 0x04: return "NTAG"
        default: return String(format: "0x%02X", versionBytes[2])
        }
    }

    var productVersion: String? {
        guard let versionBytes, versionBytes.count >= 6 else { return nil }
        return "\(versionBytes[4]).\(versionBytes[5])"
    }

    /// User-memory size implied by the GET_VERSION storage byte, in bytes.
    var storageSizeDescription: String? {
        guard let versionBytes, versionBytes.count >= 7 else { return nil }
        switch versionBytes[6] {
        case 0x0B: return "48 bytes"
        case 0x0E: return "128 bytes"
        case 0x0F: return "144 bytes"
        case 0x11: return "504 bytes"
        case 0x13: return "888 bytes"
        default: return String(format: "storage code 0x%02X", versionBytes[6])
        }
    }

    var protocolDescription: String? {
        guard let versionBytes, versionBytes.count >= 8 else { return nil }
        return versionBytes[7] == 0x03 ? "ISO/IEC 14443-3" : String(format: "0x%02X", versionBytes[7])
    }

    // MARK: - Capability container decoding

    /// NDEF capability container: magic, version, size, and read/write access.
    var capabilityContainerDescription: String? {
        guard let cc = capabilityContainer, cc.count >= 4 else { return nil }
        guard cc[0] == 0xE1 else { return "Not NDEF formatted (magic 0x\(String(format: "%02X", cc[0])))" }
        let major = (cc[1] >> 4) & 0x0F
        let minor = cc[1] & 0x0F
        let size = Int(cc[2]) * 8
        let access = cc[3] == 0x00 ? "read/write" : (cc[3] == 0x0F ? "read-only" : String(format: "0x%02X", cc[3]))
        return "NDEF v\(major).\(minor), \(size) bytes, \(access)"
    }

    var isNDEFReadOnlyByCC: Bool {
        guard let cc = capabilityContainer, cc.count >= 4 else { return false }
        return cc[0] == 0xE1 && cc[3] != 0x00
    }

    // MARK: - Password / configuration decoding (NTAG21x)

    /// First page protected by the password. 0xFF means protection is disabled.
    var auth0: Int? {
        guard let cfg = configPage0, cfg.count >= 4 else { return nil }
        return Int(cfg[3])
    }

    var isPasswordProtected: Bool {
        guard let auth0 else { return false }
        return auth0 <= 0xFE
    }

    /// PROT bit: false = password needed for writing only, true = for reading too.
    var passwordProtectsReads: Bool? {
        guard let cfg = configPage1, cfg.count >= 1 else { return nil }
        return (cfg[0] & 0x80) != 0
    }

    /// CFGLCK: configuration pages permanently frozen.
    var isConfigurationLocked: Bool {
        guard let cfg = configPage1, cfg.count >= 1 else { return false }
        return (cfg[0] & 0x40) != 0
    }

    /// AUTHLIM: number of failed password attempts allowed (0 = unlimited).
    var authenticationLimit: Int? {
        guard let cfg = configPage1, cfg.count >= 1 else { return nil }
        return Int(cfg[0] & 0x07)
    }

    var hasStaticLockBits: Bool {
        guard let lock = staticLockBytes, lock.count >= 2 else { return false }
        return lock[0] != 0 || lock[1] != 0
    }

    var hasDynamicLockBits: Bool {
        guard let lock = dynamicLockBytes, lock.count >= 3 else { return false }
        return lock[0] != 0 || lock[1] != 0 || lock[2] != 0
    }

    var hasOriginalitySignature: Bool {
        guard let signature else { return false }
        return signature.contains { $0 != 0x00 }
    }
}
