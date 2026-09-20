import SwiftUI

/// One row of a raw memory dump: index, hex bytes, ASCII preview. Used by the memory dump
/// viewer, the memory editor, and the bin dump screen.
struct HexByteRow: View {
    let index: Int
    let label: String
    let data: Data
    var onTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)

            Text(HexUtils.hexString(data))
                .font(.system(.footnote, design: .monospaced))
                .lineLimit(1)

            Spacer()

            Text(HexUtils.asciiPreview(data))
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }
}
