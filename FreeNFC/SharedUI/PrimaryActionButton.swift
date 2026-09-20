import SwiftUI

/// The one prominent "do the thing" button used across every screen, so every primary action
/// looks and behaves identically. The label is explicitly centered with flexible spacers —
/// a bare `Label` inside `.frame(maxWidth: .infinity)` picks up Form/List's leading label
/// column and drifts off-center, which is why this exists.
struct PrimaryActionButton: View {
    let title: String
    var systemImage: String = "wave.3.right"
    /// Shown (with a scanning glyph) while an NFC session is in flight.
    var isBusy: Bool = false
    var busyTitle: String = "Scanning\u{2026}"
    var isDestructive: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                Image(systemName: isBusy ? "dot.radiowaves.left.and.right" : systemImage)
                    .symbolEffect(.variableColor, isActive: isBusy)
                Text(isBusy ? busyTitle : title)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(isDestructive ? .red : .accentColor)
        .disabled(isBusy || !isEnabled)
    }
}

/// Same button sized for a Form/List section row: clears the default row insets so the button
/// spans the full width of the card instead of sitting inside the label gutter.
struct PrimaryActionRow: View {
    let title: String
    var systemImage: String = "wave.3.right"
    var isBusy: Bool = false
    var busyTitle: String = "Scanning\u{2026}"
    var isDestructive: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        PrimaryActionButton(
            title: title,
            systemImage: systemImage,
            isBusy: isBusy,
            busyTitle: busyTitle,
            isDestructive: isDestructive,
            isEnabled: isEnabled,
            action: action
        )
        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
        .listRowBackground(Color.clear)
    }
}
