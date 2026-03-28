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
    @Published var deepOrbitSlideOffset: CGFloat = 0
    @Published var slideAppIndex: Int = -1
    @Published var returnSlideAppIndex: Int = -1
    @Published var returnSlideOffset: CGFloat = 0
    @Published var deepOrbitOpacity: CGFloat = 0

    var deepOrbitSlideAmount: CGFloat { CGFloat(settings.parentWedgeSlideDistance) }

    private var slideAnimationTimer: Timer?
    private var slideStartValue: CGFloat = 0
    private var slideTargetValue: CGFloat = 0
    private var slideStartTime: CFTimeInterval = 0
    private let slideAnimationDuration: CFTimeInterval = 0.25

    private var returnAnimationTimer: Timer?
    private var returnStartValue: CGFloat = 0
    private var returnStartTime: CFTimeInterval = 0

    private var opacityTimer: Timer?
    private var opacityStartValue: CGFloat = 0
    private var opacityTargetValue: CGFloat = 0
    private var opacityStartTime: CFTimeInterval = 0
    private let opacityDuration: CFTimeInterval = 0.12
    private var opacityCompletion: (() -> Void)?

    private var hoverTimer: Timer?
    private var hoveredIndex: Int = -1
    private var lastActiveApp: NSRunningApplication?
    private var cancelZoneTimer: Timer?
    private var cancelZoneArmed: Bool = false
    private var lastThumbnailPrefetchTime: CFTimeInterval = 0

    private var settings: OrbitSettings { OrbitSettings.shared }

    var showDebug: Bool { settings.showDebugOverlay }
    var primaryRadius: CGFloat { CGFloat(settings.primaryRadius) }
    var deepOrbitRadius: CGFloat { CGFloat(settings.primaryRadius) + segmentIconSize / 2 + 70 }
    var deepOrbitOuterRadius: CGFloat {
        let innerR = primaryRadius + segmentIconSize / 2 + 17
        let baseOuter = deepOrbitRadius + 130
        return innerR + (baseOuter - innerR) * CGFloat(settings.deepOrbitScale)
    }
    let deepOrbitSpread: Double = 0.7
    var segmentIconSize: CGFloat { CGFloat(settings.iconSize) }
    var centerDeadZone: CGFloat { CGFloat(settings.centerDeadZone) }
    var deepOrbitDeadZone: CGFloat { primaryRadius * 0.65 }
    var hoverDelay: TimeInterval { settings.hoverTimeout }

    var isInDeepOrbit: Bool {
        if case .deep = tier { return true }
        return false
    }

    var deepOrbitDisplayAppIndex: Int {
        if case .deep(let idx) = tier { return idx }
        if slideAppIndex >= 0 { return slideAppIndex }
        return 0
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
        deepOrbitSlideOffset = 0
        slideAppIndex = -1
        slideAnimationTimer?.invalidate()
        slideAnimationTimer = nil
        slideCompletion = nil
        returnSlideAppIndex = -1
        returnSlideOffset = 0
        returnAnimationTimer?.invalidate()
        returnAnimationTimer = nil
        deepOrbitOpacity = 0
        opacityTimer?.invalidate()
        opacityTimer = nil
        opacityCompletion = nil
        hoveredIndex = -1
        hoverTimer?.invalidate()
        stopCancelZoneTimer()

        lastActiveApp = NSWorkspace.shared.frontmostApplication
        prefetchThumbnailsIfNeeded()
    }

    func softRefresh() {
        let previousBundleID: String? = {
            guard selectedIndex >= 0, selectedIndex < apps.count else { return nil }
            return apps[selectedIndex].bundleIdentifier
        }()

        let newApps = WindowManager.shared.fetchActiveApps()
        apps = newApps

        if let bid = previousBundleID,
           let idx = newApps.firstIndex(where: { $0.bundleIdentifier == bid }) {
            selectedIndex = idx
            centerLabel = newApps[idx].name
        } else if selectedIndex >= newApps.count {
            selectedIndex = newApps.isEmpty ? -1 : 0
            centerLabel = newApps.isEmpty ? "" : newApps[0].name
        }

        if case .deep(let appIndex) = tier {
            if appIndex < newApps.count {
                deepOrbitWindows = newApps[appIndex].windows
            } else {
                tier = .primary
                deepOrbitWindows = []
                selectedWindowIndex = -1
            }
        }

        prefetchThumbnailsIfNeeded()
    }

    private func prefetchThumbnailsIfNeeded() {
        let now = CACurrentMediaTime()
        guard now - lastThumbnailPrefetchTime > 10 else { return }
        lastThumbnailPrefetchTime = now

        let windowsToCapture = apps
            .filter { $0.windows.count > 1 }
            .flatMap { $0.windows }
            .filter { windowThumbnails[$0.id] == nil }

        guard !windowsToCapture.isEmpty else { return }

        Task.detached { [weak self] in
            var captured: [CGWindowID: NSImage] = [:]
            for w in windowsToCapture {
                if let img = WindowManager.shared.captureWindowThumbnail(windowID: w.id) {
                    captured[w.id] = img
                }
            }
            let result = captured
            guard let target = self else { return }
            await MainActor.run {
                target.windowThumbnails.merge(result) { _, new in new }
            }
        }
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
            updateDeepOrbitSelection(normalizedAngle: normalized, distance: distance, appIndex: appIndex)
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

    private func updateDeepOrbitSelection(normalizedAngle: Double, distance: Double, appIndex: Int) {
        guard !deepOrbitWindows.isEmpty else { return }

        let primaryZoneInner = Double(centerDeadZone)
        let primaryZoneOuter = Double(primaryRadius + segmentIconSize / 2 + 5)
        let inPrimaryZone = distance >= primaryZoneInner && distance <= primaryZoneOuter

        if inPrimaryZone && settings.deepOrbitSwitchOnHover && !apps.isEmpty {
            let segmentAngle = (2.0 * Double.pi) / Double(apps.count)
            let offset = Double.pi / 2.0 + segmentAngle / 2.0
            let adjusted = normalizeAngle(normalizedAngle + offset)
            let hoveredApp = Int(adjusted / segmentAngle) % apps.count

            selectedIndex = hoveredApp
            centerLabel = apps[hoveredApp].name

            if hoveredApp != appIndex {
                if hoveredApp != hoveredIndex {
                    hoveredIndex = hoveredApp
                    hoverTimer?.invalidate()
                    hoverTimer = Timer.scheduledTimer(withTimeInterval: hoverDelay, repeats: false) { [weak self] _ in
                        Task { @MainActor in
                            guard let self else { return }
                            self.cancelDeepOrbit()
                            self.selectedIndex = hoveredApp
                            self.centerLabel = self.apps[hoveredApp].name
                            if self.apps[hoveredApp].windows.count > 1 {
                                self.enterDeepOrbit(for: hoveredApp)
                            }
                        }
                    }
                }
                return
            } else {
                cancelHoverTimer()
            }
        } else {
            cancelHoverTimer()
        }

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

        let timer = Timer(timeInterval: hoverDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.enterDeepOrbit(for: index)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        hoverTimer = timer
    }

    private func cancelHoverTimer() {
        hoverTimer?.invalidate()
        hoveredIndex = -1
    }

    private func startCancelZoneTimer() {
        guard !cancelZoneArmed else { return }
        cancelZoneArmed = true
        let timer = Timer(timeInterval: hoverDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.cancelDeepOrbit()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        cancelZoneTimer = timer
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

        deepOrbitOpacity = 0
        tier = .deep(appIndex: appIndex)
        deepOrbitWindows = app.windows
        selectedWindowIndex = -1

        if settings.animateParentWedge {
            if slideAppIndex >= 0 && slideAppIndex != appIndex && deepOrbitSlideOffset > 0 {
                returnSlideAppIndex = slideAppIndex
                returnSlideOffset = deepOrbitSlideOffset
                animateReturnSlide()
            }
            slideAnimationTimer?.invalidate()
            slideAnimationTimer = nil
            deepOrbitSlideOffset = 0
            slideAppIndex = appIndex
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.animateDeepOrbitOpacity(to: 1)
            if self.settings.animateParentWedge {
                self.animateSlideOffset(to: self.deepOrbitSlideAmount)
            }
        }

        let uncached = app.windows.filter { windowThumbnails[$0.id] == nil }
        if !uncached.isEmpty {
            Task.detached { [weak self] in
                var captured: [CGWindowID: NSImage] = [:]
                for w in uncached {
                    if let img = WindowManager.shared.captureWindowThumbnail(windowID: w.id) {
                        captured[w.id] = img
                    }
                }
                let result = captured
                guard let target = self else { return }
                await MainActor.run {
                    target.windowThumbnails.merge(result) { _, new in new }
                }
            }
        }
    }

    func cancelDeepOrbit() {
        guard case .deep(let appIndex) = tier else { return }
        selectedIndex = appIndex
        centerLabel = apps[appIndex].name
        tier = .primary
        if settings.animateParentWedge {
            slideAppIndex = appIndex
            animateSlideOffset(to: 0)
        } else {
            slideAppIndex = appIndex
        }
        animateDeepOrbitOpacity(to: 0) { [weak self] in
            guard let self else { return }
            if !self.settings.animateParentWedge {
                self.deepOrbitWindows = []
                self.slideAppIndex = -1
            }
        }
        selectedWindowIndex = -1
        hoveredIndex = -1
        cancelHoverTimer()
        stopCancelZoneTimer()
    }

    private var slideCompletion: (() -> Void)?

    private func animateSlideOffset(to target: CGFloat, completion: (() -> Void)? = nil) {
        slideStartValue = deepOrbitSlideOffset
        slideTargetValue = target
        slideStartTime = 0
        slideCompletion = completion
        slideAnimationTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self else { timer.invalidate(); return }
                if self.slideStartTime == 0 {
                    self.slideStartTime = CACurrentMediaTime()
                    return
                }
                let elapsed = CACurrentMediaTime() - self.slideStartTime
                let t = min(elapsed / self.slideAnimationDuration, 1.0)
                let eased = 1.0 - pow(1.0 - t, 3.0)
                self.deepOrbitSlideOffset = self.slideStartValue + CGFloat(eased) * (self.slideTargetValue - self.slideStartValue)
                if t >= 1.0 {
                    timer.invalidate()
                    self.slideAnimationTimer = nil
                    let cb = self.slideCompletion
                    self.slideCompletion = nil
                    if self.slideTargetValue == 0 {
                        self.slideAppIndex = -1
                        self.deepOrbitWindows = []
                    }
                    cb?()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        slideAnimationTimer = timer
    }

    private func animateReturnSlide() {
        returnStartValue = returnSlideOffset
        returnStartTime = 0
        returnAnimationTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self else { timer.invalidate(); return }
                if self.returnStartTime == 0 {
                    self.returnStartTime = CACurrentMediaTime()
                    return
                }
                let elapsed = CACurrentMediaTime() - self.returnStartTime
                let t = min(elapsed / self.slideAnimationDuration, 1.0)
                let eased = 1.0 - pow(1.0 - t, 3.0)
                self.returnSlideOffset = self.returnStartValue * CGFloat(1.0 - eased)
                if t >= 1.0 {
                    timer.invalidate()
                    self.returnAnimationTimer = nil
                    self.returnSlideAppIndex = -1
                    self.returnSlideOffset = 0
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        returnAnimationTimer = timer
    }

    private func animateDeepOrbitOpacity(to target: CGFloat, completion: (() -> Void)? = nil) {
        opacityStartValue = deepOrbitOpacity
        opacityTargetValue = target
        opacityStartTime = CACurrentMediaTime()
        opacityCompletion = completion
        opacityTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self else { timer.invalidate(); return }
                let elapsed = CACurrentMediaTime() - self.opacityStartTime
                let t = min(elapsed / self.opacityDuration, 1.0)
                let eased = 1.0 - pow(1.0 - t, 3.0)
                self.deepOrbitOpacity = self.opacityStartValue + CGFloat(eased) * (self.opacityTargetValue - self.opacityStartValue)
                if t >= 1.0 {
                    timer.invalidate()
                    self.opacityTimer = nil
                    self.opacityCompletion?()
                    self.opacityCompletion = nil
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        opacityTimer = timer
    }

    func returnSlideVector(appIndex: Int) -> CGPoint {
        guard apps.count > 0, returnSlideAppIndex == appIndex else { return .zero }
        let angle = angleForSegment(at: appIndex, total: apps.count)
        return CGPoint(
            x: returnSlideOffset * CGFloat(cos(angle)),
            y: returnSlideOffset * CGFloat(sin(angle))
        )
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

    func deepOrbitSlideVector(appIndex: Int) -> CGPoint {
        guard apps.count > 0 else { return .zero }
        let angle = angleForSegment(at: appIndex, total: apps.count)
        return CGPoint(
            x: deepOrbitSlideOffset * CGFloat(cos(angle)),
            y: deepOrbitSlideOffset * CGFloat(sin(angle))
        )
    }

    func deepOrbitTargetSlideVector(appIndex: Int) -> CGPoint {
        guard apps.count > 0, settings.animateParentWedge else { return .zero }
        let angle = angleForSegment(at: appIndex, total: apps.count)
        return CGPoint(
            x: deepOrbitSlideAmount * CGFloat(cos(angle)),
            y: deepOrbitSlideAmount * CGFloat(sin(angle))
        )
    }
}
