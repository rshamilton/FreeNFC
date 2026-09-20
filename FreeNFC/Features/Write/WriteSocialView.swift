import CoreNFC
import SwiftUI

struct WriteSocialView: View {
    @State private var platform: SocialPlatform = .instagram
    @State private var username = ""

    var body: some View {
        Form {
            Section("Platform") {
                Picker("Platform", selection: $platform) {
                    ForEach(SocialPlatform.allCases) { p in
                        Label {
                            Text(p.displayName)
                        } icon: {
                            SocialBadge(platform: p)
                        }
                        .tag(p)
                    }
                }
                .pickerStyle(.navigationLink)
            }

            Section {
                HStack {
                    Text("@")
                        .foregroundStyle(.secondary)
                    TextField(platform.placeholder, text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            } footer: {
                Text("Writes a link to your \(platform.displayName) profile.")
            }

            Section {
                AddRecordButton(
                    title: platform.displayName,
                    icon: platform.iconName,
                    color: platform.brandColor,
                    subtitle: username.isEmpty ? "Empty" : "@\(username)",
                    buildPayload: buildPayload
                )
            }
        }
        .navigationTitle("Write Social Profile")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func buildPayload() throws -> NFCNDEFPayload {
        let url = try platform.profileURL(username: username)
        guard let payload = NDEFWriter.uri(url.absoluteString) else {
            throw NFCError.custom("Couldn't build that link record.")
        }
        return payload
    }
}
