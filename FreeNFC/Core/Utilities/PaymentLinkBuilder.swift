import Foundation
import SwiftUI

enum PaymentPlatform: String, CaseIterable, Identifiable, Codable {
    case venmo, paypal, cashApp

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .venmo: return "Venmo"
        case .paypal: return "PayPal"
        case .cashApp: return "Cash App"
        }
    }

    var handlePrefix: String {
        switch self {
        case .venmo: return "@"
        case .paypal: return ""
        case .cashApp: return "$"
        }
    }

    var placeholder: String {
        switch self {
        case .venmo: return "username"
        case .paypal: return "username"
        case .cashApp: return "cashtag"
        }
    }

    var iconName: String {
        switch self {
        case .venmo: return "dollarsign.circle.fill"
        case .paypal: return "creditcard.circle.fill"
        case .cashApp: return "banknote.fill"
        }
    }

    var brandColor: Color {
        switch self {
        case .venmo: return Color(red: 0.13, green: 0.60, blue: 0.95)
        case .paypal: return Color(red: 0.0, green: 0.32, blue: 0.62)
        case .cashApp: return Color(red: 0.0, green: 0.78, blue: 0.33)
        }
    }

    /// PayPal amounts append to the path; Venmo/Cash App don't support a universal-link amount.
    func paymentURL(handle rawHandle: String, amount: String) throws -> URL {
        var handle = rawHandle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !handle.isEmpty else { throw ValidationError.empty("Handle") }
        if handle.hasPrefix(handlePrefix), !handlePrefix.isEmpty {
            handle.removeFirst(handlePrefix.count)
        }
        let encoded = handle.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? handle
        let trimmedAmount = amount.trimmingCharacters(in: .whitespacesAndNewlines)

        let string: String
        switch self {
        case .venmo:
            string = "https://venmo.com/\(encoded)"
        case .paypal:
            string = trimmedAmount.isEmpty ? "https://paypal.me/\(encoded)" : "https://paypal.me/\(encoded)/\(trimmedAmount)"
        case .cashApp:
            string = trimmedAmount.isEmpty ? "https://cash.app/$\(encoded)" : "https://cash.app/$\(encoded)/\(trimmedAmount)"
        }

        guard let url = URL(string: string) else { throw ValidationError.invalidURL }
        return url
    }
}
