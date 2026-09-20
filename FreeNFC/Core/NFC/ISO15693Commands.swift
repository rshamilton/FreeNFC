import CoreNFC
import Foundation
import ObjectiveC

struct ISO15693SystemInfo {
    let dsfid: Int
    let afi: Int
    let blockSize: Int
    let blockCount: Int
    let icReference: Int
}

/// Thin, friendlier wrappers around the built-in NFCISO15693Tag block/lock/custom-command API.
extension NFCISO15693Tag {
    private typealias SystemInfoBlock = @convention(block) (Int, Int, Int, Int, Int, Error?) -> Void
    private typealias GetSystemInfoFn = @convention(c) (AnyObject, Selector, UInt8, SystemInfoBlock) -> Void

    func iso15693SystemInfo() async throws -> ISO15693SystemInfo {
        try await withCheckedThrowingContinuation { continuation in
            let selector = NSSelectorFromString("getSystemInfoWithRequestFlag:completionHandler:")
            guard let method = class_getInstanceMethod(Swift.type(of: self), selector) else {
                continuation.resume(throwing: NFCError.custom("ISO 15693 system info is unavailable."))
                return
            }
            let imp = method_getImplementation(method)
            let caller = unsafeBitCast(imp, to: GetSystemInfoFn.self)
            let flags = NFCISO15693RequestFlag([.highDataRate, .address]).rawValue

            let block: SystemInfoBlock = { dsfid, afi, blockSize, blockCount, icReference, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ISO15693SystemInfo(
                        dsfid: dsfid,
                        afi: afi,
                        blockSize: blockSize,
                        blockCount: blockCount,
                        icReference: icReference
                    ))
                }
            }

            caller(self, selector, flags, block)
        }
    }

    func iso15693Read(block: Int) async throws -> Data {
        guard let blockByte = UInt8(exactly: block) else { throw NFCError.custom("Block number must be 0–255.") }
        return try await readSingleBlock(requestFlags: [.highDataRate, .address], blockNumber: blockByte)
    }

    func iso15693ReadRange(from start: Int, count: Int) async throws -> [Data] {
        try await readMultipleBlocks(requestFlags: [.highDataRate, .address], blockRange: NSRange(location: start, length: count))
    }

    func iso15693Write(block: Int, data: Data) async throws {
        guard let blockByte = UInt8(exactly: block) else { throw NFCError.custom("Block number must be 0–255.") }
        try await writeSingleBlock(requestFlags: [.highDataRate, .address], blockNumber: blockByte, dataBlock: data)
    }

    func iso15693Lock(block: Int) async throws {
        guard let blockByte = UInt8(exactly: block) else { throw NFCError.custom("Block number must be 0–255.") }
        try await lockBlock(requestFlags: [.highDataRate, .address], blockNumber: blockByte)
    }

    /// Sends a raw ISO 15693 custom command (used by the Manual Commands tool).
    func iso15693Custom(code: UInt8, parameters: Data) async throws -> Data {
        try await customCommand(requestFlags: [.highDataRate, .address], customCommandCode: Int(code), customRequestParameters: parameters)
    }

    /// Dumps every readable block up to the tag's reported capacity.
    func iso15693FullDump() async throws -> (blockSize: Int, blocks: [Data]) {
        let info = try await iso15693SystemInfo()
        var blocks: [Data] = []
        var index = 0
        while index < info.blockCount {
            let chunk = min(info.blockCount - index, 32)
            let read = try await iso15693ReadRange(from: index, count: chunk)
            blocks.append(contentsOf: read)
            index += chunk
        }
        return (info.blockSize, blocks)
    }
}
