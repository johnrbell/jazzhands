import SwiftUI
import Combine

enum OrbitTier {
    case primary
    case deep(appIndex: Int)
}

@MainActor
final class OrbitViewModel: ObservableObject {
    @Published var apps: [OrbitApp] = []
    @Published var selectedIndex: Int = -1
    @Published var selectedWindowIndex: Int = -1
    @Published var tier: OrbitTier = .primary
    @Published var mouseAngle: Double = 0
    @Published var mouseDistance: Double = 0
    @Published var isVisible: Bool = false
    @Published var centerLabel: String = ""
    @Published var deepOrbitWindows: [OrbitWindow] = []
    @Published var windowThumbnails: [CGWindowID: NSImage] = [:]
    @Published var debugCursorPos: CGPoint = .zero
    @Published var shouldResetCursor: Bool = false

    private var hoverTimer: Timer?
    private var hoveredIndex: Int = -1
    private var lastActiveApp: NSRunningApplication?
    private var cancelZoneTimer: Timer?
    private var cancelZoneArmed: Bool = false

    private var settings: OrbitSettings { OrbitSettings.shared }

    var showDebug: Bool { settings.showDebugOverlay }
    var primaryRadius: CGFloat { CGFloat(settings.primaryRadius) }
    var deepOrbitRadius: CGFloat { CGFloat(settings.primaryRadius) + segmentIconSize / 2 + 60 }
    var deepOrbitOuterRadius: CGFloat { deepOrbitRadius + 130 }
    let deepOrbitSpread: Double = 0.7
    var segmentIconSize: CGFloat { CGFloat(settings.iconSize) }
    var centerDeadZone: CGFloat { CGFloat(settings.centerDeadZone) }
    var deepOrbitDeadZone: CGFloat { primaryRadius * 0.65 }
    var hoverDelay: TimeInterval { settings.hoverTimeout }

    var isInDeepOrbit: Bool {
        if case .deep = tier { return true }
        return false
    }

    var isCancelHovered: Bool {
        isInDeepOrbit && mouseDistance <= Double(deepOrbitDeadZone)
    }

    func refresh() {
        apps = WindowManager.shared.fetchActiveApps()
        selectedIndex = -1
        selectedWindowIndex = -1
        tier = .primary
        centerLabel = ""
        deepOrbitWindows = []
        windowThumbnails = [:]
        hoveredIndex = -1
        hoverTimer?.invalidate()
        stopCancelZoneTimer()

        lastActiveApp = NSWorkspace.shared.frontmostApplication
    }

    func updateMouse(dx: CGFloat, dy: CGFloat) {
        debugCursorPos = CGPoint(x: dx, y: dy)
        let distance = Double(sqrt(dx * dx + dy * dy))
        mouseDistance = distance

        if case .deep = tier {
            guard distance > Double(deepOrbitDeadZone) else {
                selectedWindowIndex = -1
                centerLabel = ""
                startCancelZoneTimer()
                return
            }
            stopCancelZoneTimer()
        } else {
            guard distance > Double(centerDeadZone) else {
                selectedIndex = -1
                selectedWindowIndex = -1
                centerLabel = ""
                cancelHoverTimer()
                return
            }
        }

        let angle = atan2(Double(dy), Double(dx))
        let normalized = normalizeAngle(angle)
        mouseAngle = normalized

        switch tier {
        case .primary:
            updatePrimarySelection(normalizedAngle: normalized, distance: distance)
        case .deep(let appIndex):
            updateDeepOrbitSelection(normalizedAngle: normalized, appIndex: appIndex)
        }
    }

    private func updatePrimarySelection(normalizedAngle: Double, distance: Double) {
        guard !apps.isEmpty else { return }
        let segmentAngle = (2.0 * Double.pi) / Double(apps.count)
        let offset = Double.pi / 2.0 + segmentAngle / 2.0
        let adjusted = normalizeAngle(normalizedAngle + offset)
        let index = Int(adjusted / segmentAngle) % apps.count

        if index != selectedIndex {
            selectedIndex = index
            centerLabel = apps[index].name
        }

        if index != hoveredIndex {
            hoveredIndex = index
            startHoverTimer(for: index)
        }
    }

    private func updateDeepOrbitSelection(normalizedAngle: Double, appIndex: Int) {
        guard !deepOrbitWindows.isEmpty else { return }
        let count = deepOrbitWindows.count

        var bestIndex = 0
        var bestDist = Double.greatestFiniteMagnitude

        for i in 0..<count {
            let winAngle = normalizeAngle(deepOrbitAngle(windowIndex: i, appIndex: appIndex))
            var diff = normalizedAngle - winAngle
            if diff > Double.pi { diff -= 2.0 * Double.pi }
            if diff < -Double.pi { diff += 2.0 * Double.pi }
            let absDiff = abs(diff)
            if absDiff < bestDist {
                bestDist = absDiff
                bestIndex = i
            }
        }

        selectedWindowIndex = bestIndex
        centerLabel = deepOrbitWindows[bestIndex].title.isEmpty
            ? apps[appIndex].name
            : deepOrbitWindows[bestIndex].title
    }

    private func normalizeAngle(_ angle: Double) -> Double {
        var a = angle
        while a < 0 { a += 2.0 * Double.pi }
        while a >= 2.0 * Double.pi { a -= 2.0 * Double.pi }
        return a
    }

    // MARK: - Hover / Deep Orbit

    private func startHoverTimer(for index: Int) {
        hoverTimer?.invalidate()
        guard settings.deepOrbitEnabled,
              index >= 0, index < apps.count, apps[index].windows.count > 1 else { return }

        hoverTimer = Timer.scheduledTimer(withTimeInterval: hoverDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.enterDeepOrbit(for: index)
            }
        }
    }

    private func cancelHoverTimer() {
        hoverTimer?.invalidate()
        hoveredIndex = -1
    }

    private func startCancelZoneTimer() {
        guard !cancelZoneArmed else { return }
        cancelZoneArmed = true
        cancelZoneTimer = Timer.scheduledTimer(withTimeInterval: hoverDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.cancelDeepOrbit()
            }
        }
    }

    private func stopCancelZoneTimer() {
        cancelZoneTimer?.invalidate()
        cancelZoneTimer = nil
        cancelZoneArmed = false
    }

    private func enterDeepOrbit(for appIndex: Int) {
        guard appIndex >= 0, appIndex < apps.count else { return }
        let app = apps[appIndex]
        guard app.windows.count > 1 else { return }

        tier = .deep(appIndex: appIndex)
        deepOrbitWindows = app.windows
        selectedWindowIndex = -1
        for window in app.windows {
            if windowThumbnails[window.id] == nil {
                windowThumbnails[window.id] = WindowManager.shared.captureWindowThumbnail(windowID: window.id)
            }
        }
    }

    func cancelDeepOrbit() {
        guard case .deep(let appIndex) = tier else { return }
        selectedIndex = appIndex
        centerLabel = apps[appIndex].name
        tier = .primary
        deepOrbitWindows = []
        selectedWindowIndex = -1
        hoveredIndex = -1
        cancelHoverTimer()
        stopCancelZoneTimer()
    }

    // MARK: - Tab Cycling

    func cycleSelectionCounterClockwise() {
        guard !apps.isEmpty, case .primary = tier else { return }
        if selectedIndex < 0 {
            selectedIndex = 0
        } else {
            selectedIndex = (selectedIndex + 1) % apps.count
        }
        centerLabel = apps[selectedIndex].name
        hoveredIndex = -1
        cancelHoverTimer()
    }

    func cycleSelectionClockwise() {
        guard !apps.isEmpty, case .primary = tier else { return }
        if selectedIndex < 0 {
            selectedIndex = apps.count - 1
        } else {
            selectedIndex = (selectedIndex - 1 + apps.count) % apps.count
        }
        centerLabel = apps[selectedIndex].name
        hoveredIndex = -1
        cancelHoverTimer()
    }

    // MARK: - Selection

    func confirmSelection() {
        switch tier {
        case .primary:
            guard selectedIndex >= 0, selectedIndex < apps.count else {
                log("confirmSelection PRIMARY: no selection (idx=\(selectedIndex))")
                return
            }
            log("confirmSelection PRIMARY: \(apps[selectedIndex].name)")
            WindowManager.shared.activateApp(apps[selectedIndex])
        case .deep(let appIndex):
            log("confirmSelection DEEP: windowIdx=\(selectedWindowIndex) count=\(deepOrbitWindows.count) distance=\(mouseDistance) deadZone=\(deepOrbitDeadZone)")
            if selectedWindowIndex >= 0, selectedWindowIndex < deepOrbitWindows.count {
                let w = deepOrbitWindows[selectedWindowIndex]
                log("  activating window: '\(w.title)' id=\(w.id)")
                WindowManager.shared.activateWindow(w)
            } else {
                log("  no window selected, activating app")
                if appIndex >= 0, appIndex < apps.count {
                    WindowManager.shared.activateApp(apps[appIndex])
                }
            }
        }
    }

    private func log(_ msg: String) {
        let entry = "[\(Date())] VM: \(msg)\n"
        let path = "/tmp/orbit.log"
        if let handle = FileHandle(forWritingAtPath: path) {
            handle.seekToEndOfFile()
            handle.write(entry.data(using: .utf8)!)
            handle.closeFile()
        }
    }

    func switchToLastApp() {
        guard let lastApp = lastActiveApp else { return }
        let target = apps.first { $0.runningApp != lastApp } ?? apps.first
        if let target = target {
            WindowManager.shared.activateApp(target)
        }
    }

    // MARK: - Geometry Helpers

    func angleForSegment(at index: Int, total: Int) -> Double {
        let segmentAngle = (2.0 * Double.pi) / Double(total)
        return segmentAngle * Double(index) - Double.pi / 2.0
    }

    func positionForSegment(at index: Int, total: Int, radius: CGFloat) -> CGPoint {
        let angle = angleForSegment(at: index, total: total)
        return CGPoint(
            x: radius * CGFloat(cos(angle)),
            y: radius * CGFloat(sin(angle))
        )
    }

    func deepOrbitAngle(windowIndex: Int, appIndex: Int) -> Double {
        let parentAngle = angleForSegment(at: appIndex, total: apps.count)
        let count = deepOrbitWindows.count
        let totalSpread = deepOrbitSpread * Double(count - 1)
        let startAngle = parentAngle - totalSpread / 2.0
        return startAngle + deepOrbitSpread * Double(windowIndex)
    }

    func deepOrbitPosition(windowIndex: Int, appIndex: Int) -> CGPoint {
        let angle = deepOrbitAngle(windowIndex: windowIndex, appIndex: appIndex)
        return CGPoint(
            x: deepOrbitRadius * CGFloat(cos(angle)),
            y: deepOrbitRadius * CGFloat(sin(angle))
        )
    }
}
