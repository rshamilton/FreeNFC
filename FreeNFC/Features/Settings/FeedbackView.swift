import SwiftUI
import UIKit

/// Shared contact details and helpers for every feedback entry point.
enum SupportContact {
    static let email = "freenfc@googlegroups.com"
    static let issuesURL = URL(string: "https://github.com/rshamilton/FreeNFC/issues")!
    static let bugReportURL = URL(string: "https://github.com/rshamilton/FreeNFC/issues/new?template=bug_report.yml")!
    static let featureRequestURL = URL(string: "https://github.com/rshamilton/FreeNFC/issues/new?template=feature_request.yml")!

    static var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    @MainActor
    static var deviceSummary: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let model = withUnsafeBytes(of: &systemInfo.machine) { raw in
            String(decoding: raw.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
        return "NFC Forge \(appVersion) · iOS \(UIDevice.current.systemVersion) · \(model)"
    }

    @MainActor
    static func mailURL(subject: String, body: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body + "\n\n—\n\(deviceSummary)")
        ]
        return components.url
    }
}

// MARK: - Send Feedback

struct FeedbackView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "envelope.open.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.blue)
                    Text("I read every message.")
                        .font(.headline)
                    Text("NFC Forge is built by one person, and every email sent here lands in front of me — I read all of them. Your note doesn't need to be important or polished: a quick “this was confusing,” “I love this,” or “I wish it did X” is genuinely helpful.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            Section {
                Button {
                    if let url = SupportContact.mailURL(subject: "NFC Forge Feedback", body: "") {
                        openURL(url)
                    }
                } label: {
                    Label("Email Feedback", systemImage: "envelope")
                }

                Button {
                    UIPasteboard.general.string = SupportContact.email
                    FeedbackManager.shared.copied()
                } label: {
                    HStack {
                        Label("Copy Address", systemImage: "doc.on.doc")
                        Spacer()
                        Text(SupportContact.email)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            } footer: {
                Text("Your app version and iOS version are added to the bottom of the email so I can help faster. Feel free to delete them.")
            }

            Section {
                Button {
                    openURL(ReviewPrompter.writeReviewURL)
                } label: {
                    Label("Rate NFC Forge on the App Store", systemImage: "star.bubble")
                }
            } footer: {
                Text("If NFC Forge has been useful, a quick rating helps other people find a free, ad-free NFC tool.")
            }
        }
        .navigationTitle("Send Feedback")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Report a Bug / Request a Feature

struct IssueReportView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section {
                Text("Found something broken or have an idea? Use GitHub if you have an account — it lets others follow along and add details. Otherwise, email works just as well.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }

            Section("Report a Bug") {
                Button {
                    openURL(SupportContact.bugReportURL)
                } label: {
                    Label("Open a Bug Report on GitHub", systemImage: "ant")
                }
                Button {
                    if let url = SupportContact.mailURL(
                        subject: "NFC Forge Bug Report",
                        body: "What happened:\n\n\nWhat I expected:\n\n\nSteps to reproduce:\n1. \n\nTag type (if known):\n"
                    ) {
                        openURL(url)
                    }
                } label: {
                    Label("Email a Bug Report", systemImage: "envelope")
                }
            }

            Section("Request a Feature") {
                Button {
                    openURL(SupportContact.featureRequestURL)
                } label: {
                    Label("Suggest a Feature on GitHub", systemImage: "lightbulb")
                }
                Button {
                    if let url = SupportContact.mailURL(
                        subject: "NFC Forge Feature Request",
                        body: "What I'd like NFC Forge to do:\n\n\nWhy it would help:\n"
                    ) {
                        openURL(url)
                    }
                } label: {
                    Label("Email a Feature Idea", systemImage: "envelope")
                }
            }

            Section {
                Button {
                    openURL(SupportContact.issuesURL)
                } label: {
                    Label("Browse Existing Issues", systemImage: "list.bullet.rectangle")
                }
            } footer: {
                Text("Please don't include passwords, payment card data, or other private tag contents in public GitHub issues.")
            }
        }
        .navigationTitle("Bug or Feature Idea")
        .navigationBarTitleDisplayMode(.inline)
    }
}
