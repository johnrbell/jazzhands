import SwiftUI
import AppKit

struct OnboardingView: View {
    @State private var accessibilityGranted = AXIsProcessTrusted()
    @State private var screenCaptureGranted = CGPreflightScreenCaptureAccess()
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var allGranted: Bool { accessibilityGranted && screenCaptureGranted }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            permissionsList
            Divider()
            footer
        }
        .frame(width: 480)
        .onReceive(timer) { _ in
            accessibilityGranted = AXIsProcessTrusted()
            screenCaptureGranted = CGPreflightScreenCaptureAccess()
            if allGranted {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NSApp.windows.first { $0.title == "JazzHands Setup" }?.close()
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("Welcome to JazzHands")
                .font(.title.bold())
            Text("JazzHands needs two permissions to work.\nGrant them below, then you're all set.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 32)
    }

    private var permissionsList: some View {
        VStack(spacing: 16) {
            permissionRow(
                icon: "hand.raised.fill",
                title: "Accessibility",
                description: "Required to detect hotkeys and manage windows globally.",
                granted: accessibilityGranted,
                action: {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
            )
            permissionRow(
                icon: "record.circle",
                title: "Screen Recording",
                description: "Required to capture window thumbnails for the switcher.",
                granted: screenCaptureGranted,
                action: {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
                }
            )
        }
        .padding(24)
    }

    private func permissionRow(icon: String, title: String, description: String,
                               granted: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(granted ? .green : .secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title).font(.headline)
                    if granted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.subheadline)
                    }
                }
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !granted {
                Button("Grant Access") { action() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            } else {
                Text("Granted")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
    }

    private var footer: some View {
        HStack {
            if allGranted {
                Text("All permissions granted — you're ready to go!")
                    .font(.callout)
                    .foregroundColor(.green)
            } else {
                Text("JazzHands will start automatically once permissions are granted.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(allGranted ? "Done" : "Skip for Now") {
                NSApp.windows.first { $0.title == "JazzHands Setup" }?.close()
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}
