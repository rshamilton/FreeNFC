import SwiftUI

struct SupportHelpView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section("Scanning Tips") {
                SupportTipRow(
                    icon: "iphone.radiowaves.left.and.right",
                    title: "Antenna Location",
                    detail: "The iPhone NFC antenna is located at the very top edge on the back of the device. Rest the top rim of your phone directly against the tag."
                )
                SupportTipRow(
                    icon: "hand.raised",
                    title: "Hold Steady",
                    detail: "Keep the phone still for 1–2 seconds. Multi-page memory dumps and full chip diagnostics require several rapid round-trip transmissions."
                )
                SupportTipRow(
                    icon: "case",
                    title: "Remove Metal or Thick Cases",
                    detail: "MagSafe wallets, thick metal kickstands, or RFID-shielding cases can attenuate the 13.56 MHz NFC radio frequency field."
                )
            }

            Section("Frequently Asked Questions") {
                DisclosureGroup("Why can't I clone my transit card, badge, or Apple Pay card?") {
                    Text("Transit cards (Clipper, Suica, Oyster), contactless credit cards, and secure workplace badges use encrypted microcontrollers or proprietary protocols (like MIFARE Classic Crypto1 or EMV). iOS CoreNFC restricts arbitrary cryptographic keys to protect cardholder security, so encrypted sectors cannot be read or duplicated.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                }

                DisclosureGroup("What tags can I write and duplicate?") {
                    Text("Standard NDEF-compatible tags including NTAG213, NTAG215, NTAG216, MIFARE Ultralight, and ISO 15693 (Vicinity) tags work flawlessly for reading, writing, formatting, memory editing, and duplicating.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                }

                DisclosureGroup("How do I unbrick or recover a password-locked tag?") {
                    Text("Go to Tools → Password Protection → Recover. The app will systematically attempt factory defaults (FF FF FF FF and 00 00 00 00) or your entered candidate password to authenticate and restore the configuration pages to their unlocked state.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                }

                DisclosureGroup("How does the Computer Bridge reader work?") {
                    Text("When turned on in Tools → Computer Reader, your iPhone runs a lightweight web server on your local Wi-Fi network. Open the displayed URL in Chrome or Safari on your Mac or PC to trigger scans and writes from your computer without cables or software installation.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                }
            }

            Section("Contact & Assistance") {
                Button {
                    if let url = URL(string: "https://rshamilton.github.io/FreeNFC/support.html") {
                        openURL(url)
                    }
                } label: {
                    Label("Visit Online Support Portal", systemImage: "questionmark.circle")
                }

                Button {
                    if let url = URL(string: "https://github.com/rshamilton/FreeNFC/issues/new") {
                        openURL(url)
                    }
                } label: {
                    Label("Report an Issue on GitHub", systemImage: "ant.circle")
                }

                Button {
                    let mailto = "mailto:freenfc@googlegroups.com?subject=Free%20NFC%20Feedback%20%26%20Support"
                    if let url = URL(string: mailto) {
                        openURL(url)
                    }
                } label: {
                    Label("Email Developer", systemImage: "envelope")
                }
            }
        }
        .navigationTitle("Support & Help")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SupportTipRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
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
