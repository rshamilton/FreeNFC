import CoreNFC
import Foundation

/// One thing worth telling the user about a tag: why it can't be written, why part of it
/// couldn't be read, or a fact about its protection state.
struct TagIssue: Identifiable, Hashable {
    enum Severity: String {
        case blocking   // this tag can't do what you're trying to do
        case warning    // partially limited
        case info       // worth knowing

        var systemImage: String {
            switch self {
            case .blocking: return "xmark.octagon.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            }
        }
    }

    let id = UUID()
    let severity: Severity
    let title: String
    let detail: String
}

/// Turns a scanned tag into plain-language explanations of anything blocking or limiting it —
/// password locks, permanent lock bits, encryption the iPhone can't touch, missing NDEF
/// formatting. This is what makes "it just failed" into "here's exactly why".
enum TagDiagnostics {
    static func issues(for tag: ScannedTag) -> [TagIssue] {
        var issues: [TagIssue] = []
        let details = tag.details

        // --- Encryption / hardware limits the iPhone simply can't get past
        if tag.family == .mifareClassic {
            issues.append(TagIssue(
                severity: .blocking,
                title: "Encrypted \u{2014} MIFARE Classic",
                detail: "Classic cards protect every sector with NXP's Crypto1 cipher. Apple blocks those authentication commands in CoreNFC, so no iPhone app can read or write the data \u{2014} only the UID is available."
            ))
        }

        if tag.family == .iso7816 {
            issues.append(TagIssue(
                severity: .info,
                title: "Smart card / secure element",
                detail: "This tag runs applications behind a secure element. Anything beyond its NDEF application usually needs cryptographic keys the card's issuer holds (bank cards, passports, transit and access cards)."
            ))
        }

        if tag.family == .felica {
            issues.append(TagIssue(
                severity: .info,
                title: "FeliCa secure services",
                detail: "Most FeliCa services (transit, e-money) are encrypted and need issuer keys. NFC Forge can read unencrypted services and NDEF, and send raw commands."
            ))
        }

        // --- Password protection
        if let details, details.isPasswordProtected, let auth0 = details.auth0 {
            let readsToo = details.passwordProtectsReads == true
            issues.append(TagIssue(
                severity: .blocking,
                title: "Password protected from page \(auth0)",
                detail: readsToo
                    ? "Pages \(auth0) and up need a password to read *or* write (PROT = 1). Use Tools \u{2192} Password Protection \u{2192} Recover to clear it, or Remove if you know the password."
                    : "Pages \(auth0) and up need a password before they can be written (PROT = 0), though they can still be read. Use Tools \u{2192} Password Protection to remove or recover it."
            ))
            if let limit = details.authenticationLimit, limit > 0 {
                issues.append(TagIssue(
                    severity: .warning,
                    title: "Limited password attempts",
                    detail: "This tag permanently locks itself after \(limit) wrong password attempt\(limit == 1 ? "" : "s") (AUTHLIM = \(limit)). Be careful with guesses."
                ))
            }
        }

        // --- Permanent locks
        if tag.ndefStatus == .readOnly || details?.isNDEFReadOnlyByCC == true {
            issues.append(TagIssue(
                severity: .blocking,
                title: "Locked read-only",
                detail: "This tag has been made permanently read-only. Nothing \u{2014} this app or any other \u{2014} can write to it again."
            ))
        }
        if details?.hasStaticLockBits == true {
            issues.append(TagIssue(
                severity: .warning,
                title: "Some pages permanently locked",
                detail: "Static lock bits are set, so part of the first 16 pages is frozen read-only. Lock bits are one-way and can't be cleared."
            ))
        }
        if details?.hasDynamicLockBits == true {
            issues.append(TagIssue(
                severity: .warning,
                title: "Upper pages permanently locked",
                detail: "Dynamic lock bits are set, freezing part of the upper user memory read-only. This can't be undone."
            ))
        }
        if details?.isConfigurationLocked == true {
            issues.append(TagIssue(
                severity: .warning,
                title: "Configuration frozen",
                detail: "CFGLCK is set, so the password and protection settings are permanently locked and can no longer be changed."
            ))
        }

        // --- NDEF state
        if tag.ndefStatus == .notSupported {
            issues.append(TagIssue(
                severity: .warning,
                title: "Not NDEF formatted",
                detail: "There's no valid capability container, so phones won't auto-open its contents. Writing from the Write tab will format it automatically, or use Tools \u{2192} Format."
            ))
        }

        // --- Read completeness
        if tag.family.supportsRawMemoryAccess && tag.dump == nil {
            issues.append(TagIssue(
                severity: .warning,
                title: "Memory couldn't be read",
                detail: "The raw memory dump failed. That usually means the tag is password protected, moved away mid-scan, or isn't a standard Ultralight/NTAG chip."
            ))
        }

        if tag.family == .ultralightOrNTAG, details?.versionBytes == nil {
            issues.append(TagIssue(
                severity: .info,
                title: "Unrecognized chip",
                detail: "This chip didn't answer GET_VERSION, so its exact layout is unknown. It may be a MIFARE Ultralight C (3DES authentication) or a third-party clone. Password and format tools need a known layout."
            ))
        }

        return issues
    }

    /// The single most important issue, used to explain a failed write in context.
    static func primaryBlocker(for tag: ScannedTag) -> TagIssue? {
        issues(for: tag).first { $0.severity == .blocking }
    }
}
