import CoreNFC
import SwiftUI
import UniformTypeIdentifiers

struct BinDumpView: View {
    @EnvironmentObject private var nfc: NFCSessionManager

    @State private var dump: TagDump?
    @State private var binFileURL: URL?
    @State private var dumpError: String?

    @State private var importedURL: URL?
    @State private var importedData: Data?
    @State private var blockSize = "4"
    @State private var startBlock = "0"
    @State private var allowProtected = false
    @State private var showingImporter = false
    @State private var restoreError: String?
    @State private var restoreSuccess: String?
    @State private var showRestoreConfirm = false

    var body: some View {
        Form {
            Section {
                Button {
                    Task { await readAndDump() }
                } label: {
                    Label(nfc.isScanning ? "Scanning\u{2026}" : "Read Tag & Create .bin", systemImage: "arrow.down.doc")
                }
                .disabled(nfc.isScanning)

                if let dump {
                    LabeledContent("Size", value: "\(dump.totalBytes) bytes")
                    if let binFileURL {
                        ShareLink(item: binFileURL) {
                            Label("Export \(binFileURL.lastPathComponent)", systemImage: "square.and.arrow.up")
                        }
                    }
                }
                if let dumpError {
                    StatusBanner(kind: .error, message: dumpError)
                }
            } header: {
                Text("Full Dump")
            } footer: {
                Text("Reads every page/block this app can reach and saves it as a raw .bin file.")
            }

            Section {
                Button {
                    showingImporter = true
                } label: {
                    Label(importedURL?.lastPathComponent ?? "Choose .bin File", systemImage: "arrow.up.doc")
                }
                if importedData != nil {
                    HStack {
                        Text("Block Size")
                        Spacer()
                        TextField("4", text: $blockSize).keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 60)
                    }
                    HStack {
                        Text("Start Block")
                        Spacer()
                        TextField("4", text: $startBlock).keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 60)
                    }
                    Toggle(isOn: $allowProtected) {
                        Label("Allow writing protected pages", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(allowProtected ? .red : .primary)
                    }
                    PrimaryActionRow(title: "Write .bin to Tag", isBusy: nfc.isScanning) {
                        showRestoreConfirm = true
                    }
                }
                if let restoreError {
                    StatusBanner(kind: .error, message: restoreError)
                }
                if let restoreSuccess {
                    StatusBanner(kind: .success, message: restoreSuccess)
                }
            } header: {
                Text("Restore from .bin")
            } footer: {
                Text("A .bin exported by this app is a full dump, so restore it starting at block 0 \u{2014} the UID, lock, capability and password pages are skipped automatically. \u{201C}Allow writing protected pages\u{201D} lifts that guard; it can permanently brick a tag, so leave it off unless you truly need it.")
            }
        }
        .navigationTitle("Full .bin Dump")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.data, .item]) { result in
            handleImport(result)
        }
        .confirmationDialog("Write .bin to Tag", isPresented: $showRestoreConfirm, titleVisibility: .visible) {
            Button("Hold Near Tag to Write", role: .destructive) { Task { await restore() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This overwrites the target tag's memory starting at block \(startBlock).")
        }
    }

    private func readAndDump() async {
        dumpError = nil
        binFileURL = nil
        let outcome = await nfc.perform(alertMessage: "Hold your iPhone near the tag to read its full memory.") { tag, session in
            let family = TagFamilyResolver.family(for: tag)
            guard family.supportsRawMemoryAccess else { throw NFCError.classicNotSupported }
            self.dump = try await TagMemoryAccess.dump(tag: tag)
        }
        switch outcome {
        case .success:
            if let dump {
                binFileURL = try? FileExport.writeTempFile(
                    data: dump.flatData,
                    suggestedName: FileExport.binFileName(prefix: "dump", uid: dump.chipLabel ?? "tag")
                )
            }
        case .failure(let error):
            if !NFCSessionManager.isUserCancellation(error) {
                dumpError = NFCSessionManager.friendlyMessage(for: error)
            }
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        restoreError = nil
        switch result {
        case .failure(let error):
            restoreError = error.localizedDescription
        case .success(let url):
            do {
                importedData = try FileExport.readFile(at: url)
                importedURL = url
            } catch {
                restoreError = (error as? LocalizedError)?.errorDescription ?? "Couldn't read that file."
            }
        }
    }

    private func restore() async {
        restoreError = nil
        restoreSuccess = nil
        guard let importedData, let size = Int(blockSize), size > 0, let start = Int(startBlock), start >= 0 else {
            restoreError = "Enter a valid block size and start block."
            return
        }
        var blocks: [Data] = []
        var offset = 0
        while offset < importedData.count {
            let end = min(offset + size, importedData.count)
            var chunk = importedData.subdata(in: offset..<end)
            if chunk.count < size { chunk.append(Data(repeating: 0, count: size - chunk.count)) }
            blocks.append(chunk)
            offset += size
        }

        let allow = allowProtected
        var writtenCount = 0
        let outcome = await nfc.perform(alertMessage: "Hold your iPhone near the tag to write the file.") { tag, session in
            writtenCount = try await TagMemoryAccess.writeBlocks(tag: tag, startIndex: start, blocks: blocks, allowProtectedPages: allow)
        }
        switch outcome {
        case .success:
            let skipped = blocks.count - writtenCount
            restoreSuccess = skipped > 0
                ? "Wrote \(writtenCount) user blocks (skipped \(skipped) protected page\(skipped == 1 ? "" : "s"))."
                : "Wrote \(writtenCount) blocks to the tag."
        case .failure(let error):
            if !NFCSessionManager.isUserCancellation(error) {
                restoreError = NFCSessionManager.friendlyMessage(for: error)
            }
        }
    }
}
