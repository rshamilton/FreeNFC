import SwiftData
import SwiftUI

struct ReadResultView: View {
    let tag: ScannedTag

    @Environment(\.modelContext) private var modelContext
    @State private var showingSaveAlert = false
    @State private var saveName = ""
    @State private var toast: String?

    private var issues: [TagIssue] { TagDiagnostics.issues(for: tag) }

    var body: some View {
        List {
            issuesSection
            tagSection
            chipSection
            protectionSection
            otherFamilySection
            recordsSection
            memorySection
            actionsSection
        }
        .navigationTitle("Scan Result")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: generateShareSummary()) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .alert("Save Tag to Library", isPresented: $showingSaveAlert) {
            TextField("Name", text: $saveName)
            Button("Save") { save() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Saved tags can be cloned onto blank tags later from the Duplicate tab.")
        }
        .overlay(alignment: .bottom) {
            if let toast {
                StatusBanner(kind: .success, message: toast)
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(for: .seconds(1.5))
                        self.toast = nil
                    }
            }
        }
        .animation(.easeInOut, value: toast)
    }

    // MARK: - Sections

    @ViewBuilder
    private var issuesSection: some View {
        if !issues.isEmpty {
            Section("Diagnostics & Alerts") {
                ForEach(issues) { issue in
                    VStack(alignment: .leading, spacing: 4) {
                        Label {
                            Text(issue.title).font(.subheadline.weight(.semibold))
                        } icon: {
                            Image(systemName: issue.severity.systemImage)
                                .foregroundStyle(color(for: issue.severity))
                        }
                        Text(issue.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var tagSection: some View {
        Section("Tag Information") {
            LabeledContent("Type", value: tag.family.rawValue)
            if let detail = tag.techDetail {
                LabeledContent("Chip", value: detail)
            }
            HStack {
                Text("UID")
                Spacer()
                Text(tag.uid)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.primary)
                Button {
                    Clipboard.copy(tag.uid)
                    toast = "UID copied"
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            LabeledContent("UID Length", value: "\(tag.uid.split(separator: " ").count) bytes")
            LabeledContent("NDEF Status", value: tag.ndefStatusLabel)
            if let capacity = tag.ndefCapacity {
                LabeledContent("NDEF Capacity", value: "\(capacity) bytes")
            }
            if let dump = tag.dump {
                LabeledContent("Memory Read", value: "\(dump.totalBytes) bytes (\(dump.blocks.count) × \(dump.blockSize)B)")
            }
            LabeledContent("Scanned", value: tag.dateScanned.formatted(date: .abbreviated, time: .standard))
        }
    }

    @ViewBuilder
    private var chipSection: some View {
        if let details = tag.details, details.versionBytes != nil || details.signature != nil || details.readCounter != nil {
            Section("Chip Details") {
                if let vendor = details.vendorName { LabeledContent("Vendor", value: vendor) }
                if let product = details.productTypeName { LabeledContent("Product", value: product) }
                if let version = details.productVersion { LabeledContent("Version", value: version) }
                if let storage = details.storageSizeDescription { LabeledContent("User Memory", value: storage) }
                if let proto = details.protocolDescription { LabeledContent("Protocol", value: proto) }
                if let counter = details.readCounter { LabeledContent("Read Counter", value: "\(counter)") }
                LabeledContent("Originality Signature", value: details.hasOriginalitySignature ? "Present (Authentic)" : "Not available")
                if let version = details.versionBytes {
                    hexRow("GET_VERSION", version)
                }
                if let signature = details.signature, details.hasOriginalitySignature {
                    hexRow("Signature", signature)
                }
            }
        }
    }

    @ViewBuilder
    private var protectionSection: some View {
        if let details = tag.details, details.configPage0 != nil || details.capabilityContainer != nil {
            Section("Protection & Security Configuration") {
                if let cc = details.capabilityContainerDescription {
                    LabeledContent("Capability Container", value: cc)
                }
                if let auth0 = details.auth0 {
                    LabeledContent("Password Protection (AUTH0)", value: details.isPasswordProtected ? "Protected starting at page \(auth0)" : "Not protected")
                }
                if details.isPasswordProtected, let readsToo = details.passwordProtectsReads {
                    LabeledContent("Protection Scope", value: readsToo ? "Read + Write restricted" : "Write restricted only")
                }
                if let limit = details.authenticationLimit {
                    LabeledContent("Failed Attempt Limit", value: limit == 0 ? "Unlimited" : "\(limit)")
                }
                LabeledContent("Configuration Locked", value: details.isConfigurationLocked ? "Yes (Permanent)" : "No (Modifiable)")
                LabeledContent("Static Lock Bits", value: details.hasStaticLockBits ? "Locked" : "Clear (Writable)")
                LabeledContent("Dynamic Lock Bits", value: details.hasDynamicLockBits ? "Locked" : "Clear (Writable)")
                if let lock = details.staticLockBytes { hexRow("Static Lock Bytes", lock) }
                if let lock = details.dynamicLockBytes { hexRow("Dynamic Lock Bytes", lock) }
                if let cfg = details.configPage0 { hexRow("Configuration Page 0 (CFG0)", cfg) }
                if let cfg = details.configPage1 { hexRow("Configuration Page 1 (CFG1)", cfg) }
            }
        }
    }

    @ViewBuilder
    private var otherFamilySection: some View {
        if let details = tag.details, hasOtherFamilyInfo(details) {
            Section("Technology Identifiers") {
                if let aid = details.applicationIdentifier, !aid.isEmpty {
                    LabeledContent("Selected AID", value: aid)
                }
                if let appData = details.applicationData {
                    hexRow("Application Data", appData)
                }
                if let proprietary = details.proprietaryApplicationDataCoding {
                    LabeledContent("Proprietary Coding", value: proprietary ? "Yes" : "No")
                }
                if let historical = details.historicalBytes, !historical.isEmpty {
                    hexRow("Historical Bytes", historical)
                }
                if let code = details.icManufacturerCode {
                    LabeledContent("IC Manufacturer Code", value: "\(code)")
                }
                if let serial = details.icSerialNumber, !serial.isEmpty {
                    hexRow("IC Serial", serial)
                }
                if let system = details.systemCode {
                    hexRow("System Code", system)
                }
                if let dsfid = details.dsfid { LabeledContent("DSFID", value: String(format: "0x%02X", dsfid)) }
                if let afi = details.afi { LabeledContent("AFI", value: String(format: "0x%02X", afi)) }
                if let size = details.blockSize, let count = details.blockCount {
                    LabeledContent("Blocks", value: "\(count) × \(size) bytes")
                }
                if let reference = details.icReference {
                    LabeledContent("IC Reference", value: String(format: "0x%02X", reference))
                }
            }
        }
    }

    private var recordsSection: some View {
        Section(tag.records.isEmpty ? "NDEF Records" : "NDEF Records (\(tag.records.count))") {
            if tag.records.isEmpty {
                Text(tag.ndefStatus == .notSupported ? "Tag is not NDEF formatted." : "No NDEF records stored.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(tag.records) { record in
                    NavigationLink {
                        RecordDetailView(record: record)
                    } label: {
                        recordRow(record)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var memorySection: some View {
        if let dump = tag.dump {
            Section("Memory") {
                NavigationLink {
                    MemoryDumpView(title: "Full Memory Dump", dump: dump)
                } label: {
                    Label("View Full Memory Dump (\(dump.totalBytes) B)", systemImage: "square.grid.3x3")
                }
            }
        }
    }

    private var actionsSection: some View {
        Section("Actions") {
            Button {
                Clipboard.copy(tag.allRawBytesHexString)
                toast = "All raw bytes copied"
            } label: {
                Label("Copy All Raw Bytes (Hex)", systemImage: "doc.on.clipboard")
            }

            Button {
                saveName = "Tag \(tag.uid.prefix(8))"
                showingSaveAlert = true
            } label: {
                Label("Save Tag to Library", systemImage: "square.and.arrow.down")
            }
        }
    }

    // MARK: - Subviews & Helpers

    @ViewBuilder
    private func recordRow(_ record: NDEFRecordModel) -> some View {
        HStack(spacing: 12) {
            Image(systemName: record.iconName)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.kindLabel)
                    .font(.subheadline.weight(.semibold))
                if let display = record.displayString {
                    Text(display)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Text("\(record.payload.count) bytes payload")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func hexRow(_ label: String, _ data: Data) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Text(data.hexString)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                Spacer()
                Button {
                    Clipboard.copy(data.hexString)
                    toast = "\(label) copied"
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func hasOtherFamilyInfo(_ details: TagDetails) -> Bool {
        details.applicationIdentifier != nil || details.applicationData != nil
            || details.icManufacturerCode != nil || details.systemCode != nil
            || details.dsfid != nil || (details.historicalBytes?.isEmpty == false)
    }

    private func color(for severity: TagIssue.Severity) -> Color {
        switch severity {
        case .blocking: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }

    private func save() {
        let saved = SavedTag(name: saveName.isEmpty ? "Untitled Tag" : saveName, scannedTag: tag)
        modelContext.insert(saved)
        FeedbackManager.shared.success()
        toast = "Tag saved to library"
    }

    private func generateShareSummary() -> String {
        var text = "NFC Forge Scan Report\n"
        text += "------------------------\n"
        text += "Tag Type: \(tag.family.rawValue)\n"
        if let chip = tag.techDetail { text += "Chip: \(chip)\n" }
        text += "UID: \(tag.uid)\n"
        text += "NDEF Status: \(tag.ndefStatusLabel)\n"
        if let capacity = tag.ndefCapacity { text += "Capacity: \(capacity) bytes\n" }
        text += "Date Scanned: \(tag.dateScanned.formatted())\n\n"

        if !tag.records.isEmpty {
            text += "NDEF Records (\(tag.records.count)):\n"
            for (idx, r) in tag.records.enumerated() {
                text += "[\(idx + 1)] \(r.kindLabel) (\(r.payload.count) B): \(r.displayString ?? r.rawHexString)\n"
            }
            text += "\n"
        }

        if let dump = tag.dump {
            text += "Raw Memory (\(dump.totalBytes) bytes):\n"
            text += dump.flatData.hexString
            text += "\n"
        }

        return text
    }
}
