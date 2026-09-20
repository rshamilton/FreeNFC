import ContactsUI
import SwiftUI

struct RecordDetailView: View {
    let record: NDEFRecordModel

    @State private var copied: String?
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            if let display = record.displayString {
                Section("Decoded Content") {
                    Text(display)
                        .font(.body)
                        .textSelection(.enabled)

                    actionButtons(for: display)

                    copyButton("Copy Decoded Text", value: display)
                }
            }

            Section("Record Header") {
                LabeledContent("Record Kind", value: record.kindLabel)
                LabeledContent("Type-Name Format (TNF)", value: record.typeNameFormatLabel)
                LabeledContent("Type Identifier", value: record.typeString.isEmpty ? "—" : record.typeString)
                if !record.type.isEmpty {
                    LabeledContent("Type (Hex)", value: record.type.hexString)
                }
                if record.identifier.isEmpty {
                    LabeledContent("Identifier", value: "None")
                } else {
                    LabeledContent("Identifier (Hex)", value: record.identifier.hexString)
                }
                LabeledContent("Payload Size", value: "\(record.payload.count) bytes")
            }

            Section("Payload (Hex)") {
                Text(record.rawHexString.isEmpty ? "Empty" : record.rawHexString)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                copyButton("Copy Payload Hex", value: record.rawHexString)
            }

            if !record.payload.isEmpty {
                Section("Payload (ASCII Preview)") {
                    Text(record.payloadASCII)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                }
            }

            Section("Full NDEF Record (Raw Bytes)") {
                Text(record.fullRecordHexString.isEmpty ? "Empty" : record.fullRecordHexString)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                copyButton("Copy Full Record Hex", value: record.fullRecordHexString)
            }
        }
        .navigationTitle(record.kindLabel)
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            if let copied {
                StatusBanner(kind: .success, message: copied)
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(for: .seconds(1.4))
                        self.copied = nil
                    }
            }
        }
        .animation(.easeInOut, value: copied)
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private func actionButtons(for display: String) -> some View {
        if let url = record.openableURL {
            Button {
                openURL(url)
            } label: {
                Label(urlButtonTitle(for: url), systemImage: urlButtonIcon(for: url))
            }

            ShareLink(item: url) {
                Label("Share Link", systemImage: "square.and.arrow.up")
            }
        } else if display.hasPrefix("BEGIN:VCARD") {
            if let vcardData = record.payload.isEmpty ? display.data(using: .utf8) : record.payload,
               let tempURL = try? FileExport.writeTempFile(data: vcardData, suggestedName: "contact.vcf") {
                ShareLink(item: tempURL) {
                    Label("Share / Add Contact Card", systemImage: "person.crop.circle.badge.plus")
                }
            }
        } else if display.hasPrefix("WIFI:") {
            Button {
                Clipboard.copy(display)
                copied = "Wi-Fi Config Copied"
            } label: {
                Label("Copy Wi-Fi Configuration", systemImage: "wifi")
            }
        }
    }

    private func urlButtonTitle(for url: URL) -> String {
        switch url.scheme?.lowercased() {
        case "tel": return "Call Phone Number"
        case "mailto": return "Compose Email"
        case "sms": return "Send Text Message"
        case "facetime", "facetime-audio": return "Start FaceTime"
        case "http", "https":
            return (url.host?.contains("maps") == true) ? "Open in Maps" : "Open in Safari"
        default: return "Open in Safari"
        }
    }

    private func urlButtonIcon(for url: URL) -> String {
        switch url.scheme?.lowercased() {
        case "tel": return "phone.fill"
        case "mailto": return "envelope.fill"
        case "sms": return "message.fill"
        case "facetime", "facetime-audio": return "video.fill"
        case "http", "https":
            return (url.host?.contains("maps") == true) ? "map.fill" : "safari"
        default: return "safari"
        }
    }

    @ViewBuilder
    private func copyButton(_ title: String, value: String) -> some View {
        Button {
            Clipboard.copy(value)
            copied = "Copied to clipboard"
        } label: {
            Label(title, systemImage: "doc.on.clipboard")
        }
    }
}
