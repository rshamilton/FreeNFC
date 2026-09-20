import CoreNFC
import SwiftData
import SwiftUI

struct ManualCommandView: View {
    enum Tech: String, CaseIterable { case mifare = "MIFARE", iso15693 = "ISO 15693", iso7816 = "ISO 7816", felica = "FeliCa" }

    @EnvironmentObject private var nfc: NFCSessionManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CommandHistoryEntry.date, order: .reverse) private var history: [CommandHistoryEntry]

    @State private var tech: Tech = .mifare
    @State private var commandHex = "60"
    @State private var iso15693Code = "2B"
    @State private var iso15693Params = ""
    @State private var responseHex: String?
    @State private var statusWord: String?
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Picker("Tag Type", selection: $tech) {
                    ForEach(Tech.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
            }

            Section("Command") {
                inputFields
                presetMenu
            }

            if let errorMessage {
                Section { StatusBanner(kind: .error, message: errorMessage) }
                    .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
            }

            if let responseHex {
                Section("Response") {
                    if let statusWord {
                        LabeledContent("Status Word", value: statusWord)
                    }
                    Text(responseHex)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                    Button {
                        Clipboard.copy(responseHex)
                    } label: {
                        Label("Copy Response", systemImage: "doc.on.clipboard")
                    }
                }
            }

            Section {
                PrimaryActionRow(title: "Hold Near Tag & Send", isBusy: nfc.isScanning) {
                    Task { await send() }
                }
            }

            if !history.isEmpty {
                Section("Recent Commands") {
                    ForEach(history.prefix(20)) { entry in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(entry.techLabel).font(.caption.weight(.semibold))
                                Spacer()
                                Image(systemName: entry.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(entry.succeeded ? .green : .red)
                                    .font(.caption)
                            }
                            Text(entry.commandHex).font(.system(.caption2, design: .monospaced))
                            Text(entry.responseHex).font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Manual Commands")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var inputFields: some View {
        switch tech {
        case .mifare, .iso7816, .felica:
            TextField("Command bytes (hex)", text: $commandHex)
                .font(.system(.body, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        case .iso15693:
            TextField("Command code (hex, 1 byte)", text: $iso15693Code)
                .font(.system(.body, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("Parameters (hex, optional)", text: $iso15693Params)
                .font(.system(.body, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }

    private var presets: [(name: String, a: String, b: String)] {
        switch tech {
        case .mifare: return [("GET_VERSION", "60", ""), ("READ page 0", "30 00", ""), ("HALT", "50 00", "")]
        case .iso15693: return [("Get System Info", "2B", ""), ("Read Block 0", "20", "00")]
        case .iso7816: return [("SELECT (no AID)", "00 A4 04 00 00", "")]
        case .felica: return [("Polling", "00 FF FF 01 00", "")]
        }
    }

    @ViewBuilder
    private var presetMenu: some View {
        Menu {
            ForEach(presets, id: \.name) { preset in
                Button(preset.name) {
                    if tech == .iso15693 {
                        iso15693Code = preset.a
                        iso15693Params = preset.b
                    } else {
                        commandHex = preset.a
                    }
                }
            }
        } label: {
            Label("Presets", systemImage: "list.bullet")
        }
    }

    private func send() async {
        errorMessage = nil
        responseHex = nil
        statusWord = nil

        let commandForHistory: String
        switch tech {
        case .iso15693: commandForHistory = "\(iso15693Code) \(iso15693Params)".trimmingCharacters(in: .whitespaces)
        default: commandForHistory = commandHex
        }

        var response: Data?
        var sw: (UInt8, UInt8)?

        let outcome = await nfc.perform(alertMessage: "Hold your iPhone near the tag.") { tag, session in
            switch (self.tech, tag) {
            case (.mifare, .miFare(let t)):
                guard let bytes = HexUtils.data(fromHex: self.commandHex) else { throw NFCError.custom("Invalid hex.") }
                response = try await t.sendMiFareCommand(commandPacket: bytes)
            case (.iso15693, .iso15693(let t)):
                guard let codeByte = UInt8(self.iso15693Code.filter { !$0.isWhitespace }, radix: 16) else {
                    throw NFCError.custom("Command code must be one hex byte.")
                }
                let params = HexUtils.data(fromHex: self.iso15693Params) ?? Data()
                response = try await t.iso15693Custom(code: codeByte, parameters: params)
            case (.iso7816, .iso7816(let t)):
                guard let bytes = HexUtils.data(fromHex: self.commandHex) else { throw NFCError.custom("Invalid hex.") }
                let result = try await t.sendRawAPDU(bytes)
                response = result.data
                sw = (result.sw1, result.sw2)
            case (.felica, .feliCa(let t)):
                guard let bytes = HexUtils.data(fromHex: self.commandHex) else { throw NFCError.custom("Invalid hex.") }
                response = try await t.sendRawFeliCa(bytes)
            default:
                throw NFCError.custom("That's a \(TagFamilyResolver.family(for: tag).rawValue) tag, not \(self.tech.rawValue). Switch the picker or scan a different tag.")
            }
        }

        let succeeded: Bool
        var responseString = ""
        switch outcome {
        case .success:
            succeeded = true
            responseString = response?.hexString ?? ""
            responseHex = responseString
            if let sw {
                let word = String(format: "%02X%02X", sw.0, sw.1)
                statusWord = word
                responseString += " (SW \(word))"
            }
        case .failure(let error):
            succeeded = false
            if !NFCSessionManager.isUserCancellation(error) {
                errorMessage = NFCSessionManager.friendlyMessage(for: error)
                responseString = errorMessage ?? "Failed"
            } else {
                return
            }
        }

        let entry = CommandHistoryEntry(techLabel: tech.rawValue, commandHex: commandForHistory, responseHex: responseString, succeeded: succeeded)
        modelContext.insert(entry)
    }
}
