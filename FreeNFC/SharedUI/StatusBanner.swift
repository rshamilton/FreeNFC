import SwiftUI

struct StatusBanner: View {
    enum Kind { case success, error, info }

    let kind: Kind
    let message: String

    private var color: Color {
        switch kind {
        case .success: return .green
        case .error: return .red
        case .info: return .blue
        }
    }

    private var icon: String {
        switch kind {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    var body: some View {
        Label(message, systemImage: icon)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
