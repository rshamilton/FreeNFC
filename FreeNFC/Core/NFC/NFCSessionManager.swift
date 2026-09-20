import CoreNFC
import Foundation

/// Drives a single NFCTagReaderSession scan and hands the connected tag to a caller-supplied
/// async closure. Every feature (read, write, duplicate, and every Tools screen) shares this
/// one manager instead of each rolling its own session/delegate boilerplate.
@MainActor
final class NFCSessionManager: NSObject, ObservableObject {
    @Published var isScanning = false

    private var activeSession: NFCTagReaderSession?
    private var operation: ((NFCTag, NFCTagReaderSession) async throws -> Void)?
    private var continuation: CheckedContinuation<Result<Void, Error>, Never>?
    private var didResume = false

    /// Starts a scan with the given prompt, runs `operation` against the first tag detected,
    /// and resolves once the session ends (success, failure, or user cancellation).
    @discardableResult
    func perform(
        alertMessage: String,
        pollingOption: NFCTagReaderSession.PollingOption = [.iso14443, .iso15693, .iso18092],
        operation: @escaping (NFCTag, NFCTagReaderSession) async throws -> Void
    ) async -> Result<Void, Error> {
        guard NFCTagReaderSession.readingAvailable else {
            return .failure(NFCError.unavailable)
        }
        self.operation = operation
        self.didResume = false
        guard let session = NFCTagReaderSession(pollingOption: pollingOption, delegate: self, queue: .main) else {
            return .failure(NFCError.unavailable)
        }
        return await withCheckedContinuation { (cont: CheckedContinuation<Result<Void, Error>, Never>) in
            self.continuation = cont
            session.alertMessage = alertMessage
            self.activeSession = session
            self.isScanning = true
            session.begin()
        }
    }

    func cancel() {
        activeSession?.invalidate(errorMessage: "Cancelled")
    }

    private func resume(with result: Result<Void, Error>) {
        guard !didResume else { return }
        didResume = true
        let cont = continuation
        continuation = nil
        operation = nil
        cont?.resume(returning: result)
    }
}

extension NFCSessionManager: NFCTagReaderSessionDelegate {
    nonisolated func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    nonisolated func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        Task { @MainActor in
            self.isScanning = false
            self.activeSession = nil
            self.resume(with: .failure(error))
        }
    }

    nonisolated func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first else { return }
        Task { @MainActor in
            do {
                try await session.connect(to: tag)
                guard let op = self.operation else { return }
                try await op(tag, session)
                self.resume(with: .success(()))
                session.alertMessage = "Done"
                session.invalidate()
            } catch {
                self.resume(with: .failure(error))
                session.invalidate(errorMessage: Self.friendlyMessage(for: error))
            }
        }
    }

    nonisolated static func friendlyMessage(for error: Error) -> String {
        if let appError = error as? LocalizedError, let description = appError.errorDescription {
            return description
        }
        if let readerError = error as? NFCReaderError {
            switch readerError.code {
            case .readerErrorSecurityViolation:
                // Code 2 ("Missing required entitlement") is also raised when Info.plist lacks the
                // ISO 7816 AIDs / FeliCa system codes for a polled technology, not just when the
                // NFC capability is missing -- so don't send people back to Signing & Capabilities.
                return "iOS refused to start the NFC scan (missing required entitlement). This is a build configuration problem: check that the app is signed with the NFC Tag Reading entitlement and that Info.plist lists ISO 7816 select identifiers and FeliCa system codes."
            case .readerErrorRadioDisabled:
                return "Turn on NFC: Settings \u{2192} General \u{2192} NFC (or Airplane Mode may be blocking it)."
            case .readerErrorUnsupportedFeature:
                return "This iPhone doesn't support this NFC feature."
            case .readerSessionInvalidationErrorSessionTimeout:
                return "Timed out waiting for a tag. Try again and hold the tag near the top of the phone."
            case .readerSessionInvalidationErrorSystemIsBusy:
                return "NFC is busy with something else right now. Try again in a moment."
            case .readerSessionInvalidationErrorSessionTerminatedUnexpectedly:
                return "The scan ended unexpectedly. Try again."
            case .readerTransceiveErrorTagConnectionLost:
                return "Lost connection to the tag \u{2014} it moved away from the phone. Hold it steady and try again."
            case .readerTransceiveErrorRetryExceeded, .readerTransceiveErrorTagResponseError:
                return "The tag refused the command. That usually means it's password protected, permanently locked, or encrypted (like a MIFARE Classic or transit card). Scan it on the Read tab to see exactly what's blocking it \u{2014} otherwise hold it more still and try again."
            case .readerTransceiveErrorPacketTooLong:
                return "That command is too long for this tag to handle."
            case .ndefReaderSessionErrorTagNotWritable:
                return "This tag is read-only and can't be written to."
            case .ndefReaderSessionErrorTagUpdateFailure:
                return "Writing to the tag failed. Try holding it steady and try again."
            case .ndefReaderSessionErrorTagSizeTooSmall:
                return "This tag is too small to hold that data."
            case .ndefReaderSessionErrorZeroLengthMessage:
                return "This tag has no NDEF data on it."
            default:
                break
            }
        }
        return error.localizedDescription
    }

    /// True when the user dismissed the system NFC sheet themselves (Cancel, or the sheet
    /// timed out) -- not worth showing as an app error.
    nonisolated static func isUserCancellation(_ error: Error) -> Bool {
        guard let readerError = error as? NFCReaderError else { return false }
        switch readerError.code {
        case .readerSessionInvalidationErrorUserCanceled:
            return true
        default:
            return false
        }
    }
}

/// Resolves a connected NFCTag down to its underlying NFCNDEFTag conformance, since MIFARE,
/// ISO15693, ISO7816, and FeliCa tags all adopt that protocol for the shared read/write API.
func ndefTag(from tag: NFCTag) -> NFCNDEFTag {
    switch tag {
    case .miFare(let t): return t
    case .iso15693(let t): return t
    case .iso7816(let t): return t
    case .feliCa(let t): return t
    @unknown default:
        preconditionFailure("Unsupported NFCTag case")
    }
}
