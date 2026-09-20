import CoreNFC
import SwiftUI

struct WriteContactView: View {
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var organization = ""
    @State private var phone = ""
    @State private var email = ""

    var body: some View {
        Form {
            Section {
                TextField("First Name", text: $firstName).textContentType(.givenName)
                TextField("Last Name", text: $lastName).textContentType(.familyName)
                TextField("Organization", text: $organization).textContentType(.organizationName)
                TextField("Phone", text: $phone).keyboardType(.phonePad).textContentType(.telephoneNumber)
                TextField("Email", text: $email).keyboardType(.emailAddress).textContentType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
            } header: {
                Text("Contact")
            } footer: {
                Text("Writes a vCard. Most phones offer to save it as a contact when the tag is scanned.")
            }

            Section {
                AddRecordButton(
                    title: "Contact Card",
                    icon: "person.text.rectangle",
                    color: .orange,
                    subtitle: "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces).isEmpty ? "Empty" : "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces),
                    buildPayload: buildPayload
                )
            }
        }
        .navigationTitle("Write Contact Card")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func buildPayload() throws -> NFCNDEFPayload {
        guard !firstName.trimmingCharacters(in: .whitespaces).isEmpty || !lastName.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ValidationError.empty("Name")
        }

        var lines = ["BEGIN:VCARD", "VERSION:3.0"]
        lines.append("N:\(lastName);\(firstName);;;")
        lines.append("FN:\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces))
        if !organization.isEmpty { lines.append("ORG:\(organization)") }
        if !phone.isEmpty {
            let normalizedPhone = (try? InputValidators.normalizePhone(phone)) ?? phone
            lines.append("TEL;TYPE=CELL:\(normalizedPhone)")
        }
        if !email.isEmpty {
            let normalizedEmail = try InputValidators.normalizeEmail(email)
            lines.append("EMAIL:\(normalizedEmail)")
        }
        lines.append("END:VCARD")

        let vcard = lines.joined(separator: "\r\n")
        return NDEFWriter.mime(type: "text/vcard", data: Data(vcard.utf8))
    }
}
