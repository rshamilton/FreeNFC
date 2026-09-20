import Foundation

enum ValidationError: LocalizedError {
    case empty(String)
    case invalidURL
    case invalidEmail
    case invalidPhone

    var errorDescription: String? {
        switch self {
        case .empty(let field): return "\(field) can't be empty."
        case .invalidURL: return "That doesn't look like a valid web address."
        case .invalidEmail: return "That doesn't look like a valid email address."
        case .invalidPhone: return "That doesn't look like a valid phone number."
        }
    }
}

/// Cleans up and validates the free-text people actually type, so a forgotten "https://"
/// or a stray space doesn't produce a dead tag.
enum InputValidators {
    /// Accepts "example.com", "www.example.com", or a fully-qualified URL and returns a
    /// normalized https:// URL (or the original scheme if one was already given).
    static func normalizeWebURL(_ input: String) throws -> URL {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw ValidationError.empty("Link") }

        if !text.contains("://") {
            text = "https://" + text
        }

        guard var components = URLComponents(string: text),
              let host = components.host, !host.isEmpty,
              host.contains(".") else {
            throw ValidationError.invalidURL
        }

        if components.scheme?.lowercased() != "http", components.scheme?.lowercased() != "https" {
            components.scheme = "https"
        }

        guard let url = components.url else { throw ValidationError.invalidURL }
        return url
    }

    /// Validates a custom URL scheme / universal link / App Store link without forcing https.
    static func normalizeAppLink(_ input: String) throws -> URL {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw ValidationError.empty("Link") }
        guard let url = URL(string: text), url.scheme != nil else {
            throw ValidationError.invalidURL
        }
        return url
    }

    static func normalizeEmail(_ input: String) throws -> String {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !text.isEmpty else { throw ValidationError.empty("Email") }
        let pattern = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        guard text.range(of: pattern, options: .regularExpression) != nil else {
            throw ValidationError.invalidEmail
        }
        return text
    }

    static func buildMailto(to: String, subject: String, body: String) throws -> String {
        let address = try normalizeEmail(to)
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        var items: [URLQueryItem] = []
        if !subject.isEmpty { items.append(URLQueryItem(name: "subject", value: subject)) }
        if !body.isEmpty { items.append(URLQueryItem(name: "body", value: body)) }
        if !items.isEmpty { components.queryItems = items }
        guard let string = components.string else { throw ValidationError.invalidEmail }
        return string
    }

    /// Strips everything but digits and a leading +, so "(555) 123-4567" becomes "+15551234567"-safe.
    static func normalizePhone(_ input: String) throws -> String {
        let allowed = input.filter { $0.isNumber || $0 == "+" }
        guard allowed.count >= 3 else { throw ValidationError.invalidPhone }
        return allowed
    }

    static func buildTel(_ input: String) throws -> String {
        "tel:" + (try normalizePhone(input))
    }

    static func buildSMS(_ input: String, body: String) throws -> String {
        let number = try normalizePhone(input)
        if body.isEmpty { return "sms:\(number)" }
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return "sms:\(number)&body=\(encodedBody)"
    }

    /// wa.me link that opens a WhatsApp chat, optionally pre-filled with a message.
    static func buildWhatsApp(_ input: String, message: String) throws -> String {
        let number = try normalizePhone(input).filter(\.isNumber) // wa.me wants digits only, no +
        guard number.count >= 6 else { throw ValidationError.invalidPhone }
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "https://wa.me/\(number)" }
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return "https://wa.me/\(number)?text=\(encoded)"
    }

    /// A FaceTime link. `audioOnly` uses the `facetime-audio:` scheme.
    static func buildFaceTime(_ input: String, audioOnly: Bool) throws -> String {
        let target = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { throw ValidationError.empty("Phone or email") }
        // FaceTime accepts a phone number or an email address.
        let value: String
        if target.contains("@") {
            value = try normalizeEmail(target)
        } else {
            value = try normalizePhone(target)
        }
        return "\(audioOnly ? "facetime-audio" : "facetime"):\(value)"
    }

    /// A Maps link that searches for a place name or street address.
    static func buildMapsSearch(_ input: String) throws -> String {
        let query = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { throw ValidationError.empty("Address") }
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return "https://maps.apple.com/?q=\(encoded)"
    }
}
