import CoreNFC
import Foundation

/// Collects every extra fact we can get about a connected tag.
///
/// Order matters: anything derivable from the memory dump we already have is taken from there
/// (no extra commands, no risk), and the commands a chip might refuse — READ_SIG, READ_CNT —
/// are sent *last*, because a NAK puts an Ultralight/NTAG tag into HALT and would break any
/// command issued after it.
enum TagDetailsReader {
    static func read(from tag: NFCTag, dump: TagDump?) async -> TagDetails {
        var details = TagDetails()

        switch tag {
        case .miFare(let mifare):
            details.historicalBytes = mifare.historicalBytes
            details.versionBytes = await mifare.ulGetVersion()

            // Pull the capability container, lock bytes and config pages out of the dump we
            // already read, rather than re-reading them off the tag.
            if let dump, dump.blockSize == 4 {
                let blocks = dump.blocks
                if blocks.count > NTAGLayout.ccPage {
                    details.capabilityContainer = Data(blocks[NTAGLayout.ccPage])
                }
                if blocks.count > 2, blocks[2].count >= 4 {
                    details.staticLockBytes = Data(blocks[2].suffix(2))
                }
                if let versionBytes = details.versionBytes,
                   let layout = NTAGLayout.from(versionResponse: versionBytes) {
                    if blocks.count > layout.dynamicLockPage {
                        details.dynamicLockBytes = Data(blocks[layout.dynamicLockPage].prefix(3))
                    }
                    if blocks.count > layout.cfg0Page {
                        details.configPage0 = Data(blocks[layout.cfg0Page])
                    }
                    if blocks.count > layout.cfg1Page {
                        details.configPage1 = Data(blocks[layout.cfg1Page])
                    }
                }
            }

            // Riskiest last: these may NAK and halt the tag.
            details.signature = try? await mifare.ulReadSignature()
            details.readCounter = try? await mifare.ulReadCounter()

        case .iso15693(let tag15693):
            details.icManufacturerCode = Int(tag15693.icManufacturerCode)
            details.icSerialNumber = tag15693.icSerialNumber
            if let info = try? await tag15693.iso15693SystemInfo() {
                details.dsfid = info.dsfid
                details.afi = info.afi
                details.blockSize = info.blockSize
                details.blockCount = info.blockCount
                details.icReference = info.icReference
            }

        case .iso7816(let tag7816):
            details.applicationIdentifier = tag7816.initialSelectedAID
            details.historicalBytes = tag7816.historicalBytes
            details.applicationData = tag7816.applicationData
            details.proprietaryApplicationDataCoding = tag7816.proprietaryApplicationDataCoding

        case .feliCa(let felica):
            details.systemCode = felica.currentSystemCode

        @unknown default:
            break
        }

        return details
    }
}
