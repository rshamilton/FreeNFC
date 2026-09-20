import Foundation
import CoreNFC

/// Owns the bridge server and turns computer requests into real NFC operations using the app's
/// shared `NFCSessionManager`. Every NFC call still runs on the phone with Apple's system sheet;
/// the computer only *asks* for scans and writes.
@MainActor
final class ComputerBridgeController: ObservableObject {
    let server = ComputerBridgeServer()

    /// The user's on/off intent. Kept separate from `server.status` so the toggle stays where
    /// the user put it while the listener negotiates Local Network permission.
    @Published var isEnabled = false

    private weak var nfc: NFCSessionManager?
    private var wired = false

    deinit {
        server.stop()
    }

    /// Connects the controller to the shared NFC manager and installs the server callbacks.
    /// Safe to call every time the screen appears.
    func attach(to nfc: NFCSessionManager) {
        self.nfc = nfc
        guard !wired else { return }
        wired = true
        server.onScanRequested = { [weak self] in self?.handleScanRequest() }
        server.onWriteTextRequested = { [weak self] text in self?.handleWriteRequest(text) }
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if enabled {
            server.start()
        } else {
            server.stop()
        }
    }

    // MARK: - Presentation

    var statusTitle: String {
        switch server.status {
        case .off: return "Reader is off"
        case .starting: return "Starting\u{2026}"
        case .waitingForPermission: return "Waiting for permission"
        case .running: return "Reader is on"
        case .failed: return "Couldn't start"
        }
    }

    var statusDetail: String {
        switch server.status {
        case .off:
            return "Turn it on, then open the address on your computer."
        case .starting:
            return "Bringing up the local server\u{2026}"
        case .waitingForPermission(let message):
            return message
        case .running:
            let count = server.clientCount
            return "\(count) computer\(count == 1 ? "" : "s") connected"
        case .failed(let message):
            return message
        }
    }

    var statusSymbol: String {
        switch server.status {
        case .running: return "wifi.circle.fill"
        case .starting, .waitingForPermission: return "clock.arrow.circlepath"
        case .failed: return "exclamationmark.triangle.fill"
        case .off: return "wifi.slash"
        }
    }

    /// The URL a computer on the same Wi-Fi should open.
    var browserURL: String? {
        guard server.isRunning, server.port != 0, let ip = LocalNetwork.wifiIPv4Address() else { return nil }
        return "http://\(ip):\(server.port)"
    }

    /// True when the server is up but the phone has no Wi-Fi address to advertise.
    var isRunningWithoutWiFi: Bool {
        server.isRunning && LocalNetwork.wifiIPv4Address() == nil
    }

    // MARK: - Requests from a computer (or the local "Scan now" button)

    func handleScanRequest() {
        guard let nfc, !nfc.isScanning else { return }
        server.send(BridgeEvent(type: "status", payload: ["message": "Scanning\u{2026} hold a tag to the iPhone."]))
        Task {
            let outcome = await TagScanner.scan(using: nfc, alertMessage: "Hold a tag near the iPhone for your computer.")
            switch outcome {
            case .success(let tag):
                server.send(Self.scanEvent(tag))
            case .failure(let error):
                if !NFCSessionManager.isUserCancellation(error) {
                    server.send(BridgeEvent(type: "error-event", payload: ["message": NFCSessionManager.friendlyMessage(for: error)]))
                }
            }
        }
    }

    func handleWriteRequest(_ text: String) {
        guard let nfc, !nfc.isScanning else { return }
        guard let payload = NDEFWriter.text(text) else {
            server.send(BridgeEvent(type: "error-event", payload: ["message": "Couldn't build a text record."]))
            return
        }
        server.send(BridgeEvent(type: "status", payload: ["message": "Writing\u{2026} hold a tag to the iPhone."]))
        Task {
            let message = NFCNDEFMessage(records: [payload])
            let outcome = await nfc.perform(alertMessage: "Hold a tag near the iPhone to write.") { tag, _ in
                try await NDEFWriter.write(message, to: tag)
            }
            switch outcome {
            case .success:
                server.send(BridgeEvent(type: "status", payload: ["message": "Wrote \u{201C}\(text)\u{201D} to the tag."]))
            case .failure(let error):
                if !NFCSessionManager.isUserCancellation(error) {
                    server.send(BridgeEvent(type: "error-event", payload: ["message": NFCSessionManager.friendlyMessage(for: error)]))
                }
            }
        }
    }

    // MARK: - Serialization

    static func scanEvent(_ tag: ScannedTag) -> BridgeEvent {
        var payload: [String: Any] = [
            "uid": tag.uid,
            "family": tag.family.rawValue,
            "ndefStatus": tag.ndefStatusLabel,
        ]
        if let chip = tag.techDetail { payload["chip"] = chip }
        if let capacity = tag.ndefCapacity { payload["capacity"] = capacity }
        payload["records"] = tag.records.map { record -> [String: String] in
            ["kind": record.kindLabel, "value": record.displayString ?? record.rawHexString]
        }
        payload["issues"] = TagDiagnostics.issues(for: tag).map { issue -> [String: String] in
            ["severity": issue.severity.rawValue, "title": issue.title, "detail": issue.detail]
        }
        if let dump = tag.dump {
            payload["memoryHex"] = dump.flatData.hexString
            payload["memoryBytes"] = dump.totalBytes
        }
        return BridgeEvent(type: "scan", payload: payload)
    }
}
