import AudioToolbox
import SwiftUI
import UIKit

/// Centralized haptic and acoustic feedback manager.
/// Respects user preferences configured in Settings.
@MainActor
final class FeedbackManager {
    static let shared = FeedbackManager()

    @AppStorage("hapticsEnabled") var hapticsEnabled: Bool = true
    @AppStorage("soundEnabled") var soundEnabled: Bool = true

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    private let selectionFeedback = UISelectionFeedbackGenerator()

    init() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        notificationFeedback.prepare()
        selectionFeedback.prepare()
    }

    // MARK: - Haptics

    func light() {
        guard hapticsEnabled else { return }
        lightImpact.impactOccurred()
    }

    func medium() {
        guard hapticsEnabled else { return }
        mediumImpact.impactOccurred()
    }

    func heavy() {
        guard hapticsEnabled else { return }
        heavyImpact.impactOccurred()
    }

    func selection() {
        guard hapticsEnabled else { return }
        selectionFeedback.selectionChanged()
    }

    func success() {
        if hapticsEnabled {
            notificationFeedback.notificationOccurred(.success)
        }
        if soundEnabled {
            // System sound for positive completion (similar to Apple Pay chime / photo shutter)
            AudioServicesPlaySystemSound(1054)
        }
    }

    func warning() {
        if hapticsEnabled {
            notificationFeedback.notificationOccurred(.warning)
        }
        if soundEnabled {
            AudioServicesPlaySystemSound(1053)
        }
    }

    func error() {
        if hapticsEnabled {
            notificationFeedback.notificationOccurred(.error)
        }
        if soundEnabled {
            AudioServicesPlaySystemSound(1053)
        }
    }

    func copied() {
        light()
    }
}
