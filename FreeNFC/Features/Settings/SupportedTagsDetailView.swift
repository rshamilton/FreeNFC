import SwiftUI

struct SupportedTagsDetailView: View {
    var body: some View {
        List {
            Section("Full Read, Write & Tool Support") {
                TechCard(
                    title: "MIFARE Ultralight / NTAG21x",
                    chips: "NTAG213, NTAG215, NTAG216, Ultralight EV1, Ultralight C",
                    status: "Full Support",
                    statusColor: .green,
                    features: [
                        "Read & Write standard NDEF records",
                        "Complete raw 4-byte page memory dump",
                        "Format blank chips as NDEF containers",
                        "Permanent lock bits configuration",
                        "32-bit password protection, change, and unbricking recovery",
                        "Byte-level Memory Editor and full .bin backup/restore",
                        "Raw GET_VERSION, READ, WRITE, and PWD_AUTH commands"
                    ]
                )

                TechCard(
                    title: "ISO 15693 (Vicinity Cards & Tags)",
                    chips: "ICODE SLIX, ICODE SLIX2, Tag-it HF-I, EM4233",
                    status: "Full Support",
                    statusColor: .green,
                    features: [
                        "Read & Write standard NDEF records across long read range",
                        "Multi-block raw memory reading & writing",
                        "Block locking and lock status inspection",
                        "DSFID and AFI configuration commands",
                        "Memory Editor and .bin dump/restore support",
                        "Custom ISO 15693 single/multi-block transceive commands"
                    ]
                )
            }

            Section("Specialized & Smart Card Support") {
                TechCard(
                    title: "ISO 7816 (Smart Cards & Type 4 NFC)",
                    chips: "DESFire EV1/EV2/EV3, Type 4 Tag, Calypso, JavaCard",
                    status: "NDEF + APDU Passthrough",
                    statusColor: .blue,
                    features: [
                        "Read & Write Type 4 NDEF files via Application Select",
                        "Raw APDU command transceiver (CLA, INS, P1, P2, Lc, Data, Le)",
                        "Automatic SW1/SW2 status code inspection",
                        "Originality & historical bytes decoding",
                        "Note: Raw hardware memory mapping is protected by smart card OS"
                    ]
                )

                TechCard(
                    title: "FeliCa (JIS X 6319-4 / NFC Type 3)",
                    chips: "FeliCa Lite-S, FeliCa Standard",
                    status: "NDEF + Command Passthrough",
                    statusColor: .blue,
                    features: [
                        "Read & Write Type 3 NDEF blocks",
                        "System Code and Manufacturer Code extraction",
                        "Raw command packet passthrough (Polling, Request Service)"
                    ]
                )
            }

            Section("Restricted & Proprietary Technologies") {
                TechCard(
                    title: "MIFARE Classic (1K / 4K / Mini)",
                    chips: "Classic 1K, Classic 4K",
                    status: "UID Detection Only",
                    statusColor: .orange,
                    features: [
                        "7-byte or 4-byte UID detection and card family identification",
                        "Apple CoreNFC does not provide raw hardware access to the proprietary Crypto1 authentication engine required to read or write Classic sectors on iOS."
                    ]
                )
            }

            Section("Built-in Safety Safeguards") {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Safety Overrides", systemImage: "shield.lefthalf.filled")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.blue)

                    Text("Free NFC actively guards against accidental tag bricking by protecting lock bytes (pages 0x02–0x03), capability containers (page 0x03), and password/auth registers (pages 0xE2–0xE5 on NTAG215) during standard write operations.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Advanced engineers can toggle the 'Allow writing protected pages' switch in the Memory Editor and .bin Restore tools when deliberate low-level reconfiguration is needed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Tag Compatibility")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TechCard: View {
    let title: String
    let chips: String
    let status: String
    let statusColor: Color
    let features: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text(status)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor.opacity(0.12), in: Capsule())
            }

            Text(chips)
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(features, id: \.self) { feature in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                            .padding(.top, 2)
                        Text(feature)
                            .font(.caption)
                    }
                }
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 6)
    }
}
