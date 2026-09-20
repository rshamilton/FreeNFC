import Foundation
import SwiftData

/// A saved/cloneable tag (Duplicate flow step 1, and general scan history).
@Model
final class SavedTag {
    var name: String
    var uid: String
    var familyRawValue: String
    var dateSaved: Date
    var encodedScannedTag: Data

    init(name: String, scannedTag: ScannedTag) {
        self.name = name
        self.uid = scannedTag.uid
        self.familyRawValue = scannedTag.familyRawValue
        self.dateSaved = Date()
        self.encodedScannedTag = (try? JSONEncoder().encode(scannedTag)) ?? Data()
    }

    var scannedTag: ScannedTag? {
        try? JSONDecoder().decode(ScannedTag.self, from: encodedScannedTag)
    }

    var family: TagFamily { TagFamily(rawValue: familyRawValue) ?? .unknown }
}

/// One entry in the Manual Commands log.
@Model
final class CommandHistoryEntry {
    var date: Date
    var techLabel: String
    var commandHex: String
    var responseHex: String
    var succeeded: Bool

    init(techLabel: String, commandHex: String, responseHex: String, succeeded: Bool) {
        self.date = Date()
        self.techLabel = techLabel
        self.commandHex = commandHex
        self.responseHex = responseHex
        self.succeeded = succeeded
    }
}

enum AppSchema {
    static let models: [any PersistentModel.Type] = [SavedTag.self, CommandHistoryEntry.self]
}
