import Foundation

enum FileExportError: LocalizedError {
    case writeFailed
    case readFailed

    var errorDescription: String? {
        switch self {
        case .writeFailed: return "Couldn't create the export file."
        case .readFailed: return "Couldn't read that file."
        }
    }
}

/// .bin dump export/import helpers backing the Bin Dump tool and raw-bytes sharing elsewhere.
enum FileExport {
    static func writeTempFile(data: Data, suggestedName: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(suggestedName)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            throw FileExportError.writeFailed
        }
    }

    static func readFile(at url: URL) throws -> Data {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        do {
            return try Data(contentsOf: url)
        } catch {
            throw FileExportError.readFailed
        }
    }

    static func binFileName(prefix: String, uid: String) -> String {
        let safeUID = uid.replacingOccurrences(of: " ", with: "")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "\(prefix)-\(safeUID)-\(formatter.string(from: Date())).bin"
    }
}
