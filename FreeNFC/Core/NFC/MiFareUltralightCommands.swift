import CoreNFC

/// Raw MIFARE Ultralight / NTAG21x command bytes, sent via NFCMiFareTag.sendMiFareCommand.
/// These work for the Ultralight/NTAG family only -- MIFARE Classic's authentication
/// command is deliberately blocked by CoreNFC and is not implemented here.
enum UltralightCommand {
    static let getVersion: UInt8 = 0x60
    static let read: UInt8 = 0x30
    static let fastRead: UInt8 = 0x3A
    static let write: UInt8 = 0xA2
    static let pwdAuth: UInt8 = 0x1B
    static let readSignature: UInt8 = 0x3C
    static let readCounter: UInt8 = 0x39
}

/// Page layout for the common NTAG21x family, derived from the GET_VERSION response.
/// Falls back to page-by-page probing for tags this table doesn't recognize (generic
/// MIFARE Ultralight / Ultralight EV1 / third-party NTAG-compatible chips).
struct NTAGLayout {
    let name: String
    let totalPages: Int
    let userPageRange: ClosedRange<Int>
    let dynamicLockPage: Int
    let cfg0Page: Int   // AUTH0: page number where password protection begins
    let cfg1Page: Int   // ACCESS byte: protection direction, auth limit
    let pwdPage: Int
    let packPage: Int

    static let ccPage = 3

    static func from(versionResponse data: Data) -> NTAGLayout? {
        guard data.count >= 8 else { return nil }
        switch data[6] {
        case 0x0F: return .ntag213
        case 0x11: return .ntag215
        case 0x13: return .ntag216
        default: return nil
        }
    }

    /// Looks up a layout by the chip name recorded in a saved dump (e.g. "NTAG215").
    static func named(_ name: String?) -> NTAGLayout? {
        switch name {
        case NTAGLayout.ntag213.name: return .ntag213
        case NTAGLayout.ntag215.name: return .ntag215
        case NTAGLayout.ntag216.name: return .ntag216
        default: return nil
        }
    }

    static let ntag213 = NTAGLayout(name: "NTAG213", totalPages: 45, userPageRange: 4...39, dynamicLockPage: 40, cfg0Page: 41, cfg1Page: 42, pwdPage: 43, packPage: 44)
    static let ntag215 = NTAGLayout(name: "NTAG215", totalPages: 135, userPageRange: 4...129, dynamicLockPage: 130, cfg0Page: 131, cfg1Page: 132, pwdPage: 133, packPage: 134)
    static let ntag216 = NTAGLayout(name: "NTAG216", totalPages: 231, userPageRange: 4...225, dynamicLockPage: 226, cfg0Page: 227, cfg1Page: 228, pwdPage: 229, packPage: 230)

    /// True for the pages an ordinary user-data write must never touch: writing them changes
    /// lock bits, the capability container, or the password/config that password-locks the tag.
    func isProtectedPage(_ page: Int) -> Bool {
        page <= NTAGLayout.ccPage || page >= dynamicLockPage
    }

    /// A human name for why a page is off-limits, used in error messages.
    func protectedAreaName(for page: Int) -> String {
        if page <= 1 { return "UID (factory-locked)" }
        if page == 2 { return "static lock bytes" }
        if page == NTAGLayout.ccPage { return "capability container" }
        if page == dynamicLockPage { return "dynamic lock bytes" }
        if page == cfg0Page || page == cfg1Page { return "configuration pages" }
        if page == pwdPage { return "password page" }
        if page == packPage { return "password-acknowledge (PACK) page" }
        return "reserved area"
    }
}

/// Decides whether a given page write is safe for a MIFARE Ultralight / NTAG tag, so no
/// feature can accidentally write the lock/config/password pages and brick a tag. Built once
/// per scan from the connected tag's GET_VERSION, then consulted for every page in a batch.
struct MifareWriteGuard {
    let layout: NTAGLayout?

    static func make(for tag: NFCMiFareTag) async -> MifareWriteGuard {
        let layout = await tag.ulGetVersion().flatMap(NTAGLayout.from(versionResponse:))
        return MifareWriteGuard(layout: layout)
    }

    /// Throws `NFCError.protectedPage` if writing `page` would risk bricking the tag.
    func check(_ page: Int) throws {
        if let layout {
            if layout.isProtectedPage(page) {
                throw NFCError.protectedPage(page: page, area: layout.protectedAreaName(for: page))
            }
        } else if page <= NTAGLayout.ccPage {
            // Unknown chip: we can't locate its config pages, so only the header is certain.
            let area = page <= 1 ? "UID (factory-locked)" : (page == 2 ? "static lock bytes" : "capability container")
            throw NFCError.protectedPage(page: page, area: area)
        }
    }
}

extension NFCMiFareTag {
    /// Full GET_VERSION response (8 bytes) identifying the chip, or nil if unsupported.
    func ulGetVersion() async -> Data? {
        try? await sendMiFareCommand(commandPacket: Data([UltralightCommand.getVersion]))
    }

    /// Reads 4 consecutive pages (16 bytes) starting at `page`.
    func ulRead(page: Int) async throws -> Data {
        let response = try await sendMiFareCommand(commandPacket: Data([UltralightCommand.read, UInt8(page)]))
        guard response.count >= 4 else { throw NFCError.invalidResponse }
        return response
    }

    /// Reads a contiguous page range in one shot via FAST_READ.
    func ulFastRead(from startPage: Int, to endPage: Int) async throws -> Data {
        let response = try await sendMiFareCommand(commandPacket: Data([UltralightCommand.fastRead, UInt8(startPage), UInt8(endPage)]))
        let expected = (endPage - startPage + 1) * 4
        guard response.count >= expected else { throw NFCError.invalidResponse }
        return response
    }

    /// The chip's 32-byte ECC originality signature (NXP READ_SIG). Non-genuine or older chips
    /// NAK this, so callers should treat a throw as "not available".
    func ulReadSignature() async throws -> Data {
        let response = try await sendMiFareCommand(commandPacket: Data([UltralightCommand.readSignature, 0x00]))
        guard response.count >= 32 else { throw NFCError.invalidResponse }
        return Data(response.prefix(32))
    }

    /// The NFC read counter (how many times the tag has been read), if the chip has it enabled.
    func ulReadCounter(index: UInt8 = 0x02) async throws -> Int {
        let response = try await sendMiFareCommand(commandPacket: Data([UltralightCommand.readCounter, index]))
        guard response.count >= 3 else { throw NFCError.invalidResponse }
        return Int(response[0]) | (Int(response[1]) << 8) | (Int(response[2]) << 16)
    }

    /// Writes exactly one 4-byte page.
    func ulWrite(page: Int, bytes: Data) async throws {
        guard bytes.count == 4 else { throw NFCError.custom("A page is exactly 4 bytes.") }
        _ = try await sendMiFareCommand(commandPacket: Data([UltralightCommand.write, UInt8(page)]) + bytes)
    }

    /// Authenticates with a 4-byte password, returning the 2-byte PACK on success.
    @discardableResult
    func ulPasswordAuth(password: Data) async throws -> Data {
        guard password.count == 4 else { throw NFCError.custom("Passwords are 4 bytes.") }
        do {
            let response = try await sendMiFareCommand(commandPacket: Data([UltralightCommand.pwdAuth]) + password)
            guard response.count >= 2 else { throw NFCError.invalidResponse }
            return response
        } catch {
            throw NFCError.wrongPassword
        }
    }

    /// Initializes a blank Ultralight/NTAG tag for NDEF: writes the Capability Container
    /// (page 3) sized to the chip's user memory, then an empty NDEF message TLV so the tag
    /// reads as "formatted but empty" afterward. Only works for chips this app can identify
    /// via GET_VERSION -- unrecognized chips need a known memory size to build a correct CC.
    func ulFormatAsNDEF() async throws {
        guard let versionData = await ulGetVersion(), let layout = NTAGLayout.from(versionResponse: versionData) else {
            throw NFCError.custom("Unrecognized chip \u{2014} can't determine its memory size to format it safely.")
        }
        let userBytes = (layout.userPageRange.upperBound - layout.userPageRange.lowerBound + 1) * 4
        let sizeByte = UInt8(clamping: userBytes / 8)
        let cc = Data([0xE1, 0x10, sizeByte, 0x00])
        try await ulWrite(page: NTAGLayout.ccPage, bytes: cc)

        // Empty NDEF message TLV: Type(0x03) Length(0x03) [D0 00 00] Terminator(0xFE)
        try await ulWrite(page: layout.userPageRange.lowerBound, bytes: Data([0x03, 0x03, 0xD0, 0x00]))
        try await ulWrite(page: layout.userPageRange.lowerBound + 1, bytes: Data([0x00, 0xFE, 0x00, 0x00]))
    }

    /// Looks up this chip's NTAG21x layout via GET_VERSION, or throws a friendly error.
    func ulRequireLayout() async throws -> NTAGLayout {
        guard let versionData = await ulGetVersion(), let layout = NTAGLayout.from(versionResponse: versionData) else {
            throw NFCError.custom("Unrecognized chip \u{2014} can't locate its password/config pages.")
        }
        return layout
    }

    /// Protects the tag with a new 4-byte password, requiring PWD_AUTH for every page from
    /// the start of user memory onward. Assumes the tag isn't already password-protected.
    func ulSetPassword(password: Data, pack: Data, layout: NTAGLayout) async throws {
        try await ulWrite(page: layout.pwdPage, bytes: password)
        try await ulWrite(page: layout.packPage, bytes: pack + Data([0x00, 0x00]))
        try await ulSetAuth0(layout.userPageRange.lowerBound, layout: layout)
    }

    /// Re-authenticates with the current password, then installs a new one.
    func ulChangePassword(current: Data, newPassword: Data, newPack: Data, layout: NTAGLayout) async throws {
        try await ulPasswordAuth(password: current)
        try await ulWrite(page: layout.pwdPage, bytes: newPassword)
        try await ulWrite(page: layout.packPage, bytes: newPack + Data([0x00, 0x00]))
    }

    /// Re-authenticates with the current password, then disables protection (AUTH0 = 0xFF).
    func ulRemovePassword(current: Data, layout: NTAGLayout) async throws {
        try await ulPasswordAuth(password: current)
        try await ulSetAuth0(0xFF, layout: layout)
    }

    /// Recovers a tag that was accidentally password-locked: authenticates with one password,
    /// then clears protection and restores the factory configuration.
    ///
    /// Deliberately takes a *single* password rather than a list. An Ultralight/NTAG tag stops
    /// answering as soon as it rejects a PWD_AUTH, so any further attempt in the same session
    /// fails no matter what it sends — a multi-password loop would report "wrong password" even
    /// when a later candidate was correct. The caller retries one password per scan instead.
    func ulRecoverProtection(password: Data, layout: NTAGLayout) async throws {
        try await ulPasswordAuth(password: password)
        try await ulRestoreFactoryProtection(layout: layout)
    }

    /// Sets AUTH0 — the first password-protected page. 0xFF disables protection entirely.
    ///
    /// AUTH0 is **byte 3** of CFG0, whose layout is [MIRROR, RFUI, MIRROR_PAGE, AUTH0]. Writing
    /// byte 0 instead sets the mirror configuration and silently leaves protection untouched.
    private func ulSetAuth0(_ value: Int, layout: NTAGLayout) async throws {
        let current = try await ulRead(page: layout.cfg0Page)
        var cfg0 = Data(current.prefix(4))
        cfg0[3] = UInt8(clamping: value)
        try await ulWrite(page: layout.cfg0Page, bytes: cfg0)
    }

    /// Puts the protection configuration back to NXP factory values. The session must already be
    /// authenticated. Rewrites CFG0 wholesale so a previously-corrupted MIRROR byte is repaired
    /// too, clears the ACCESS byte (PROT / CFGLCK / AUTHLIM), and resets PWD/PACK.
    func ulRestoreFactoryProtection(layout: NTAGLayout) async throws {
        // CFG0: MIRROR = 0x04 (factory), MIRROR_PAGE = 0, AUTH0 = 0xFF (protection off).
        try await ulWrite(page: layout.cfg0Page, bytes: Data([0x04, 0x00, 0x00, 0xFF]))

        // CFG1: clear the ACCESS byte, preserving the rest if it can still be read.
        var cfg1 = Data([0x00, 0x05, 0x00, 0x00])
        if let current = try? await ulRead(page: layout.cfg1Page), current.count >= 4 {
            cfg1 = Data(current.prefix(4))
            cfg1[0] = 0x00
        }
        try await ulWrite(page: layout.cfg1Page, bytes: cfg1)

        try await ulWrite(page: layout.pwdPage, bytes: Data([0xFF, 0xFF, 0xFF, 0xFF]))
        try await ulWrite(page: layout.packPage, bytes: Data([0x00, 0x00, 0x00, 0x00]))
    }

    /// Dumps every user + config page it can reach. Uses the known NTAG21x layout when
    /// GET_VERSION is recognized, otherwise probes page-by-page until a read fails.
    func ulFullDump() async throws -> (layout: NTAGLayout?, pages: [Data]) {
        var pages: [Data] = []

        if let versionData = await ulGetVersion(), let layout = NTAGLayout.from(versionResponse: versionData) {
            var page = 0
            while page < layout.totalPages {
                let chunkEnd = min(page + 3, layout.totalPages - 1)
                let chunk = try await ulFastRead(from: page, to: chunkEnd)
                for offset in stride(from: 0, to: chunk.count, by: 4) {
                    pages.append(chunk.subdata(in: offset..<offset + 4))
                }
                page = chunkEnd + 1
            }
            return (layout, Array(pages.prefix(layout.totalPages)))
        }

        // Unknown chip: probe sequentially until the tag stops answering.
        var page = 0
        while page < 256 {
            do {
                let quad = try await ulRead(page: page)
                pages.append(quad.subdata(in: 0..<4))
                page += 1
            } catch {
                break
            }
        }
        return (nil, pages)
    }
}
