import CoreNFC
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Query(sort: \SavedTag.dateSaved, order: .reverse) private var savedTags: [SavedTag]
    @Query(sort: \CommandHistoryEntry.date, order: .reverse) private var commandHistory: [CommandHistoryEntry]

    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true
    @AppStorage("soundEnabled") private var soundEnabled: Bool = true
    @AppStorage("autoSaveScans") private var autoSaveScans: Bool = false

    @State private var showingClearSavedConfirm = false
    @State private var showingClearHistoryConfirm = false
    @State private var exportedTagsURL: URL?
    @State private var exportedHistoryURL: URL?
    @State private var toastMessage: String?

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (Build \(build))"
    }

    var body: some View {
        List {
            deviceSection
            preferencesSection
            dataManagementSection
            guidesSection
            aboutSection
        }
        .navigationTitle("Settings")
        .alert("Clear all saved tags?", isPresented: $showingClearSavedConfirm) {
            Button("Clear All", role: .destructive) {
                savedTags.forEach(modelContext.delete)
                FeedbackManager.shared.medium()
                toastMessage = "Saved tags cleared"
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove all \(savedTags.count) saved tags from your local library.")
        }
        .alert("Clear command history?", isPresented: $showingClearHistoryConfirm) {
            Button("Clear All", role: .destructive) {
                commandHistory.forEach(modelContext.delete)
                FeedbackManager.shared.medium()
                toastMessage = "Command history cleared"
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete all \(commandHistory.count) logged manual transceive entries.")
        }
        .overlay(alignment: .bottom) {
            if let toastMessage {
                StatusBanner(kind: .success, message: toastMessage)
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(for: .seconds(1.5))
                        self.toastMessage = nil
                    }
            }
        }
        .animation(.easeInOut, value: toastMessage)
        .onAppear {
            prepareExports()
        }
    }

    // MARK: - Sections

    private var deviceSection: some View {
        Section("Hardware & Scanning") {
            HStack {
                Label("NFC Reader Status", systemImage: "wave.3.right.circle.fill")
                    .foregroundStyle(.blue)
                Spacer()
                Text(NFCReaderSession.readingAvailable ? "Ready" : "Unavailable")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NFCReaderSession.readingAvailable ? .green : .red)
            }
        }
    }

    private var preferencesSection: some View {
        Section("Preferences") {
            Toggle(isOn: $hapticsEnabled) {
                Label("Haptic Feedback", systemImage: "hand.tap.fill")
            }
            .onChange(of: hapticsEnabled) { _, newValue in
                if newValue { FeedbackManager.shared.light() }
            }

            Toggle(isOn: $soundEnabled) {
                Label("Audio Signals", systemImage: "speaker.wave.2.fill")
            }

            Toggle(isOn: $autoSaveScans) {
                Label("Auto-Save Scanned Tags", systemImage: "arrow.down.doc.fill")
            }
        }
    }

    private var dataManagementSection: some View {
        Section("Data & Storage") {
            HStack {
                Text("Saved Tags")
                Spacer()
                Text("\(savedTags.count)")
                    .foregroundStyle(.secondary)
            }

            if !savedTags.isEmpty, let exportedTagsURL {
                ShareLink(item: exportedTagsURL) {
                    Label("Export Saved Tags (JSON)", systemImage: "square.and.arrow.up")
                }
            }

            Button(role: .destructive) {
                showingClearSavedConfirm = true
            } label: {
                Label("Clear Saved Tags", systemImage: "trash")
            }
            .disabled(savedTags.isEmpty)

            HStack {
                Text("Logged Manual Commands")
                Spacer()
                Text("\(commandHistory.count)")
                    .foregroundStyle(.secondary)
            }

            if !commandHistory.isEmpty, let exportedHistoryURL {
                ShareLink(item: exportedHistoryURL) {
                    Label("Export History (CSV)", systemImage: "square.and.arrow.up")
                }
            }

            Button(role: .destructive) {
                showingClearHistoryConfirm = true
            } label: {
                Label("Clear Command History", systemImage: "clock.arrow.circlepath")
            }
            .disabled(commandHistory.isEmpty)
        }
    }

    private var guidesSection: some View {
        Section("Help & Documentation") {
            NavigationLink {
                SupportedTagsDetailView()
            } label: {
                Label("Tag Compatibility & Tech Matrix", systemImage: "cpu")
            }

            NavigationLink {
                SupportHelpView()
            } label: {
                Label("Support & Troubleshooting", systemImage: "questionmark.circle")
            }

            NavigationLink {
                PrivacyPolicyView()
            } label: {
                Label("Privacy Policy", systemImage: "hand.raised.shield")
            }
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text("App Version")
                Spacer()
                Text(appVersion)
                    .foregroundStyle(.secondary)
            }

            Button {
                if let url = URL(string: "https://rshamilton.github.io/FreeNFC/") {
                    openURL(url)
                }
            } label: {
                Label("NFC Forge Website", systemImage: "globe")
            }

            Button {
                if let url = URL(string: "https://github.com/rshamilton/FreeNFC") {
                    openURL(url)
                }
            } label: {
                Label("GitHub Repository", systemImage: "chevron.left.forwardslash.chevron.right")
            }
        } header: {
            Text("About")
        } footer: {
            VStack(alignment: .center, spacing: 4) {
                Text("NFC Forge · Open-Source")
                Text("Zero Ads · Zero Trackers · No Cloud Required")
                Text("© 2026 Ryan Hamilton · MIT License")
            }
            .font(.caption2)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 8)
        }
    }

    private func prepareExports() {
        // Prepare tags JSON export
        if !savedTags.isEmpty {
            let tagModels = savedTags.compactMap { $0.scannedTag }
            if let data = try? JSONEncoder().encode(tagModels) {
                exportedTagsURL = try? FileExport.writeTempFile(data: data, suggestedName: "NFCForge_SavedTags_\(Date().formatted(date: .numeric, time: .omitted)).json")
            }
        } else {
            exportedTagsURL = nil
        }

        // Prepare command history CSV export
        if !commandHistory.isEmpty {
            var csv = "Date,Technology,Command (Hex),Response (Hex),Succeeded\n"
            for entry in commandHistory {
                let dateStr = entry.date.ISO8601Format()
                let cleanCmd = entry.commandHex.replacingOccurrences(of: ",", with: " ")
                let cleanResp = entry.responseHex.replacingOccurrences(of: ",", with: " ")
                csv += "\(dateStr),\"\(entry.techLabel)\",\"\(cleanCmd)\",\"\(cleanResp)\",\(entry.succeeded)\n"
            }
            if let data = csv.data(using: .utf8) {
                exportedHistoryURL = try? FileExport.writeTempFile(data: data, suggestedName: "NFCForge_Commands_\(Date().formatted(date: .numeric, time: .omitted)).csv")
            }
        } else {
            exportedHistoryURL = nil
        }
    }
}
