import CoreNFC
import SwiftUI

/// One record a user has added to the set they're building in Write, before it's written.
struct ComposedRecord: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let iconName: String
    let iconColor: Color
    let payload: NFCNDEFPayload
}

/// Holds the in-progress list of records for the Write tab. A blank tag can hold a link, a
/// Wi-Fi block, a contact card, and more all at once -- this lets someone build that up one
/// record at a time, reorder or remove any of them, then write them all to the tag in one scan.
@MainActor
final class WriteComposerStore: ObservableObject {
    @Published var records: [ComposedRecord] = []

    func add(title: String, subtitle: String, icon: String, color: Color, payload: NFCNDEFPayload) {
        records.append(ComposedRecord(title: title, subtitle: subtitle, iconName: icon, iconColor: color, payload: payload))
    }

    func remove(at offsets: IndexSet) {
        records.remove(atOffsets: offsets)
    }

    func move(from source: IndexSet, to destination: Int) {
        records.move(fromOffsets: source, toOffset: destination)
    }

    func clear() {
        records.removeAll()
    }

    func buildMessage() -> NFCNDEFMessage {
        NFCNDEFMessage(records: records.map(\.payload))
    }

    var totalBytes: Int {
        records.reduce(0) { $0 + $1.payload.payload.count }
    }
}
