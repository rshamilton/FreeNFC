import SwiftUI

/// Read-only hex viewer for a TagDump. Used from Read's result screen and from the Bin Dump tool.
struct MemoryDumpView: View {
    let title: String
    let dump: TagDump

    @State private var binFileURL: URL?
    @State private var copiedIndex: Int?

    var body: some View {
        List {
            Section {
                LabeledContent("Total Size", value: "\(dump.totalBytes) bytes")
                LabeledContent("Block Size", value: "\(dump.blockSize) bytes")
                if let chip = dump.chipLabel {
                    LabeledContent("Chip", value: chip)
                }
            }

            Section("Blocks") {
                ForEach(Array(dump.blocks.enumerated()), id: \.offset) { index, block in
                    HexByteRow(index: index, label: "\(index)", data: block) {
                        Clipboard.copy(block)
                        copiedIndex = index
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        Clipboard.copy(dump.flatData.hexString)
                    } label: {
                        Label("Copy All as Hex", systemImage: "doc.on.clipboard")
                    }
                    if let binFileURL {
                        ShareLink(item: binFileURL) {
                            Label("Export as .bin", systemImage: "square.and.arrow.up")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear(perform: prepareBinFile)
        .overlay(alignment: .bottom) {
            if copiedIndex != nil {
                StatusBanner(kind: .success, message: "Block copied")
                    .padding()
                    .task {
                        try? await Task.sleep(for: .seconds(1.2))
                        copiedIndex = nil
                    }
            }
        }
        .animation(.default, value: copiedIndex)
    }

    private func prepareBinFile() {
        binFileURL = try? FileExport.writeTempFile(
            data: dump.flatData,
            suggestedName: FileExport.binFileName(prefix: "dump", uid: dump.chipLabel ?? "tag")
        )
    }
}
