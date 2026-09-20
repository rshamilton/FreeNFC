import CoreNFC
import Foundation

/// Writes a previously-saved tag's content onto a new target tag.
enum CloneEngine {
    static func clone(_ source: ScannedTag, onto tag: NFCTag) async throws {
        let targetFamily = TagFamilyResolver.family(for: tag)
        guard targetFamily == source.family else {
            throw NFCError.custom("The saved tag is \(source.family.rawValue) but the target is \(targetFamily.rawValue). Duplicating needs two tags of the same type.")
        }

        // Prefer a straightforward NDEF clone -- it's what most saved tags actually need,
        // and it works even if the target's raw layout doesn't exactly match the source's.
        if !source.records.isEmpty {
            let records = source.records.map {
                NDEFWriter.custom(tnf: $0.typeNameFormat, type: $0.type, identifier: $0.identifier, payload: $0.payload)
            }
            try await NDEFWriter.write(NFCNDEFMessage(records: records), to: tag)
            return
        }

        guard let dump = source.dump, source.family.supportsRawMemoryAccess else {
            throw NFCError.custom("The saved tag has no NDEF content and no raw memory to clone.")
        }
        try await cloneRaw(dump, onto: tag)
    }

    /// Best-effort raw page/block clone for tags with no NDEF message. Writes only the user
    /// pages, starting at page 4 (never the UID/lock/CC header). The protected-page guard in
    /// `TagMemoryAccess.writeBlocks` is the backstop that keeps a clone from ever writing the
    /// config/lock/password pages and bricking the target.
    private static func cloneRaw(_ dump: TagDump, onto tag: NFCTag) async throws {
        switch tag {
        case .miFare:
            let layout = NTAGLayout.named(dump.chipLabel)
            let firstUserPage = layout?.userPageRange.lowerBound ?? 4
            let lastUserPage = layout?.userPageRange.upperBound ?? (dump.blocks.count - 1)
            guard lastUserPage >= firstUserPage, firstUserPage < dump.blocks.count else { return }
            let end = min(lastUserPage, dump.blocks.count - 1)
            let userBlocks = Array(dump.blocks[firstUserPage...end])
            try await TagMemoryAccess.writeBlocks(tag: tag, startIndex: firstUserPage, blocks: userBlocks)
        case .iso15693:
            try await TagMemoryAccess.writeBlocks(tag: tag, startIndex: 0, blocks: dump.blocks)
        default:
            throw NFCError.custom("This tag type can't be cloned directly.")
        }
    }
}
