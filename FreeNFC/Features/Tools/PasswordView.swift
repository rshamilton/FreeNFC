import CoreNFC
import SwiftUI

struct PasswordView: View {
    enum Mode: String, CaseIterable {
        case set = "Set"
        case change = "Change"
        case remove = "Remove"
        case recover = "Recover"
    }

    @EnvironmentObject private var nfc: NFCSessionManager
    @State private var mode: Mode = .set
    @State private var enterAsHex = false
    @State private var currentPassword = ""
    @State private var newPassword = ""
    /// Which password Recover will try on the next scan. Only one attempt is possible per scan,
    /// so each failure advances this and the user taps again.
    @State private var recoverAttemptIndex = 0
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var showConfirm = false

    var body: some View {
        Form {
            modeSection
            hexSection

            if mode == .change || mode == .remove {
                Section(mode == .remove ? "Password" : "Current Password") {
                    passwordField(text: $currentPassword)
                }
            }

            if mode == .recover {
                recoverSection
            }

            if mode == .set || mode == .change {
                Section {
                    passwordField(text: $newPassword)
                } header: {
                    Text("New Password")
                } footer: {
                    Text("Write this down \u{2014} if it's lost, the protected pages can't be read or written again.")
                }
            }

            if let errorMessage {
                Section { StatusBanner(kind: .error, message: errorMessage) }
                    .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
            }
            if let successMessage {
                Section { StatusBanner(kind: .success, message: successMessage) }
                    .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
            }

            Section {
                PrimaryActionRow(
                    title: mode == .recover ? "Recover Tag" : "\(mode.rawValue) Password",
                    systemImage: mode == .recover ? "bandage" : "key",
                    isBusy: nfc.isScanning
                ) {
                    if validate() { showConfirm = true }
                }
            }
        }
        .navigationTitle("Password Protection")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: mode) { _, _ in resetProgress() }
        .onChange(of: currentPassword) { _, _ in recoverAttemptIndex = 0 }
        .confirmationDialog("\(mode.rawValue) Password", isPresented: $showConfirm, titleVisibility: .visible) {
            Button("Hold Near Tag") { Task { await run() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(confirmMessage)
        }
    }

    // MARK: - Sections

    private var modeSection: some View {
        Section {
            Picker("Action", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { Text($0.rawValue) }
            }
            .pickerStyle(.segmented)
        } footer: {
            Text(modeExplanation)
        }
    }

    private var hexSection: some View {
        Section {
            Toggle("Enter password as hex", isOn: $enterAsHex)
        } footer: {
            Text(enterAsHex
                 ? "Passwords are 4 bytes \u{2014} 8 hex digits, e.g. FF FF FF FF."
                 : "Passwords are exactly 4 characters. Turn on hex to enter raw bytes like 00000000.")
        }
    }

    private var recoverSection: some View {
        Section {
            passwordField(text: $currentPassword)
            if let candidate = currentCandidate {
                LabeledContent("Next attempt", value: candidate.label)
            }
        } header: {
            Text("Known Password (optional)")
        } footer: {
            Text("Leave blank to work through the common defaults \u{2014} FF FF FF FF (the factory value) then 00 00 00 00. A tag stops responding the moment it rejects a password, so only one can be tried per scan: if it's wrong, just hold the tag to the phone again to try the next one.")
        }
    }

    @ViewBuilder
    private func passwordField(text: Binding<String>) -> some View {
        Group {
            if enterAsHex {
                TextField("FF FF FF FF", text: text)
                    .font(.system(.body, design: .monospaced))
            } else {
                SecureField("4 characters", text: text)
            }
        }
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
    }

    // MARK: - Recovery candidates

    /// Ordered passwords Recover will work through: anything typed in first, then the two
    /// defaults a mis-written tag realistically ends up with.
    private var recoverCandidates: [(label: String, data: Data)] {
        var list: [(label: String, data: Data)] = []
        if let entered = passwordData(currentPassword, allowEmpty: true), !entered.isEmpty {
            list.append((label: "your password", data: entered))
        }
        list.append((label: "FF FF FF FF", data: Data([0xFF, 0xFF, 0xFF, 0xFF])))
        list.append((label: "00 00 00 00", data: Data([0x00, 0x00, 0x00, 0x00])))
        return list
    }

    private var currentCandidate: (label: String, data: Data)? {
        let candidates = recoverCandidates
        guard !candidates.isEmpty else { return nil }
        return candidates[min(recoverAttemptIndex, candidates.count - 1)]
    }

    // MARK: - Copy

    private var modeExplanation: String {
        switch mode {
        case .set: return "Password-protect a MIFARE Ultralight / NTAG tag's pages."
        case .change: return "Replace the tag's existing password with a new one."
        case .remove: return "Remove password protection using the current password."
        case .recover: return "Unbrick a tag that got password-locked by accident \u{2014} clears protection and resets the configuration to factory."
        }
    }

    private var confirmMessage: String {
        switch mode {
        case .set: return "The tag will require this password for future reads/writes of its protected pages."
        case .change: return "Replaces the tag's current password with the new one."
        case .remove: return "Removes password protection from this tag entirely."
        case .recover:
            return "Tries \(currentCandidate?.label ?? "the default password"), then clears protection and restores the factory configuration."
        }
    }

    // MARK: - Validation

    /// Turns a password field into 4 bytes, honoring the hex toggle. Empty is allowed only for
    /// the optional Recover field.
    private func passwordData(_ raw: String, allowEmpty: Bool = false) -> Data? {
        if raw.isEmpty { return allowEmpty ? Data() : nil }
        if enterAsHex {
            guard let data = HexUtils.data(fromHex: raw), data.count == 4 else { return nil }
            return data
        } else {
            guard raw.utf8.count == 4 else { return nil }
            return Data(raw.utf8)
        }
    }

    private func validate() -> Bool {
        errorMessage = nil
        let unit = enterAsHex ? "8 hex digits (4 bytes)" : "exactly 4 characters"
        if mode == .change || mode == .remove {
            guard passwordData(currentPassword) != nil else {
                errorMessage = "Current password must be \(unit)."
                return false
            }
        }
        if mode == .recover, !currentPassword.isEmpty, passwordData(currentPassword) == nil {
            errorMessage = "That password must be \(unit), or leave it blank."
            return false
        }
        if mode == .set || mode == .change {
            guard passwordData(newPassword) != nil else {
                errorMessage = "New password must be \(unit)."
                return false
            }
        }
        return true
    }

    private func resetProgress() {
        recoverAttemptIndex = 0
        errorMessage = nil
        successMessage = nil
    }

    private func isWrongPassword(_ error: Error) -> Bool {
        if let nfcError = error as? NFCError, case .wrongPassword = nfcError { return true }
        return false
    }

    // MARK: - Run

    private func run() async {
        errorMessage = nil
        successMessage = nil

        let candidates = recoverCandidates
        let candidate = currentCandidate

        let outcome = await nfc.perform(alertMessage: "Hold your iPhone near the tag.") { tag, session in
            guard case .miFare(let t) = tag, TagFamilyResolver.family(for: tag) == .ultralightOrNTAG else {
                throw NFCError.custom("Password protection is only available for MIFARE Ultralight / NTAG tags.")
            }
            let layout = try await t.ulRequireLayout()
            switch mode {
            case .set:
                guard let new = passwordData(newPassword) else { throw NFCError.custom("Invalid new password.") }
                try await t.ulSetPassword(password: new, pack: Data([0x00, 0x00]), layout: layout)
            case .change:
                guard let current = passwordData(currentPassword), let new = passwordData(newPassword) else {
                    throw NFCError.custom("Invalid password.")
                }
                try await t.ulChangePassword(current: current, newPassword: new, newPack: Data([0x00, 0x00]), layout: layout)
            case .remove:
                guard let current = passwordData(currentPassword) else { throw NFCError.custom("Invalid password.") }
                try await t.ulRemovePassword(current: current, layout: layout)
            case .recover:
                guard let candidate else { throw NFCError.custom("No password available to try.") }
                try await t.ulRecoverProtection(password: candidate.data, layout: layout)
            }
        }

        switch outcome {
        case .success:
            if mode == .recover, let candidate {
                successMessage = "Recovered using \(candidate.label). Protection is off and the password is back to the factory default."
                recoverAttemptIndex = 0
            } else {
                successMessage = successText
            }
            currentPassword = ""
            newPassword = ""

        case .failure(let error):
            guard !NFCSessionManager.isUserCancellation(error) else { return }
            if mode == .recover, let candidate, isWrongPassword(error) {
                let next = recoverAttemptIndex + 1
                if next < candidates.count {
                    recoverAttemptIndex = next
                    errorMessage = "\(candidate.label) wasn't it. The tag stops responding once it rejects a password, so hold it to the phone again to try \(candidates[next].label)."
                } else {
                    recoverAttemptIndex = 0
                    errorMessage = "None of those passwords worked. If you know the tag's real password, enter it above and try again."
                }
            } else {
                errorMessage = NFCSessionManager.friendlyMessage(for: error)
            }
        }
    }

    private var successText: String {
        switch mode {
        case .set: return "Password set."
        case .change: return "Password changed."
        case .remove: return "Password removed."
        case .recover: return "Tag recovered."
        }
    }
}
