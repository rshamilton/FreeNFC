import Foundation
import Network

/// A structured event pushed to connected computers over Server-Sent Events.
struct BridgeEvent {
    let type: String
    let payload: [String: Any]

    var sseData: Data {
        var object = payload
        object["type"] = type
        let json = (try? JSONSerialization.data(withJSONObject: object)) ?? Data("{}".utf8)
        let jsonString = String(data: json, encoding: .utf8) ?? "{}"
        return Data("event: \(type)\ndata: \(jsonString)\n\n".utf8)
    }
}

/// One line in the on-device activity log shown on the Computer Reader screen.
struct BridgeLogEntry: Identifiable {
    let id = UUID()
    let date = Date()
    let message: String
}

/// What the server is actually doing. Kept separate from the user's on/off intent so the
/// toggle never snaps back while the listener is still coming up (notably while iOS is showing
/// the Local Network permission prompt, which puts the listener in `.waiting`).
enum BridgeStatus: Equatable {
    case off
    case starting
    case waitingForPermission(String)
    case running
    case failed(String)

    var isActive: Bool {
        switch self {
        case .off, .failed: return false
        case .starting, .waitingForPermission, .running: return true
        }
    }
}

/// A tiny embedded HTTP/1.1 + Server-Sent-Events server that turns this iPhone into an NFC
/// reader for a computer on the same Wi-Fi network. The Mac (or any browser) opens the phone's
/// address, sees scans stream in live, and can ask the phone to read or write a tag. The phone
/// stays in charge of the NFC hardware — every scan still shows Apple's system sheet — so this
/// is a bridge, not a background reader.
///
/// Networking runs on a private serial queue; all `@Published` UI state is republished on the
/// main queue. Requests that need NFC are handed back to the app through `onScanRequested` /
/// `onWriteTextRequested`, which are always invoked on the main queue.
final class ComputerBridgeServer: ObservableObject {
    @Published private(set) var status: BridgeStatus = .off
    @Published private(set) var port: UInt16 = 0
    @Published private(set) var clientCount = 0
    @Published private(set) var log: [BridgeLogEntry] = []

    var isRunning: Bool { status == .running }

    /// Called on the main queue when a connected computer asks the phone to scan a tag.
    var onScanRequested: (() -> Void)?
    /// Called on the main queue when a computer asks the phone to write text to the next tag.
    var onWriteTextRequested: ((String) -> Void)?

    private let serviceName: String
    private let queue = DispatchQueue(label: "com.ryan.freenfc.bridge")
    private var listener: NWListener?
    private var eventClients: [ObjectIdentifier: NWConnection] = [:]
    private var didFallBackToAnyPort = false

    init(serviceName: String = "Free NFC Reader") {
        self.serviceName = serviceName
    }

    // MARK: - Lifecycle

    func start(preferredPort: UInt16 = 8080) {
        queue.async { [weak self] in
            guard let self else { return }
            self.didFallBackToAnyPort = false
            self._start(preferredPort: preferredPort)
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self._stop(status: .off)
        }
    }

    /// Broadcasts a structured event to every connected computer.
    func send(_ event: BridgeEvent) {
        queue.async { [weak self] in
            guard let self else { return }
            let data = event.sseData
            for (id, connection) in self.eventClients {
                connection.send(content: data, completion: .contentProcessed { [weak self] error in
                    if error != nil { self?.queue.async { self?.dropClient(id) } }
                })
            }
        }
    }

    // MARK: - Server (private queue)

    private func _start(preferredPort: UInt16) {
        tearDownListener()
        publish { self.status = .starting }

        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true

            let listener: NWListener
            if preferredPort != 0, let port = NWEndpoint.Port(rawValue: preferredPort) {
                listener = try NWListener(using: params, on: port)
            } else {
                listener = try NWListener(using: params) // system picks a free port
            }
            listener.service = NWListener.Service(name: serviceName, type: "_freenfc._tcp")

            listener.stateUpdateHandler = { [weak self] state in
                self?.handleListenerState(state, preferredPort: preferredPort)
            }
            listener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }
            listener.start(queue: queue)
            self.listener = listener
        } catch {
            appendLog("Couldn't start server: \(error.localizedDescription)")
            publish { self.status = .failed(error.localizedDescription) }
        }
    }

    private func handleListenerState(_ state: NWListener.State, preferredPort: UInt16) {
        switch state {
        case .ready:
            let resolvedPort = listener?.port?.rawValue ?? preferredPort
            publish {
                self.status = .running
                self.port = resolvedPort
            }
            appendLog("Reader ready on port \(resolvedPort).")

        case .waiting(let error):
            // Most commonly: iOS is waiting on the Local Network permission prompt, or Wi-Fi
            // isn't up yet. The listener recovers by itself once that resolves, so stay alive.
            let message = Self.describe(error)
            publish { self.status = .waitingForPermission(message) }
            appendLog("Waiting: \(message)")

        case .failed(let error):
            // Port already taken? Retry once letting the system choose a free port.
            if case .posix(let code) = error, code == .EADDRINUSE, !didFallBackToAnyPort {
                didFallBackToAnyPort = true
                appendLog("Port \(preferredPort) is busy — picking another.")
                _start(preferredPort: 0)
                return
            }
            let message = Self.describe(error)
            appendLog("Failed: \(message)")
            _stop(status: .failed(message))

        case .cancelled:
            publish { self.status = .off }

        default:
            break
        }
    }

    private static func describe(_ error: NWError) -> String {
        if case .posix(let code) = error {
            switch code {
            case .EADDRINUSE: return "That port is already in use."
            case .EACCES, .EPERM:
                return "Local Network access is off. Allow it in Settings → Free NFC → Local Network."
            case .ENETDOWN, .EHOSTUNREACH, .ENETUNREACH:
                return "No network. Connect the iPhone to Wi-Fi."
            default: break
            }
        }
        return error.localizedDescription
    }

    private func tearDownListener() {
        for (_, connection) in eventClients { connection.cancel() }
        eventClients.removeAll()
        listener?.stateUpdateHandler = nil
        listener?.cancel()
        listener = nil
        publish { self.clientCount = 0 }
    }

    private func _stop(status: BridgeStatus) {
        tearDownListener()
        publish { self.status = status }
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveRequest(on: connection, buffer: Data())
    }

    /// Accumulates bytes until a full HTTP request (headers + any declared body) has arrived.
    private func receiveRequest(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buffer = buffer
            if let data { buffer.append(data) }

            if let request = HTTPRequest(raw: buffer) {
                self.route(request, on: connection)
                return
            }
            if isComplete || error != nil {
                connection.cancel()
                return
            }
            self.receiveRequest(on: connection, buffer: buffer)
        }
    }

    private func route(_ request: HTTPRequest, on connection: NWConnection) {
        switch (request.method, request.path) {
        case ("GET", "/"), ("GET", "/index.html"):
            respondHTML(BridgeWebPage.html, on: connection)

        case ("GET", "/events"):
            openEventStream(on: connection)

        case ("POST", "/scan"):
            appendLog("Computer requested a scan.")
            dispatchMain { self.onScanRequested?() }
            respondJSON(["ok": true], on: connection)

        case ("POST", "/write"):
            let text = request.jsonBody?["text"] as? String ?? ""
            if text.isEmpty {
                respondJSON(["ok": false, "error": "No text provided."], on: connection, status: "400 Bad Request")
            } else {
                appendLog("Computer requested a write: \(text.prefix(60))")
                dispatchMain { self.onWriteTextRequested?(text) }
                respondJSON(["ok": true], on: connection)
            }

        case ("GET", "/status"):
            respondJSON(["running": isRunning, "clients": eventClients.count], on: connection)

        default:
            respond(status: "404 Not Found", headers: [:], body: Data("Not found".utf8), on: connection, close: true)
        }
    }

    // MARK: - SSE clients

    private func openEventStream(on connection: NWConnection) {
        let headers = [
            "Content-Type": "text/event-stream",
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "Access-Control-Allow-Origin": "*",
        ]
        connection.send(content: responseHead(status: "200 OK", headers: headers),
                        completion: .contentProcessed { _ in })

        let id = ObjectIdentifier(connection)
        eventClients[id] = connection
        publish { self.clientCount = self.eventClients.count }
        appendLog("Computer connected (\(eventClients.count) online).")

        connection.send(content: BridgeEvent(type: "hello", payload: ["message": "connected"]).sseData,
                        completion: .contentProcessed { _ in })

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .cancelled, .failed:
                self?.queue.async { self?.dropClient(id) }
            default:
                break
            }
        }
        drain(connection, id: id)
    }

    private func drain(_ connection: NWConnection, id: ObjectIdentifier) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] _, _, isComplete, error in
            guard let self else { return }
            if isComplete || error != nil {
                self.queue.async { self.dropClient(id) }
                return
            }
            self.drain(connection, id: id)
        }
    }

    private func dropClient(_ id: ObjectIdentifier) {
        guard let connection = eventClients.removeValue(forKey: id) else { return }
        connection.cancel()
        publish { self.clientCount = self.eventClients.count }
        appendLog("Computer disconnected (\(eventClients.count) online).")
    }

    // MARK: - Responses

    private func respondHTML(_ html: String, on connection: NWConnection) {
        respond(status: "200 OK",
                headers: ["Content-Type": "text/html; charset=utf-8"],
                body: Data(html.utf8), on: connection, close: true)
    }

    private func respondJSON(_ object: [String: Any], on connection: NWConnection, status: String = "200 OK") {
        let body = (try? JSONSerialization.data(withJSONObject: object)) ?? Data("{}".utf8)
        respond(status: status,
                headers: ["Content-Type": "application/json", "Access-Control-Allow-Origin": "*"],
                body: body, on: connection, close: true)
    }

    private func respond(status: String, headers: [String: String], body: Data, on connection: NWConnection, close: Bool) {
        var head = headers
        head["Content-Length"] = String(body.count)
        if close { head["Connection"] = "close" }
        var data = responseHead(status: status, headers: head)
        data.append(body)
        connection.send(content: data, completion: .contentProcessed { _ in
            if close { connection.cancel() }
        })
    }

    private func responseHead(status: String, headers: [String: String]) -> Data {
        var lines = ["HTTP/1.1 \(status)"]
        for (key, value) in headers { lines.append("\(key): \(value)") }
        lines.append("")
        lines.append("")
        return Data(lines.joined(separator: "\r\n").utf8)
    }

    // MARK: - State plumbing

    private func publish(_ changes: @escaping () -> Void) {
        DispatchQueue.main.async(execute: changes)
    }

    private func dispatchMain(_ work: @escaping () -> Void) {
        DispatchQueue.main.async(execute: work)
    }

    private func appendLog(_ message: String) {
        publish {
            self.log.insert(BridgeLogEntry(message: message), at: 0)
            if self.log.count > 100 { self.log.removeLast(self.log.count - 100) }
        }
    }
}

/// Minimal HTTP request parser: enough to read a method, path, headers, and a Content-Length
/// body. Returns nil until the whole request has arrived in `raw`.
private struct HTTPRequest {
    let method: String
    let path: String
    let headers: [String: String]
    let body: Data

    var jsonBody: [String: Any]? {
        guard !body.isEmpty else { return nil }
        return (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
    }

    init?(raw: Data) {
        guard let headerEndRange = raw.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let headerData = raw.subdata(in: raw.startIndex..<headerEndRange.lowerBound)
        guard let headerText = String(data: headerData, encoding: .utf8) else { return nil }

        var lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else { return nil }
        method = String(parts[0])
        path = String(parts[1])

        lines.removeFirst()
        var parsedHeaders: [String: String] = [:]
        for line in lines where line.contains(":") {
            let pair = line.split(separator: ":", maxSplits: 1)
            if pair.count == 2 {
                parsedHeaders[pair[0].trimmingCharacters(in: .whitespaces).lowercased()] =
                    pair[1].trimmingCharacters(in: .whitespaces)
            }
        }
        headers = parsedHeaders

        let bodyStart = headerEndRange.upperBound
        let available = raw.subdata(in: bodyStart..<raw.endIndex)
        if let lengthString = parsedHeaders["content-length"], let expected = Int(lengthString), expected > 0 {
            guard available.count >= expected else { return nil } // wait for the rest of the body
            body = available.prefix(expected)
        } else {
            body = Data()
        }
    }
}
