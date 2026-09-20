import Foundation

enum NFCError: LocalizedError {
    case unavailable
    case noTagDetected
    case unsupportedTag
    case classicNotSupported
    case notNDEFFormatted
    case tagNotWritable
    case payloadTooLarge(capacity: Int, needed: Int)
    case invalidResponse
    case wrongPassword
    case cancelled
    case protectedPage(page: Int, area: String)
    case custom(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "This device doesn't support NFC scanning."
        case .noTagDetected:
            return "No tag was detected. Try again."
        case .unsupportedTag:
            return "This tag type isn't recognized."
        case .classicNotSupported:
            return "MIFARE Classic cards are read-only on iPhone. Apple blocks the authentication commands needed to read or write sectors, so only the UID is available."
        case .notNDEFFormatted:
            return "This tag isn't NDEF formatted yet. Use Tools → Format first."
        case .tagNotWritable:
            return "This tag is locked or read-only."
        case .payloadTooLarge(let capacity, let needed):
            return "This tag holds \(capacity) bytes, but \(needed) bytes are needed. Use a larger tag or shorten the content."
        case .invalidResponse:
            return "The tag sent back an unexpected response."
        case .wrongPassword:
            return "Incorrect password."
        case .cancelled:
            return "Cancelled."
        case .protectedPage(let page, let area):
            return "Refusing to write page \(page) \u{2014} that's the tag's \(area). Writing there can permanently brick the tag (make it read-only or password-lock it). Turn on \u{201C}Allow writing protected pages\u{201D} only if you know exactly what you're doing, or use the Password / Lock tools instead."
        case .custom(let message):
            return message
        }
    }
}
