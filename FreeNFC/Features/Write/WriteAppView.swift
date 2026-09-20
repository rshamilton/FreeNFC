import CoreNFC
import SwiftUI

/// iOS has no equivalent of Android's NFC "app record" that force-launches an app, so this
/// offers the three link types that actually work: a custom URL scheme, a Universal Link, or
/// an App Store page (which opens the app if installed, or its store listing if not).
struct WriteAppView: View {
    enum Mode: String, CaseIterable {
        case scheme = "URL Scheme"
        case universal = "Universal Link"
        case appStore = "App Store"
    }

    @State private var mode: Mode = .universal
    @State private var text = ""

    var body: some View {
        Form {
            Section {
                Picker("Type", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
            }

            Section {
                TextField(placeholder, text: $text)
                    .keyboardType(mode == .scheme ? .default : .URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } footer: {
                Text(footer)
            }

            Section {
                AddRecordButton(title: "Application", icon: "app.badge", color: .purple, subtitle: text.isEmpty ? "Empty" : text, buildPayload: buildPayload)
            }
        }
        .navigationTitle("Write Application")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var placeholder: String {
        switch mode {
        case .scheme: return "myapp://open"
        case .universal: return "example.com/deep/link"
        case .appStore: return "App Store ID or link"
        }
    }

    private var footer: String {
        switch mode {
        case .scheme: return "Opens the app directly if it's installed and registers this scheme. Nothing happens if it isn't installed."
        case .universal: return "A normal https:// link. Opens in the app if it supports this domain as an associated Universal Link, otherwise opens in Safari."
        case .appStore: return "Paste the numeric App Store ID (e.g. 1459969523) or a full apps.apple.com link."
        }
    }

    private func buildPayload() throws -> NFCNDEFPayload {
        let url: URL
        switch mode {
        case .scheme:
            url = try InputValidators.normalizeAppLink(text)
        case .universal:
            url = try InputValidators.normalizeWebURL(text)
        case .appStore:
            url = try appStoreURL()
        }
        guard let payload = NDEFWriter.uri(url.absoluteString) else {
            throw NFCError.custom("Couldn't build that link record.")
        }
        return payload
    }

    private func appStoreURL() throws -> URL {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ValidationError.empty("App Store ID or link") }

        if trimmed.contains("apps.apple.com") {
            return try InputValidators.normalizeWebURL(trimmed)
        }

        let digits = trimmed.filter(\.isNumber)
        guard !digits.isEmpty, let url = URL(string: "https://apps.apple.com/app/id\(digits)") else {
            throw ValidationError.invalidURL
        }
        return url
    }
}
