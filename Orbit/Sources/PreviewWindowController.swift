import AppKit
import SwiftUI
import Combine

@MainActor
final class PreviewLockState: ObservableObject {
    @Published var isLocked: Bool = false
}

@MainActor
final class PreviewWindowController {
    private var window: NSWindow?
    private let viewModel = OrbitViewModel()
    private let lockState = PreviewLockState()
    private var refreshTimer: Timer?
    private var settingsCancellable: AnyCancellable?
    private var trackingView: PreviewTrackingView?
    private var moveObserver: Any?
    private var offset: CGPoint?

    func showPreview(relativeTo settingsWindow: NSWindow?) {
        viewModel.refresh()
        viewModel.isVisible = true

        if window == nil {
            let size = CGFloat(700)
            let contentRect = NSRect(x: 0, y: 0, width: size, height: size)

            let wallpaper = desktopWallpaperImage(size: CGSize(width: size, height: size))
            let previewContent = ZStack {
                if let wallpaper {
                    Image(nsImage: wallpaper)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipped()
                }
                OrbitView(viewModel: viewModel)
                PreviewOverlayView(lockState: lockState)
            }
            let hosting = NSHostingView(rootView: previewContent)
            hosting.translatesAutoresizingMaskIntoConstraints = false

            let tracker = PreviewTrackingView(frame: contentRect)
            tracker.lockState = lockState
            tracker.onMouseMoved = { [weak self] location, viewSize in
                let cx = location.x - viewSize.width / 2
                let cy = -(location.y - viewSize.height / 2)
                self?.viewModel.updateMouse(dx: cx, dy: cy)
            }
            tracker.onMouseExited = { [weak self] in
                self?.viewModel.updateMouse(dx: 0, dy: 0)
            }
            tracker.autoresizingMask = [.width, .height]
            tracker.addSubview(hosting)
            NSLayoutConstraint.activate([
                hosting.leadingAnchor.constraint(equalTo: tracker.leadingAnchor),
                hosting.trailingAnchor.constraint(equalTo: tracker.trailingAnchor),
                hosting.topAnchor.constraint(equalTo: tracker.topAnchor),
                hosting.bottomAnchor.constraint(equalTo: tracker.bottomAnchor),
            ])
            trackingView = tracker

            let w = NSWindow(
                contentRect: contentRect,
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            w.title = "Preview"
            w.contentView = tracker
            w.isReleasedWhenClosed = false
            w.backgroundColor = .black
            w.setFrameAutosaveName("PreviewWindow")
            w.makeFirstResponder(tracker)
            window = w
        }

        if let sw = settingsWindow {
            if !window!.setFrameUsingName("PreviewWindow") {
                let sf = sw.frame
                let previewFrame = window!.frame
                let x = sf.minX - previewFrame.width - 12
                let y = sf.midY - previewFrame.height / 2
                window?.setFrameOrigin(NSPoint(x: x, y: y))
            }
            sw.addChildWindow(window!, ordered: .above)
        } else {
            if !window!.setFrameUsingName("PreviewWindow") {
                window?.center()
            }
        }

        window?.orderFront(nil)

        if let sw = settingsWindow, let pw = window {
            offset = CGPoint(
                x: pw.frame.origin.x - sw.frame.origin.x,
                y: pw.frame.origin.y - sw.frame.origin.y
            )
            observeSettingsMove(sw)
        }

        startRefreshTimer()
        subscribeToSettings()
    }

    private func observeSettingsMove(_ settingsWindow: NSWindow) {
        if let obs = moveObserver { NotificationCenter.default.removeObserver(obs) }
        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: settingsWindow,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                guard let self, let sw = notification.object as? NSWindow,
                      let pw = self.window, let off = self.offset else { return }
                let newOrigin = NSPoint(
                    x: sw.frame.origin.x + off.x,
                    y: sw.frame.origin.y + off.y
                )
                pw.setFrameOrigin(newOrigin)
            }
        }
    }

    func hidePreview() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        settingsCancellable?.cancel()
        settingsCancellable = nil
        if let obs = moveObserver { NotificationCenter.default.removeObserver(obs) }
        moveObserver = nil
        if let w = window, let parent = w.parent {
            parent.removeChildWindow(w)
        }
        window?.orderOut(nil)
    }

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.viewModel.softRefresh()
            }
        }
    }

    private func desktopWallpaperImage(size: CGSize) -> NSImage? {
        guard let screen = NSScreen.main,
              let url = NSWorkspace.shared.desktopImageURL(for: screen),
              let image = NSImage(contentsOf: url) else { return nil }
        let result = NSImage(size: size)
        result.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy, fraction: 1.0)
        result.unlockFocus()
        return result
    }

    private func subscribeToSettings() {
        settingsCancellable = OrbitSettings.shared.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.viewModel.objectWillChange.send()
                self.viewModel.softRefresh()
            }
        }
    }
}

// MARK: - Lock Overlay

private struct PreviewOverlayView: View {
    @ObservedObject var lockState: PreviewLockState

    var body: some View {
        ZStack {
            if lockState.isLocked {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            lockState.isLocked = false
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "lock.open.fill")
                                    .font(.system(size: 11, weight: .medium))
                                Text("Unlock")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                    }
                    Spacer()
                }
            }

            VStack {
                Spacer()
                Text(lockState.isLocked
                     ? "Interaction locked — press Space to unlock"
                     : "Press Space to lock interaction")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.4))
                    .cornerRadius(4)
                    .padding(.bottom, 6)
            }
        }
        .allowsHitTesting(lockState.isLocked)
        .animation(.easeOut(duration: 0.15), value: lockState.isLocked)
    }
}

// MARK: - Tracking View

private class PreviewTrackingView: NSView {
    var onMouseMoved: ((NSPoint, NSSize) -> Void)?
    var onMouseExited: (() -> Void)?
    var lockState: PreviewLockState?
    private var area: NSTrackingArea?

    override var acceptsFirstResponder: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = area { removeTrackingArea(existing) }
        let newArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(newArea)
        area = newArea
    }

    override func mouseMoved(with event: NSEvent) {
        if lockState?.isLocked == true { return }
        let loc = convert(event.locationInWindow, from: nil)
        onMouseMoved?(loc, bounds.size)
    }

    override func mouseExited(with event: NSEvent) {
        if lockState?.isLocked == true { return }
        onMouseExited?()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 49 {
            MainActor.assumeIsolated {
                lockState?.isLocked.toggle()
            }
        } else {
            super.keyDown(with: event)
        }
    }
}
