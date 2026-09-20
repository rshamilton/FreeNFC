import CoreNFC
import Foundation

/// A family-agnostic snapshot of a tag's raw memory, used by Read's memory-dump view,
/// the Duplicate flow, and the Bin Dump tool.
struct TagDump: Codable, Hashable {
    let familyRawValue: String
    let blockSize: Int
    let blocks: [Data]
    let chipLabel: String?

    var family: TagFamily { TagFamily(rawValue: familyRawValue) ?? .unknown }
    var totalBytes: Int { blocks.reduce(0) { $0 + $1.count } }
    var flatData: Data { blocks.reduce(into: Data()) { $0.append($1) } }

    init(family: TagFamily, blockSize: Int, blocks: [Data], chipLabel: String? = nil) {
        self.familyRawValue = family.rawValue
        self.blockSize = blockSize
        self.blocks = blocks
        self.chipLabel = chipLabel
    }
}

/// Generic dump/write primitives that don't care which specific tag family they're talking to.
/// Feature code decides *which* blocks matter (e.g. skipping UID/lock pages when duplicating).
enum TagMemoryAccess {
    static func dump(tag: NFCTag) async throws -> TagDump {
        let family = TagFamilyResolver.family(for: tag)
        switch tag {
        case .miFare(let t):
            guard family == .ultralightOrNTAG else { throw NFCError.classicNotSupported }
            let (layout, pages) = try await t.ulFullDump()
            return TagDump(family: family, blockSize: 4, blocks: pages, chipLabel: layout?.name)
        case .iso15693(let t):
            let (blockSize, blocks) = try await t.iso15693FullDump()
            return TagDump(family: family, blockSize: blockSize, blocks: blocks, chipLabel: nil)
        case .iso7816, .feliCa:
            throw NFCError.custom("Raw memory dumping isn't available for this tag type. Use Manual Commands to talk to it directly.")
        @unknown default:
            throw NFCError.unsupportedTag
        }
    }

    /// Writes a run of consecutive blocks starting at `startIndex`. On MIFARE Ultralight /
    /// NTAG the lock/config/password pages are *skipped* (not written) unless
    /// `allowProtectedPages` is set, so restoring a full dump can't brick the tag while still
    /// writing every user page. Returns the number of blocks actually written.
    @discardableResult
    static func writeBlocks(tag: NFCTag, startIndex: Int, blocks: [Data], allowProtectedPages: Bool = false) async throws -> Int {
        var written = 0
        switch tag {
        case .miFare(let t):
            let guardInfo = allowProtectedPages ? nil : await MifareWriteGuard.make(for: t)
            for (offset, block) in blocks.enumerated() {
                let page = startIndex + offset
                if let guardInfo, (try? guardInfo.check(page)) == nil { continue } // skip protected page
                try await t.ulWrite(page: page, bytes: block)
                written += 1
            }
            return written
        case .iso15693(let t):
            for (offset, block) in blocks.enumerated() {
                try await t.iso15693Write(block: startIndex + offset, data: block)
                written += 1
            }
            return written
        default:
            throw NFCError.custom("This tag type doesn't support direct block writes.")
        }
    }

    /// Writes a set of individually-addressed blocks (the memory editor's use case), with the
    /// same protected-page guard as `writeBlocks(tag:startIndex:...)`.
    static func writeBlocks(tag: NFCTag, blocks: [Int: Data], allowProtectedPages: Bool = false) async throws {
        switch tag {
        case .miFare(let t):
            let guardInfo = allowProtectedPages ? nil : await MifareWriteGuard.make(for: t)
            for (page, data) in blocks.sorted(by: { $0.key < $1.key }) {
                try guardInfo?.check(page)
                try await t.ulWrite(page: page, bytes: data)
            }
        case .iso15693(let t):
            for (block, data) in blocks.sorted(by: { $0.key < $1.key }) {
                try await t.iso15693Write(block: block, data: data)
            }
        default:
            throw NFCError.custom("This tag type doesn't support direct block writes.")
        }
    }
}
