import CoreNFC

/// The "scan a tag and describe everything about it" flow shared by Read and Duplicate's
/// save-a-source-tag step.
enum TagScanner {
    static func scan(using nfc: NFCSessionManager, alertMessage: String = "Hold your iPhone near the tag.") async -> Result<ScannedTag, Error> {
        var result: ScannedTag?

        let outcome = await nfc.perform(alertMessage: alertMessage) { tag, session in
            let family = TagFamilyResolver.family(for: tag)
            let uid = TagFamilyResolver.uidData(for: tag)
            let readableTag = ndefTag(from: tag)

            var status: NFCNDEFStatus?
            var capacity: Int?
            var message: NFCNDEFMessage?
            if let queried = try? await NDEFReader.status(of: readableTag) {
                status = queried.status
                capacity = queried.capacity
                if queried.status != .notSupported {
                    message = try? await NDEFReader.readMessage(from: readableTag)
                }
            }

            var dump: TagDump?
            if family.supportsRawMemoryAccess {
                dump = try? await TagMemoryAccess.dump(tag: tag)
            }

            // Gathered last: the optional chip queries can halt a tag if it refuses them.
            let details = await TagDetailsReader.read(from: tag, dump: dump)

            result = ScannedTag(
                uid: uid.hexString,
                family: family,
                techDetail: dump?.chipLabel,
                ndefStatus: status,
                ndefCapacity: capacity,
                records: NDEFReader.records(from: message),
                dump: dump,
                details: details.isEmpty ? nil : details
            )
        }

        switch outcome {
        case .success:
            guard let result else { return .failure(NFCError.custom("Something went wrong reading that tag.")) }
            return .success(result)
        case .failure(let error):
            return .failure(error)
        }
    }
}
