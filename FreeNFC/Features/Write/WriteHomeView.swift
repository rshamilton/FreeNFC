import CoreNFC
import SwiftUI

struct WriteHomeView: View {
    @EnvironmentObject private var nfc: NFCSessionManager
    @EnvironmentObject private var store: WriteComposerStore
    @State private var showingClearConfirm = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var searchText = ""

    private var filteredRecordTypes: [RecordTypeOption] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return RecordTypeOption.all
        }
        return RecordTypeOption.all.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.subtitle.localizedCaseInsensitiveContains(searchText) ||
            $0.keywords.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        List {
            if !store.records.isEmpty {
                stagedRecordsSection
            }

            recordTypesSection
        }
        .searchable(text: $searchText, prompt: "Search record types (e.g. URL, Wi-Fi, vCard)")
        .navigationTitle("Write")
        .safeAreaInset(edge: .bottom) {
            writeBottomBar
        }
        .alert("Clear all staged records?", isPresented: $showingClearConfirm) {
            Button("Clear All", role: .destructive) {
                store.clear()
                FeedbackManager.shared.light()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Sections

    private var stagedRecordsSection: some View {
        Section {
            ForEach(store.records) { record in
                HStack(spacing: 12) {
                    Image(systemName: record.iconName)
                        .font(.title3)
                        .foregroundStyle(record.iconColor)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.title).font(.subheadline.weight(.semibold))
                        Text(record.subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(record.payload.payload.count) B")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                }
            }
            .onDelete(perform: store.remove)

            // Capacity indicator
            let totalBytes = store.totalBytes
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Total Staged Payload:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(totalBytes) bytes")
                        .font(.caption.weight(.semibold))
                }

                HStack(spacing: 8) {
                    chipCapacityBadge(name: "NTAG213 (144B)", fits: totalBytes <= 144)
                    chipCapacityBadge(name: "NTAG215 (504B)", fits: totalBytes <= 504)
                    chipCapacityBadge(name: "NTAG216 (888B)", fits: totalBytes <= 888)
                }
            }
            .padding(.vertical, 4)
        } header: {
            HStack {
                Text("Staged for Next Tag (\(store.records.count))")
                Spacer()
                Button("Clear", role: .destructive) {
                    showingClearConfirm = true
                }
                .font(.caption)
            }
        } footer: {
            Text("Swipe left to remove records. All staged records will be written as a multi-record NDEF message.")
        }
    }

    private var recordTypesSection: some View {
        Section(header: Text("Choose Record to Add")) {
            ForEach(filteredRecordTypes) { option in
                NavigationLink {
                    option.destinationView
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: option.icon)
                            .font(.headline)
                            .foregroundStyle(option.color)
                            .frame(width: 32, height: 32)
                            .background(option.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.title)
                                .font(.body.weight(.medium))
                            Text(option.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    @ViewBuilder
    private var writeBottomBar: some View {
        if !store.records.isEmpty {
            VStack(spacing: 8) {
                if let errorMessage {
                    StatusBanner(kind: .error, message: errorMessage)
                        .padding(.horizontal)
                }
                if let successMessage {
                    StatusBanner(kind: .success, message: successMessage)
                        .padding(.horizontal)
                }

                PrimaryActionButton(
                    title: "Write to Tag (\(store.records.count) Record\(store.records.count == 1 ? "" : "s"))",
                    systemImage: "wave.3.right.circle.fill",
                    isBusy: nfc.isScanning
                ) {
                    Task { await writeToTag() }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .background(.ultraThinMaterial)
        }
    }

    private func chipCapacityBadge(name: String, fits: Bool) -> some View {
        Text(name)
            .font(.system(size: 9, weight: .semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(fits ? Color.green.opacity(0.15) : Color.red.opacity(0.15), in: Capsule())
            .foregroundStyle(fits ? Color.green : Color.red)
    }

    private func writeToTag() async {
        errorMessage = nil
        successMessage = nil
        let message = store.buildMessage()
        let outcome = await nfc.perform(alertMessage: "Hold your iPhone near the tag to write.") { tag, session in
            let ndef = ndefTag(from: tag)
            let status = try await ndef.queryNDEFStatus()
            guard status.0 != .readOnly else { throw NFCError.tagNotWritable }
            guard status.1 >= message.length else {
                throw NFCError.payloadTooLarge(capacity: status.1, needed: message.length)
            }
            try await ndef.writeNDEF(message)
        }
        switch outcome {
        case .success:
            FeedbackManager.shared.success()
            successMessage = "Tag written successfully!"
            store.clear()
        case .failure(let error):
            if !NFCSessionManager.isUserCancellation(error) {
                FeedbackManager.shared.error()
                errorMessage = NFCSessionManager.friendlyMessage(for: error)
            }
        }
    }
}

// MARK: - Record Types Catalog

struct RecordTypeOption: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let keywords: [String]
    let destinationView: AnyView

    static let all: [RecordTypeOption] = [
        RecordTypeOption(
            title: "Web Link / URL",
            subtitle: "Opens website or universal link in browser",
            icon: "link",
            color: .blue,
            keywords: ["website", "http", "https", "link", "url"],
            destinationView: AnyView(WriteURLView())
        ),
        RecordTypeOption(
            title: "Plain Text",
            subtitle: "Free-form text message or note",
            icon: "text.alignleft",
            color: .primary,
            keywords: ["text", "note", "message"],
            destinationView: AnyView(WriteTextView())
        ),
        RecordTypeOption(
            title: "Contact Card (vCard)",
            subtitle: "Name, phone, email, organization",
            icon: "person.crop.circle.badge.plus",
            color: .orange,
            keywords: ["vcard", "contact", "person", "address book", "phonebook"],
            destinationView: AnyView(WriteContactView())
        ),
        RecordTypeOption(
            title: "Wi-Fi Network",
            subtitle: "SSID, password, and security type token",
            icon: "wifi",
            color: .teal,
            keywords: ["wifi", "network", "hotspot", "internet", "wireless"],
            destinationView: AnyView(WriteWiFiView())
        ),
        RecordTypeOption(
            title: "Social Profile",
            subtitle: "Instagram, X/Twitter, TikTok, GitHub, LinkedIn",
            icon: "at",
            color: .purple,
            keywords: ["social", "instagram", "twitter", "tiktok", "github", "linkedin", "youtube", "snapchat"],
            destinationView: AnyView(WriteSocialView())
        ),
        RecordTypeOption(
            title: "Payment Link",
            subtitle: "Venmo, PayPal, or Cash App handle",
            icon: "dollarsign.circle",
            color: .green,
            keywords: ["payment", "venmo", "paypal", "cashapp", "money", "pay"],
            destinationView: AnyView(WritePaymentView())
        ),
        RecordTypeOption(
            title: "Phone Number",
            subtitle: "One-tap direct dial tel link",
            icon: "phone.fill",
            color: .green,
            keywords: ["phone", "call", "telephone", "dial"],
            destinationView: AnyView(WritePhoneView())
        ),
        RecordTypeOption(
            title: "Email Message",
            subtitle: "Pre-filled recipient, subject, and body",
            icon: "envelope.fill",
            color: .indigo,
            keywords: ["email", "mail", "mailto"],
            destinationView: AnyView(WriteEmailView())
        ),
        RecordTypeOption(
            title: "Location / Address",
            subtitle: "Coordinates or street address in Apple Maps",
            icon: "map.fill",
            color: .red,
            keywords: ["map", "location", "gps", "navigation", "address", "coordinates"],
            destinationView: AnyView(WriteLocationView())
        ),
        RecordTypeOption(
            title: "FaceTime Call",
            subtitle: "Direct video or audio call link",
            icon: "video.fill",
            color: .green,
            keywords: ["facetime", "call", "video"],
            destinationView: AnyView(WriteFaceTimeView())
        ),
        RecordTypeOption(
            title: "WhatsApp Chat",
            subtitle: "Start chat with pre-filled message",
            icon: "message.fill",
            color: .mint,
            keywords: ["whatsapp", "chat", "message"],
            destinationView: AnyView(WriteWhatsAppView())
        ),
        RecordTypeOption(
            title: "Calendar Event",
            subtitle: "Event title, dates, and location (iCal)",
            icon: "calendar.badge.plus",
            color: .pink,
            keywords: ["calendar", "event", "meeting", "date", "ical"],
            destinationView: AnyView(WriteCalendarView())
        ),
        RecordTypeOption(
            title: "App Store Link",
            subtitle: "Open an app or custom URL scheme",
            icon: "app.badge",
            color: .cyan,
            keywords: ["app", "appstore", "application", "scheme"],
            destinationView: AnyView(WriteAppView())
        ),
        RecordTypeOption(
            title: "Bluetooth Pairing (OOB)",
            subtitle: "MAC address and pairing name",
            icon: "dot.radiowaves.left.and.right",
            color: .blue,
            keywords: ["bluetooth", "pair", "pairing", "oob", "mac"],
            destinationView: AnyView(WriteBluetoothView())
        ),
        RecordTypeOption(
            title: "Embedded Small File",
            subtitle: "Small binary or MIME file (<8 KB)",
            icon: "doc.fill",
            color: .gray,
            keywords: ["file", "binary", "data", "mime"],
            destinationView: AnyView(WriteFileView())
        ),
        RecordTypeOption(
            title: "Custom Raw NDEF Record",
            subtitle: "Custom TNF, Type, Identifier, and Payload",
            icon: "curlybraces",
            color: .secondary,
            keywords: ["custom", "raw", "expert", "developer", "payload", "hex", "tnf"],
            destinationView: AnyView(WriteCustomView())
        )
    ]
}
