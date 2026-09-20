import SwiftUI

/// The full-screen "ready to scan" call to action used by Read, Write, Duplicate, and every
/// Tools screen. iOS draws its own system sheet once a scan actually starts; this view is
/// what people see in-app before and between scans.
struct NFCScanPrompt: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let isScanning: Bool
    let actionTitle: String
    let action: () -> Void
    var isDestructive: Bool = false

    @State private var pulse = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(.tint.opacity(0.12))
                    .frame(width: 160, height: 160)
                    .scaleEffect(pulse ? 1.08 : 0.94)
                    .opacity(isScanning ? 1 : 0.6)
                    .animation(isScanning ? .easeInOut(duration: 1.1).repeatForever(autoreverses: true) : .default, value: pulse)

                Image(systemName: systemImage)
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(isDestructive ? Color.red : Color.accentColor)
            }
            .onAppear { pulse = true }

            VStack(spacing: 8) {
                Text(title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            PrimaryActionButton(
                title: actionTitle,
                isBusy: isScanning,
                isDestructive: isDestructive,
                action: action
            )
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }
}
