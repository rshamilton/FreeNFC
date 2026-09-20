import CoreNFC
import SwiftUI

struct MemoryEditorView: View {
    @EnvironmentObject private var nfc: NFCSessionManager
    @State private var dump: TagDump?
    @State private var editedBlocks: [Int: Data] = [:]
    @State private var editingIndex: Int?
    @State private var allowProtected = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    /// Layout of the scanned chip (when recognized), used to flag the lock/config/password
    /// pages so tapping them warns instead of silently bricking the tag.
    private var layout: NTAGLayout? {
        guard dump?.family == .ultralightOrNTAG else { return nil }
        return NTAGLayout.named(dump?.chipLabel)
    }

    private func isProtected(_ index: Int) -> Bool {
        layout?.isProtectedPage(index) ?? (index <= NTAGLayout.ccPage)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let dump {
                editorList(dump)
            } else {
                NFCScanPrompt(
                    title: "Memory Editor",
                    subtitle: "Read a tag's raw pages, edit any of them, then write your changes back.",
                    systemImage: "square.grid.3x3.square",
                    isScanning: nfc.isScanning,
                    actionTitle: "Read Tag",
                    action: { Task { await readTag() } }
                )
            }

            footerControls
        }
        .navigationTitle("Memory Editor")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if dump != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button("Re-read") { Task { await readTag() } }
                }
            }
        }
        .sheet(item: Binding(get: {
            editingIndex.map { EditingBlock(index: $0) }
        }, set: { editingIndex = $0?.index })) { editing in
            if let dump {
                BlockEditSheet(
                    index: editing.index,
                    blockSize: dump.blockSize,
                    initialData: editedBlocks[editing.index] ?? dump.blocks[editing.index]
                ) { newData in
                    editedBlocks[editing.index] = newData
                }
            }
        }
    }

    private struct EditingBlock: Identifiable { let index: Int; var id: Int { index } }

    @ViewBuilder
    private func editorList(_ dump: TagDump) -> some View {
        List {
            Section {
                LabeledContent("Total Size", value: "\(dump.totalBytes) bytes")
                LabeledContent("Block Size", value: "\(dump.blockSize) bytes")
            }
            if dump.family == .ultralightOrNTAG {
                Section {
                    Toggle(isOn: $allowProtected) {
                        Label("Allow editing protected pages", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(allowProtected ? .red : .primary)
                    }
                } footer: {
                    Text("Lock, configuration and password pages are read-only by default because writing them can permanently brick the tag.")
                }
            }
            Section("Tap a block to edit it") {
                ForEach(Array(dump.blocks.enumerated()), id: \.offset) { index, block in
                    blockRow(index: index, block: block)
                }
            }
        }
    }

    @ViewBuilder
    private func blockRow(index: Int, block: Data) -> some View {
        let current = editedBlocks[index] ?? block
        let locked = isProtected(index) && !allowProtected
        Button {
            editingIndex = index
        } label: {
            HStack {
                HexByteRow(index: index, label: "\(index)", data: current, onTap: nil)
                if isProtected(index) {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(locked ? Color.secondary : Color.red)
                }
                if editedBlocks[index] != nil {
                    Image(systemName: "pencil.circle.fill").foregroundStyle(.orange)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(locked)
    }

    @ViewBuilder
    private var footerControls: some View {
        VStack(spacing: 10) {
            if let errorMessage { StatusBanner(kind: .error, message: errorMessage).padding(.horizontal) }
            if let successMessage { StatusBanner(kind: .success, message: successMessage).padding(.horizontal) }
            if dump != nil, !editedBlocks.isEmpty {
                PrimaryActionButton(
                    title: "Write \(editedBlocks.count) Changed Block\(editedBlocks.count == 1 ? "" : "s")",
                    isBusy: nfc.isScanning
                ) {
                    Task { await writeChanges() }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
    }

    private func readTag() async {
        errorMessage = nil
        successMessage = nil
        editedBlocks = [:]
        let outcome = await nfc.perform(alertMessage: "Hold your iPhone near the tag to read its memory.") { tag, session in
            let family = TagFamilyResolver.family(for: tag)
            guard family.supportsRawMemoryAccess else { throw NFCError.classicNotSupported }
            self.dump = try await TagMemoryAccess.dump(tag: tag)
        }
        if case .failure(let error) = outcome, !NFCSessionManager.isUserCancellation(error) {
            errorMessage = NFCSessionManager.friendlyMessage(for: error)
        }
    }

    private func writeChanges() async {
        errorMessage = nil
        successMessage = nil
        guard let dump else { return }
        let changes = editedBlocks
        let allow = allowProtected
        let outcome = await nfc.perform(alertMessage: "Hold your iPhone near the same tag to write your changes.") { tag, session in
            guard TagFamilyResolver.family(for: tag) == dump.family else {
                throw NFCError.custom("This isn't the same type of tag you read from.")
            }
            try await TagMemoryAccess.writeBlocks(tag: tag, blocks: changes, allowProtectedPages: allow)
        }
        switch outcome {
        case .success:
            for (index, data) in changes {
                if var updatedBlocks = self.dump?.blocks, index < updatedBlocks.count {
                    updatedBlocks[index] = data
                    self.dump = TagDump(family: dump.family, blockSize: dump.blockSize, blocks: updatedBlocks, chipLabel: dump.chipLabel)
                }
            }
            editedBlocks = [:]
            successMessage = "Changes written."
        case .failure(let error):
            if !NFCSessionManager.isUserCancellation(error) {
                errorMessage = NFCSessionManager.friendlyMessage(for: error)
            }
        }
    }
}

private struct BlockEditSheet: View {
    let index: Int
    let blockSize: Int
    let initialData: Data
    let onSave: (Data) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var hex: String = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Block \(index) \u{2014} \(blockSize) bytes") {
                    TextField("Hex bytes", text: $hex)
                        .font(.system(.body, design: .monospaced))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                if let error {
                    StatusBanner(kind: .error, message: error)
                }
            }
            .navigationTitle("Edit Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .onAppear { hex = HexUtils.hexString(initialData) }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        guard let data = HexUtils.data(fromHex: hex), data.count == blockSize else {
            error = "Enter exactly \(blockSize) bytes as hex (e.g. \(String(repeating: "00 ", count: blockSize).trimmingCharacters(in: .whitespaces)))."
            return
        }
        onSave(data)
        dismiss()
    }
}
