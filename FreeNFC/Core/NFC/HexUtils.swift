import Foundation

enum HexUtils {
    static func hexString(_ data: Data, spaced: Bool = true) -> String {
        let bytes = data.map { String(format: "%02X", $0) }
        return spaced ? bytes.joined(separator: " ") : bytes.joined()
    }

    static func data(fromHex hex: String) -> Data? {
        let cleaned = hex.filter { !$0.isWhitespace }
        guard cleaned.count % 2 == 0, !cleaned.isEmpty else { return nil }
        var data = Data(capacity: cleaned.count / 2)
        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let next = cleaned.index(index, offsetBy: 2)
            guard let byte = UInt8(cleaned[index..<next], radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        return data
    }

    static func asciiPreview(_ data: Data) -> String {
        String(data.map { (0x20...0x7E).contains($0) ? Character(UnicodeScalar($0)) : "." })
    }
}

extension Data {
    var hexString: String { HexUtils.hexString(self) }
}
