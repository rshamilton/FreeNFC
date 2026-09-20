import CoreNFC
import SwiftUI

struct WriteFaceTimeView: View {
    enum Kind: String, CaseIterable { case video = "Video", audio = "Audio" }

    @State private var kind: Kind = .video
    @State private var target = ""

    var body: some View {
        Form {
            Section {
                Picker("Type", selection: $kind) {
                    ForEach(Kind.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
            }

            Section {
                TextField("Phone number or Apple ID email", text: $target)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } footer: {
                Text("Starts a FaceTime \(kind.rawValue.lowercased()) call with this contact when the tag is scanned.")
            }

            Section {
                AddRecordButton(title: "FaceTime", icon: kind == .video ? "video.circle.fill" : "phone.circle.fill", color: .green, subtitle: target.isEmpty ? "Empty" : target, buildPayload: buildPayload)
            }
        }
        .navigationTitle("Write FaceTime")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func buildPayload() throws -> NFCNDEFPayload {
        let uri = try InputValidators.buildFaceTime(target, audioOnly: kind == .audio)
        guard let payload = NDEFWriter.uri(uri) else {
            throw NFCError.custom("Couldn't build that FaceTime record.")
        }
        return payload
    }
}
