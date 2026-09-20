import CoreNFC
import SwiftUI

/// iOS has no public API to auto-join Wi-Fi from an NFC tag, and there's no single standard
/// binary format phones agree on. This writes the same "WIFI:S:...;T:...;P:...;;" text token
/// used by Wi-Fi QR codes -- apps (including some Android NFC readers) that understand that
/// format can use it, but auto-join on iPhone isn't possible from a plain NDEF tag.
struct WriteWiFiView: View {
    enum Security: String, CaseIterable { case wpa = "WPA/WPA2", wep = "WEP", none = "None" }

    @State private var ssid = ""
    @State private var password = ""
    @State private var security: Security = .wpa

    var body: some View {
        Form {
            Section {
                TextField("Network Name (SSID)", text: $ssid)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Picker("Security", selection: $security) {
                    ForEach(Security.allCases, id: \.self) { Text($0.rawValue) }
                }
                if security != .none {
                    SecureField("Password", text: $password)
                }
            } footer: {
                Text("Writes a Wi-Fi QR-style text token. Works with apps that scan for it; iPhone can't auto-join a network from an NFC tag.")
            }

            Section {
                AddRecordButton(title: "Wi-Fi Network", icon: "wifi", color: .teal, subtitle: ssid.isEmpty ? "Empty" : ssid, buildPayload: buildPayload)
            }
        }
        .navigationTitle("Write Wi-Fi Network")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func buildPayload() throws -> NFCNDEFPayload {
        let trimmedSSID = ssid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSSID.isEmpty else { throw ValidationError.empty("Network Name") }

        let securityCode: String
        switch security {
        case .wpa: securityCode = "WPA"
        case .wep: securityCode = "WEP"
        case .none: securityCode = "nopass"
        }

        var token = "WIFI:S:\(escape(trimmedSSID));T:\(securityCode);"
        if security != .none {
            token += "P:\(escape(password));"
        }
        token += ";"

        guard let payload = NDEFWriter.text(token) else {
            throw NFCError.custom("Couldn't build that Wi-Fi record.")
        }
        return payload
    }

    private func escape(_ string: String) -> String {
        var result = ""
        for character in string {
            if ";:,\\".contains(character) { result.append("\\") }
            result.append(character)
        }
        return result
    }
}
