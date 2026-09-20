import CoreNFC
import Foundation

/// Builds NFCNDEFPayload records for every "Write" screen, and writes the finished
/// message to a connected tag.
enum NDEFWriter {
    /// Writes to a resolved NDEF tag. Prefer `write(_:to rawTag:)` which can auto-format a
    /// blank Ultralight / NTAG tag first.
    static func write(_ message: NFCNDEFMessage, to tag: NFCNDEFTag) async throws {
        let (status, capacity) = try await tag.queryNDEFStatus()
        switch status {
        case .notSupported:
            throw NFCError.custom("This tag doesn't support NDEF. Use Tools \u{2192} Format first if it's blank, or it may not support NDEF at all.")
        case .readOnly:
            throw NFCError.tagNotWritable
        case .readWrite:
            break
        @unknown default:
            break
        }
        let needed = message.records.reduce(0) { $0 + encodedLength(of: $1) }
        if needed > capacity {
            throw NFCError.payloadTooLarge(capacity: capacity, needed: needed)
        }
        try await writeWithRetry(message, to: tag)
    }

    /// Writes to a tag by its raw `NFCTag`, so a blank MIFARE Ultralight / NTAG that reports
    /// "not NDEF formatted" is formatted automatically and then written, instead of failing.
    static func write(_ message: NFCNDEFMessage, to rawTag: NFCTag) async throws {
        let ndef = ndefTag(from: rawTag)
        let (status, capacity) = try await ndef.queryNDEFStatus()

        switch status {
        case .readOnly:
            throw NFCError.tagNotWritable
        case .notSupported:
            // A blank Ultralight / NTAG often reads as "not supported" until it has a valid
            // capability container. Format it in place, then fall through to a normal write.
            guard case .miFare(let mifare) = rawTag, TagFamilyResolver.family(for: rawTag) == .ultralightOrNTAG else {
                throw NFCError.custom("This tag isn't NDEF formatted and can't be formatted automatically. If it's blank, try Tools \u{2192} Format; otherwise it may not support NDEF.")
            }
            try await mifare.ulFormatAsNDEF()
            let (newStatus, newCapacity) = try await ndef.queryNDEFStatus()
            guard newStatus == .readWrite else {
                throw NFCError.custom("Formatted the tag but it still won't accept NDEF data. It may be faulty.")
            }
            try requireFits(message, capacity: newCapacity)
            try await writeWithRetry(message, to: ndef)
            return
        case .readWrite:
            try requireFits(message, capacity: capacity)
            try await writeWithRetry(message, to: ndef)
        @unknown default:
            try await writeWithRetry(message, to: ndef)
        }
    }

    private static func requireFits(_ message: NFCNDEFMessage, capacity: Int) throws {
        let needed = message.records.reduce(0) { $0 + encodedLength(of: $1) }
        if capacity > 0, needed > capacity {
            throw NFCError.payloadTooLarge(capacity: capacity, needed: needed)
        }
    }

    /// `writeNDEF` occasionally fails with a transient transceive error (the classic
    /// "tag connection lost" / "tag responded incorrectly") while the tag is still in the
    /// field. One quick retry recovers most of those without ending the scan.
    private static func writeWithRetry(_ message: NFCNDEFMessage, to tag: NFCNDEFTag, attempts: Int = 2) async throws {
        var lastError: Error?
        for attempt in 0..<attempts {
            do {
                try await tag.writeNDEF(message)
                return
            } catch let error as NFCReaderError where isRetryable(error) && attempt < attempts - 1 {
                lastError = error
                try? await Task.sleep(nanoseconds: 120_000_000)
            }
        }
        if let lastError { throw lastError }
    }

    private static func isRetryable(_ error: NFCReaderError) -> Bool {
        switch error.code {
        case .readerTransceiveErrorTagConnectionLost,
             .readerTransceiveErrorRetryExceeded,
             .readerTransceiveErrorTagResponseError:
            return true
        default:
            return false
        }
    }

    /// Rough on-tag size estimate (record header overhead + type + id + payload).
    private static func encodedLength(of record: NFCNDEFPayload) -> Int {
        record.type.count + record.identifier.count + record.payload.count + 8
    }

    // MARK: - Record builders

    static func text(_ string: String, locale: Locale = Locale(identifier: "en")) -> NFCNDEFPayload? {
        NFCNDEFPayload.wellKnownTypeTextPayload(string: string, locale: locale)
    }

    static func uri(_ urlString: String) -> NFCNDEFPayload? {
        guard let url = URL(string: urlString) else { return nil }
        return NFCNDEFPayload.wellKnownTypeURIPayload(url: url)
    }

    static func mime(type: String, data: Data) -> NFCNDEFPayload {
        NFCNDEFPayload(
            format: .media,
            type: Data(type.utf8),
            identifier: Data(),
            payload: data
        )
    }

    static func custom(tnf: NFCTypeNameFormat, type: Data, identifier: Data, payload: Data) -> NFCNDEFPayload {
        NFCNDEFPayload(format: tnf, type: type, identifier: identifier, payload: payload)
    }
}
