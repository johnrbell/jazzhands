import AppKit
import SwiftUI
import CoreGraphics

@MainActor
final class OverlayWindowController {
    private var window: NSWindow?
    private var viewModel = OrbitViewModel()
    private var mouseMonitor: Any?

    private var screenCenter: CGPoint = .zero
    private var accumulatedDelta: CGPoint = .zero
    private var ignoreEventsUntil: TimeInterval = 0
    private var maxCursorRadius: CGFloat {
        CGFloat(OrbitSettings.shared.primaryRadius) + 220
    }

    func showOrbit() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame

        viewModel.refresh()

        if window == nil {
            let hostingView = NSHostingView(rootView: OrbitView(viewModel: viewModel))
            hostingView.frame = CGRect(origin: .zero, size: frame.size)

            let w = NSWindow(
                contentRect: frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            w.level = .floating
            w.isOpaque = false
            w.backgroundColor = .clear
            w.hasShadow = false
            w.ignoresMouseEvents = false
            w.contentView = hostingView
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            window = w
        }

        window?.setFrame(frame, display: true)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeFirstResponder(window?.contentView)

        screenCenter = CGPoint(x: frame.midX, y: frame.midY)
        accumulatedDelta = .zero
        viewModel.isVisible = true

        lockMouse()
        ignoreEventsUntil = ProcessInfo.processInfo.systemUptime + 0.05
        startMouseTracking()
    }

    func hideOrbit() {
        viewModel.isVisible = false
        stopMouseTracking()
        unlockMouse()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.window?.orderOut(nil)
        }
    }

    func confirmSelection() {
        viewModel.confirmSelection()
    }

    func switchToLastApp() {
        viewModel.switchToLastApp()
    }

    // MARK: - Mouse Lock

    private func lockMouse() {
        NSCursor.hide()
        CGDisplayHideCursor(CGMainDisplayID())
        warpMouseToCenter()
        CGAssociateMouseAndMouseCursorPosition(0)
    }

    private func unlockMouse() {
        CGAssociateMouseAndMouseCursorPosition(1)
        CGDisplayShowCursor(CGMainDisplayID())
        NSCursor.unhide()
    }

    private func warpMouseToCenter() {
        guard let screen = NSScreen.main else { return }
        let flippedY = screen.frame.height - screenCenter.y
        CGWarpMouseCursorPosition(CGPoint(x: screenCenter.x, y: flippedY))
    }

    // MARK: - Mouse Tracking

    private func handleDelta(dx: CGFloat, dy: CGFloat) {
        if ProcessInfo.processInfo.systemUptime < ignoreEventsUntil { return }
        if viewModel.shouldResetCursor {
            accumulatedDelta = .zero
            viewModel.shouldResetCursor = false
        }
        accumulatedDelta.x += dx
        accumulatedDelta.y += dy
        clampDelta()
        viewModel.updateMouse(dx: accumulatedDelta.x, dy: accumulatedDelta.y)
    }

    private func clampDelta() {
        let mag = sqrt(accumulatedDelta.x * accumulatedDelta.x + accumulatedDelta.y * accumulatedDelta.y)
        if mag > maxCursorRadius {
            let scale = maxCursorRadius / mag
            accumulatedDelta.x *= scale
            accumulatedDelta.y *= scale
        }
    }

    private var clickMonitor: Any?
    private var localMoveMonitor: Any?
    private var lastEventTimestamp: TimeInterval = 0

    private nonisolated func startMouseTracking() {
        let global = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            guard let self else { return }
            let dx = event.deltaX
            let dy = event.deltaY
            let ts = event.timestamp
            Task { @MainActor in
                self.deduplicatedDelta(dx: dx, dy: dy, timestamp: ts)
            }
        }

        let local = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            guard let self else { return event }
            let dx = event.deltaX
            let dy = event.deltaY
            let ts = event.timestamp
            Task { @MainActor in
                self.deduplicatedDelta(dx: dx, dy: dy, timestamp: ts)
            }
            return event
        }

        let click = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            guard let self else { return event }
            Task { @MainActor in
                self.handleClick(event)
            }
            return event
        }

        Task { @MainActor in
            self.mouseMonitor = global
            self.localMoveMonitor = local
            self.clickMonitor = click
        }
    }

    private func deduplicatedDelta(dx: CGFloat, dy: CGFloat, timestamp: TimeInterval) {
        guard timestamp != lastEventTimestamp else { return }
        lastEventTimestamp = timestamp
        handleDelta(dx: dx, dy: dy)
    }

    private func handleClick(_ event: NSEvent) {
        guard viewModel.isInDeepOrbit else { return }
        guard let win = window else { return }

        let loc = event.locationInWindow
        let center = CGPoint(x: win.frame.width / 2, y: win.frame.height / 2)
        let dx = loc.x - center.x
        let dy = loc.y - center.y
        let dist = sqrt(dx * dx + dy * dy)

        if dist < 40 {
            viewModel.cancelDeepOrbit()
        }
    }

    private func stopMouseTracking() {
        if let m = mouseMonitor { NSEvent.removeMonitor(m); mouseMonitor = nil }
        if let m = localMoveMonitor { NSEvent.removeMonitor(m); localMoveMonitor = nil }
        if let m = clickMonitor { NSEvent.removeMonitor(m); clickMonitor = nil }
        lastEventTimestamp = 0
    }
}
