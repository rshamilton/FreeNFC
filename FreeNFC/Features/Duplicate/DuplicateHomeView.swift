import CoreNFC
import SwiftData
import SwiftUI

struct DuplicateHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var nfc: NFCSessionManager
    @Query(sort: \SavedTag.dateSaved, order: .reverse) private var savedTags: [SavedTag]

    @State private var newlyScannedTag: ScannedTag?
    @State private var showingSaveAlert = false
    @State private var pendingSaveTag: ScannedTag?
    @State private var saveName = ""
    @State private var renamingTag: SavedTag?
    @State private var renameText = ""
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var toast: String?

    private var filteredTags: [SavedTag] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return savedTags
        }
        return savedTags.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.uid.localizedCaseInsensitiveContains(searchText) ||
            $0.familyRawValue.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            if let errorMessage {
                Section {
                    StatusBanner(kind: .error, message: errorMessage)
                }
            }

            scanSourceSection

            savedTagsSection
        }
        .searchable(text: $searchText, prompt: "Search saved tags by name, UID, or type")
        .navigationTitle("Duplicate")
        .alert("Name Source Tag", isPresented: $showingSaveAlert) {
            TextField("Tag Name", text: $saveName)
            Button("Save") { commitSave() }
            Button("Cancel", role: .cancel) { pendingSaveTag = nil }
        } message: {
            Text("Save this tag to your library to clone it onto target tags anytime.")
        }
        .alert("Rename Tag", isPresented: Binding(get: { renamingTag != nil }, set: { if !$0 { renamingTag = nil } })) {
            TextField("New Name", text: $renameText)
            Button("Save") {
                if let renamingTag, !renameText.trimmingCharacters(in: .whitespaces).isEmpty {
                    renamingTag.name = renameText.trimmingCharacters(in: .whitespaces)
                    FeedbackManager.shared.light()
                    toast = "Tag renamed"
                }
                renamingTag = nil
            }
            Button("Cancel", role: .cancel) { renamingTag = nil }
        }
        .overlay(alignment: .bottom) {
            if let toast {
                StatusBanner(kind: .success, message: toast)
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(for: .seconds(1.5))
                        self.toast = nil
                    }
            }
        }
        .animation(.easeInOut, value: toast)
    }

    // MARK: - Sections

    private var scanSourceSection: some View {
        Section {
            Button {
                Task { await scanSourceTag() }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "plus.viewfinder")
                        .font(.title2)
                        .foregroundStyle(.blue)
                        .frame(width: 36, height: 36)
                        .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Scan New Source Tag")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("Reads memory and records from a physical tag")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        } footer: {
            Text("To duplicate, first scan the source tag to save a clone template, then write it to one or more blank target tags.")
        }
    }

    private var savedTagsSection: some View {
        Section(header: Text("Saved Tag Library (\(savedTags.count))")) {
            if savedTags.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 38))
                        .foregroundStyle(.secondary)
                    Text("No Saved Tags")
                        .font(.headline)
                    Text("Tags you scan here or save from the Read tab will appear in this library ready to clone.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else if filteredTags.isEmpty {
                Text("No matching tags found.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(filteredTags, id: \.persistentModelID) { (saved: SavedTag) in
                    NavigationLink {
                        CloneTargetView(savedTag: saved)
                    } label: {
                        tagRow(saved)
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            renamingTag = saved
                            renameText = saved.name
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        .tint(.orange)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            modelContext.delete(saved)
                            FeedbackManager.shared.light()
                            toast = "Tag deleted"
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func tagRow(_ saved: SavedTag) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.on.doc.fill")
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(saved.name)
                    .font(.body.weight(.semibold))

                HStack(spacing: 6) {
                    Text(saved.familyRawValue)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.12), in: Capsule())
                        .foregroundStyle(.blue)

                    Text(saved.uid)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                if let scanned = saved.scannedTag {
                    Text("\(scanned.records.count) record\(scanned.records.count == 1 ? "" : "s") · \(scanned.dump?.totalBytes ?? 0)B memory")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    private func scanSourceTag() async {
        errorMessage = nil
        let outcome = await TagScanner.scan(using: nfc, alertMessage: "Hold iPhone near the tag you want to clone.")
        switch outcome {
        case .success(let tag):
            FeedbackManager.shared.success()
            pendingSaveTag = tag
            saveName = "\(tag.family.rawValue) (\(tag.uid.prefix(8)))"
            showingSaveAlert = true
        case .failure(let error):
            if !NFCSessionManager.isUserCancellation(error) {
                FeedbackManager.shared.error()
                errorMessage = NFCSessionManager.friendlyMessage(for: error)
            }
        }
    }

    private func commitSave() {
        guard let tag = pendingSaveTag else { return }
        let name = saveName.trimmingCharacters(in: .whitespaces).isEmpty ? "Tag \(tag.uid.prefix(8))" : saveName.trimmingCharacters(in: .whitespaces)
        let saved = SavedTag(name: name, scannedTag: tag)
        modelContext.insert(saved)
        FeedbackManager.shared.success()
        toast = "Saved to library"
        pendingSaveTag = nil
    }
}
