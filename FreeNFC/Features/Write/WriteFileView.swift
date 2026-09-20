import CoreNFC
import SwiftUI
import UniformTypeIdentifiers

struct WriteFileView: View {
    @State private var fileURL: URL?
    @State private var fileData: Data?
    @State private var mimeType = "application/octet-stream"
    @State private var showingImporter = false
    @State private var pickError: String?

    var body: some View {
        Form {
            Section {
                Button {
                    showingImporter = true
                } label: {
                    Label(fileURL?.lastPathComponent ?? "Choose File", systemImage: "doc")
                }
                if let fileData {
                    LabeledContent("Size", value: "\(fileData.count) bytes")
                    LabeledContent("Type", value: mimeType)
                }
                if let pickError {
                    StatusBanner(kind: .error, message: pickError)
                }
            } footer: {
                Text("Tags are tiny (typically 144\u{2013}888 bytes), so only very small files will fit \u{2014} a short text file or vCard, not photos or documents.")
            }

            Section {
                AddRecordButton(title: "File", icon: "doc", color: .indigo, subtitle: fileURL?.lastPathComponent ?? "Empty", buildPayload: buildPayload)
            }
        }
        .navigationTitle("Write File")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.item]) { result in
            handlePick(result)
        }
    }

    private func handlePick(_ result: Result<URL, Error>) {
        pickError = nil
        switch result {
        case .failure(let error):
            pickError = error.localizedDescription
        case .success(let url):
            do {
                let data = try FileExport.readFile(at: url)
                fileURL = url
                fileData = data
                mimeType = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
            } catch {
                pickError = (error as? LocalizedError)?.errorDescription ?? "Couldn't read that file."
            }
        }
    }

    private func buildPayload() throws -> NFCNDEFPayload {
        guard let fileData else { throw NFCError.custom("Choose a file first.") }
        guard fileData.count <= 8192 else {
            throw NFCError.payloadTooLarge(capacity: 8192, needed: fileData.count)
        }
        return NDEFWriter.mime(type: mimeType, data: fileData)
    }
}
