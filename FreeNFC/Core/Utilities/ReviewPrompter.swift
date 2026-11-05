import StoreKit
import UIKit

/// Asks for an App Store rating at natural moments — right after something the user set out
/// to do actually worked (a tag was written, duplicated, or read) — and never more than
/// once per app version or more often than every couple of months.
///
/// iOS also applies its own limits (at most three system prompts per year), so this is
/// deliberately conservative.
@MainActor
enum ReviewPrompter {
    enum Moment {
        /// A tag was written or duplicated — the strongest "this app just helped me" signal.
        case majorSuccess
        /// A tag was read successfully.
        case minorSuccess

        var weight: Int {
            switch self {
            case .majorSuccess: return 2
            case .minorSuccess: return 1
            }
        }
    }

    static let appStoreID = "6801674087"
    static let writeReviewURL = URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")!

    private static let pointsThreshold = 6
    private static let minimumDaysBetweenPrompts: Double = 60

    private enum Keys {
        static let points = "reviewPrompt.points"
        static let lastPromptedVersion = "reviewPrompt.lastVersion"
        static let lastPromptDate = "reviewPrompt.lastDate"
    }

    private static var defaults: UserDefaults { .standard }

    private static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// Record a successful action and, if enough have accumulated, ask for a review a moment
    /// later so the system NFC sheet has time to dismiss first.
    static func recordSuccess(_ moment: Moment) {
        let points = defaults.integer(forKey: Keys.points) + moment.weight
        defaults.set(points, forKey: Keys.points)

        guard points >= pointsThreshold else { return }
        guard defaults.string(forKey: Keys.lastPromptedVersion) != currentVersion else { return }
        if let last = defaults.object(forKey: Keys.lastPromptDate) as? Date,
           Date().timeIntervalSince(last) < minimumDaysBetweenPrompts * 86_400 {
            return
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) else { return }
            AppStore.requestReview(in: scene)
            defaults.set(currentVersion, forKey: Keys.lastPromptedVersion)
            defaults.set(Date(), forKey: Keys.lastPromptDate)
            defaults.set(0, forKey: Keys.points)
        }
    }
}
