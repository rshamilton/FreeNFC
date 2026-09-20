import SwiftUI
import UIKit

/// Turns this iPhone into an NFC reader for a computer on the same Wi-Fi network. The phone runs
/// a tiny web server; the Mac opens the shown address in any browser, then reads and writes tags
/// through the phone. Every scan still uses the phone's NFC hardware and system sheet.
struct ComputerBridgeView: View {
    @StateObject private var controller = ComputerBridgeController()

    var body: some View {
        BridgeContentView(controller: controller, server: controller.server)
    }
}

private struct BridgeContentView: View {
    @ObservedObject var controller: ComputerBridgeController
    @ObservedObject var server: ComputerBridgeServer

    @EnvironmentObject private var nfc: NFCSessionManager
    @Environment(\.openURL) private var openURL
    @State private var copied = false

    var body: some View {
        List {
            statusSection
            troubleshootingSection
            connectSection
            controlsSection
            activitySection
            helpSection
        }
        .navigationTitle("Computer Reader")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { controller.attach(to: nfc) }
        .onChange(of: server.status) { _, status in
            if case .failed = status { controller.isEnabled = false }
        }
        .overlay(alignment: .bottom) {
            if copied {
                StatusBanner(kind: .success, message: "Address copied to clipboard")
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(for: .seconds(1.4))
                        copied = false
                    }
            }
        }
        .animation(.default, value: copied)
    }

    // MARK: - Sections

    private var statusSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: controller.statusSymbol)
                    .font(.title2)
                    .foregroundStyle(statusColor)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(controller.statusTitle)
                        .font(.headline)
                    Text(controller.statusDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Toggle("", isOn: Binding(
                    get: { controller.isEnabled },
                    set: {
                        controller.setEnabled($0)
                        FeedbackManager.shared.light()
                    }
                ))
                .labelsHidden()
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private var troubleshootingSection: some View {
        switch server.status {
        case .waitingForPermission, .failed:
            Section {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                } label: {
                    Label("Open Free NFC Settings", systemImage: "gear")
                }
            } footer: {
                Text("iOS asks for Local Network permission the first time the reader starts. If you tapped Don't Allow, turn “Local Network” back on here, then switch the reader off and on again.")
            }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var connectSection: some View {
        if server.isRunning {
            Section {
                if let url = controller.browserURL {
                    VStack(alignment: .center, spacing: 14) {
                        QRCodeView(urlString: url, size: 150)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 6)

                        Button {
                            Clipboard.copy(url)
                            copied = true
                        } label: {
                            HStack {
                                Text(url)
                                    .font(.system(.body, design: .monospaced).weight(.semibold))
                                    .foregroundStyle(.tint)
                                Spacer()
                                Image(systemName: "doc.on.clipboard")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } else {
                    Label("Connect the iPhone to Wi-Fi to get an address.", systemImage: "wifi.exclamationmark")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            } header: {
                Text("Connect From Your Computer")
            } footer: {
                Text("Scan the QR code or type the address into your computer's browser (Safari, Chrome, Firefox).")
            }
        }
    }

    @ViewBuilder
    private var controlsSection: some View {
        if server.isRunning {
            Section {
                PrimaryActionRow(title: "Scan a Tag Now", isBusy: nfc.isScanning) {
                    controller.handleScanRequest()
                }
            } footer: {
                Text("You can also trigger scans and writes directly from the web browser dashboard.")
            }
        }
    }

    @ViewBuilder
    private var activitySection: some View {
        if !server.log.isEmpty {
            Section("Live Activity Log") {
                ForEach(server.log) { entry in
                    HStack(alignment: .top, spacing: 10) {
                        Text(entry.date, style: .time)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text(entry.message)
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var helpSection: some View {
        Section {
            Text("Your Mac and iPhone must be connected to the same local Wi-Fi network. Keep this screen open while using the bridge — scans require iPhone NFC hardware in the foreground.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var statusColor: Color {
        switch server.status {
        case .running: return .green
        case .starting, .waitingForPermission: return .orange
        case .failed: return .red
        case .off: return .secondary
        }
    }
}
