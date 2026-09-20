import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "hand.raised.shield.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Privacy First")
                                .font(.headline)
                            Text("100% On-Device · Zero Data Collection")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    Text("Free NFC was built with an uncompromising commitment to privacy. We do not track you, we do not log your activity, and we never collect or transmit the data stored on your NFC tags.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Key Highlights") {
                PrivacyPointRow(
                    icon: "externaldrive.badge.checkmark",
                    color: .green,
                    title: "Zero Analytics & Tracking",
                    detail: "No third-party SDKs, no Google Analytics, no Firebase, and no behavioral tracking. The app contains no advertising or telemetry code."
                )

                PrivacyPointRow(
                    icon: "lock.shield",
                    color: .blue,
                    title: "100% On-Device Processing",
                    detail: "All NFC reading, writing, emulation analysis, memory dumping, and cryptographic validations are executed entirely on your iPhone's local processor."
                )

                PrivacyPointRow(
                    icon: "wifi.slash",
                    color: .orange,
                    title: "Local Network Bridge",
                    detail: "The 'Computer Reader' tool runs a local HTTP/SSE web server exclusively on your Wi-Fi subnet. It never connects to external servers or the cloud."
                )

                PrivacyPointRow(
                    icon: "tray.full",
                    color: .purple,
                    title: "Your Data Stays Yours",
                    detail: "Saved tags and manual command logs are stored exclusively in your iPhone's local SwiftData store. You can export or delete this data at any time in Settings."
                )
            }

            Section("System Permissions Explained") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("NFC Tag Reading Entitlement")
                        .font(.subheadline.weight(.semibold))
                    Text("Used exclusively to interface with the iPhone's NFC antenna to communicate with NFC tags you physically bring within proximity of your device.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Local Network Access")
                        .font(.subheadline.weight(.semibold))
                    Text("Requested only if you launch the Computer Reader feature to let your Mac or PC browser interact with the iPhone over your private home Wi-Fi network.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }

            Section {
                Button {
                    if let url = URL(string: "https://rshamilton.github.io/FreeNFC/privacy.html") {
                        openURL(url)
                    }
                } label: {
                    Label("View Web Privacy Policy", systemImage: "safari")
                }
            } footer: {
                Text("Last updated: September 2026. Free NFC is open-source software released under the MIT License.")
            }
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PrivacyPointRow: View {
    let icon: String
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
