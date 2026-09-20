import CoreNFC
import SwiftUI

struct WritePaymentView: View {
    @State private var platform: PaymentPlatform = .venmo
    @State private var handle = ""
    @State private var amount = ""

    var body: some View {
        Form {
            Section("Platform") {
                Picker("Platform", selection: $platform) {
                    ForEach(PaymentPlatform.allCases) { p in
                        Label(p.displayName, systemImage: p.iconName)
                            .tag(p)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                HStack {
                    Text(platform.handlePrefix.isEmpty ? "" : platform.handlePrefix)
                        .foregroundStyle(.secondary)
                    TextField(platform.placeholder, text: $handle)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                if platform != .venmo {
                    TextField("Amount (optional)", text: $amount)
                        .keyboardType(.decimalPad)
                }
            } footer: {
                Text("Writes a link to your \(platform.displayName) payment page.")
            }

            Section {
                AddRecordButton(
                    title: platform.displayName,
                    icon: platform.iconName,
                    color: platform.brandColor,
                    subtitle: handle.isEmpty ? "Empty" : "\(platform.handlePrefix)\(handle)",
                    buildPayload: buildPayload
                )
            }
        }
        .navigationTitle("Write Payment Link")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func buildPayload() throws -> NFCNDEFPayload {
        let url = try platform.paymentURL(handle: handle, amount: amount)
        guard let payload = NDEFWriter.uri(url.absoluteString) else {
            throw NFCError.custom("Couldn't build that payment record.")
        }
        return payload
    }
}
