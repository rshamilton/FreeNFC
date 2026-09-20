import UIKit

enum Clipboard {
    @MainActor
    static func copy(_ string: String) {
        UIPasteboard.general.string = string
        FeedbackManager.shared.copied()
    }

    @MainActor
    static func copy(_ data: Data) {
        UIPasteboard.general.string = data.hexString
        FeedbackManager.shared.copied()
    }
}
