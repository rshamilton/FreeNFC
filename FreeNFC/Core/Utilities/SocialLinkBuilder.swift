import Foundation
import SwiftUI

enum SocialPlatform: String, CaseIterable, Identifiable, Codable {
    case instagram, x, tiktok, facebook, linkedin, snapchat, youtube, github

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .instagram: return "Instagram"
        case .x: return "X (Twitter)"
        case .tiktok: return "TikTok"
        case .facebook: return "Facebook"
        case .linkedin: return "LinkedIn"
        case .snapchat: return "Snapchat"
        case .youtube: return "YouTube"
        case .github: return "GitHub"
        }
    }

    var iconName: String {
        switch self {
        case .instagram: return "camera.circle.fill"
        case .x: return "at.circle.fill"
        case .tiktok: return "music.note.list"
        case .facebook: return "person.2.circle.fill"
        case .linkedin: return "briefcase.circle.fill"
        case .snapchat: return "flame.fill"
        case .youtube: return "play.circle.fill"
        case .github: return "chevron.left.forwardslash.chevron.right"
        }
    }

    var brandColor: Color {
        switch self {
        case .instagram: return Color(red: 0.83, green: 0.18, blue: 0.51)
        case .x: return .black
        case .tiktok: return .black
        case .facebook: return Color(red: 0.09, green: 0.46, blue: 0.82)
        case .linkedin: return Color(red: 0.0, green: 0.47, blue: 0.71)
        case .snapchat: return Color(red: 1.0, green: 0.98, blue: 0.0)
        case .youtube: return Color(red: 1.0, green: 0.0, blue: 0.0)
        case .github: return .black
        }
    }

    /// Glyph color chosen for contrast against `brandColor` (mainly matters for Snapchat's
    /// near-white yellow, which needs a dark glyph instead of the usual white).
    var glyphColor: Color {
        self == .snapchat ? .black : .white
    }

    var placeholder: String { "username" }

    func profileURL(username rawUsername: String) throws -> URL {
        var username = rawUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !username.isEmpty else { throw ValidationError.empty("Username") }
        if username.hasPrefix("@") { username.removeFirst() }
        let encoded = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username

        let base: String
        switch self {
        case .instagram: base = "https://instagram.com/"
        case .x: base = "https://x.com/"
        case .tiktok: base = "https://tiktok.com/@"
        case .facebook: base = "https://facebook.com/"
        case .linkedin: base = "https://linkedin.com/in/"
        case .snapchat: base = "https://snapchat.com/add/"
        case .youtube: base = "https://youtube.com/@"
        case .github: base = "https://github.com/"
        }

        guard let url = URL(string: base + encoded) else { throw ValidationError.invalidURL }
        return url
    }
}
