import SwiftUI

/// A small colored circle badge for a social platform's icon, since a plain tinted SF Symbol
/// disappears against light platform colors (Snapchat's yellow especially).
struct SocialBadge: View {
    let platform: SocialPlatform
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: platform.iconName)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(platform.glyphColor)
            .frame(width: size, height: size)
            .background(platform.brandColor, in: Circle())
    }
}
