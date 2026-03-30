import SwiftUI
import Combine

enum JazzHandsTier {
    case primary
    case deep(appIndex: Int)
}

@MainActor
final class JazzHandsViewModel: ObservableObject {
    @Published var apps: [JazzHandsApp] = []
    @Published var selectedIndex: Int = -1
    @Published var selectedWindowIndex: Int = -1
    @Published var tier: JazzHandsTier = .primary
    @Published var mouseAngle: Double = 0
    @Published var mouseDistance: Double = 0
    @Published var isVisible: Bool = false
    @Published var centerLabel: String = ""
    @Published var deepJazzHandsWindows: [JazzHandsWindow] = []
    @Published var windowThumbnails: [CGWindowID: NSImage] = [:]
    @Published var debugCursorPos: CGPoint = .zero
    @Published var shouldResetCursor: Bool = false
    @Published var deepJazzHandsSlideOffset: CGFloat = 0
    @Published var slideAppIndex: Int = -1
    @Published var returnSlideAppIndex: Int = -1
    @Published var returnSlideOffset: CGFloat = 0
    @Published var deepJazzHandsOpacity: CGFloat = 0

    var deepJazzHandsSlideAmount: CGFloat { CGFloat(settings.parentWedgeSlideDistance) }

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
    private var lastThumbnailPrefetchTime: CFTimeInterval = 0

    private var settings: JazzHandsSettings { JazzHandsSettings.shared }

    var showDebug: Bool { settings.showDebugOverlay }
    var primaryRadius: CGFloat { CGFloat(settings.primaryRadius) }
    var deepJazzHandsRadius: CGFloat { CGFloat(settings.primaryRadius) + segmentIconSize / 2 + 70 }
    var deepJazzHandsOuterRadius: CGFloat {
        let innerR = primaryRadius + segmentIconSize / 2 + 17
        let baseOuter = deepJazzHandsRadius + 130
        return innerR + (baseOuter - innerR) * CGFloat(settings.deepJazzHandsScale)
    }
    var deepJazzHandsSpread: Double { 0.7 * settings.deepJazzHandsScale }
    var segmentIconSize: CGFloat { CGFloat(settings.iconSize) }
    var centerDeadZone: CGFloat { CGFloat(settings.centerDeadZone) }
    var deepJazzHandsDeadZone: CGFloat { primaryRadius * 0.65 }
    var hoverDelay: TimeInterval { settings.hoverTimeout }

    var isInDeepJazzHands: Bool {
        if case .deep = tier { return true }
        return false
    }

    var deepJazzHandsDisplayAppIndex: Int {
        if case .deep(let idx) = tier { return idx }
        if slideAppIndex >= 0 { return slideAppIndex }
        return 0
    }

    

    func refresh() {
        apps = WindowManager.shared.fetchActiveApps()
        selectedIndex = -1
        selectedWindowIndex = -1
        tier = .primary
        centerLabel = ""
        deepJazzHandsWindows = []
        windowThumbnails = [:]
        deepJazzHandsSlideOffset = 0
        slideAppIndex = -1
        slideAnimationTimer?.invalidate()
        slideAnimationTimer = nil
        slideCompletion = nil
        returnSlideAppIndex = -1
        returnSlideOffset = 0
        returnAnimationTimer?.invalidate()
        returnAnimationTimer = nil
        deepJazzHandsOpacity = 0
        opacityTimer?.invalidate()
        opacityTimer = nil
        opacityCompletion = nil
        hoveredIndex = -1
        hoverTimer?.invalidate()

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
                deepJazzHandsWindows = newApps[appIndex].windows
            } else {
                tier = .primary
                deepJazzHandsWindows = []
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
            guard distance > Double(deepJazzHandsDeadZone) else {
                cancelDeepJazzHands()
                return
            }
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
            updateDeepJazzHandsSelection(normalizedAngle: normalized, distance: distance, appIndex: appIndex)
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

    private func updateDeepJazzHandsSelection(normalizedAngle: Double, distance: Double, appIndex: Int) {
        guard !deepJazzHandsWindows.isEmpty else { return }

        let primaryZoneInner = Double(centerDeadZone)
        let primaryZoneOuter = Double(primaryRadius + segmentIconSize / 2 + 5)
        let inPrimaryZone = distance >= primaryZoneInner && distance <= primaryZoneOuter

        if inPrimaryZone && settings.deepJazzHandsSwitchOnHover && !apps.isEmpty {
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
                            self.cancelDeepJazzHands()
                            self.selectedIndex = hoveredApp
                            self.centerLabel = self.apps[hoveredApp].name
                            if self.apps[hoveredApp].windows.count > 1 {
                                self.enterDeepJazzHands(for: hoveredApp)
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

        let count = deepJazzHandsWindows.count
        var bestIndex = 0
        var bestDist = Double.greatestFiniteMagnitude

        for i in 0..<count {
            let winAngle = normalizeAngle(deepJazzHandsAngle(windowIndex: i, appIndex: appIndex))
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
        centerLabel = deepJazzHandsWindows[bestIndex].title.isEmpty
            ? apps[appIndex].name
            : deepJazzHandsWindows[bestIndex].title
    }

    private func normalizeAngle(_ angle: Double) -> Double {
        var a = angle
        while a < 0 { a += 2.0 * Double.pi }
        while a >= 2.0 * Double.pi { a -= 2.0 * Double.pi }
        return a
    }

    // MARK: - Hover / Deep JazzHands

    private func startHoverTimer(for index: Int) {
        hoverTimer?.invalidate()
        guard settings.deepJazzHandsEnabled,
              index >= 0, index < apps.count, apps[index].windows.count > 1 else { return }

        let timer = Timer(timeInterval: hoverDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.enterDeepJazzHands(for: index)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        hoverTimer = timer
    }

    private func cancelHoverTimer() {
        hoverTimer?.invalidate()
        hoveredIndex = -1
    }

    

    private func enterDeepJazzHands(for appIndex: Int) {
        guard appIndex >= 0, appIndex < apps.count else { return }
        let app = apps[appIndex]
        guard app.windows.count > 1 else { return }

        deepJazzHandsOpacity = 0
        tier = .deep(appIndex: appIndex)
        deepJazzHandsWindows = app.windows
        selectedWindowIndex = -1

        if settings.animateParentWedge {
            if slideAppIndex >= 0 && slideAppIndex != appIndex && deepJazzHandsSlideOffset > 0 {
                returnSlideAppIndex = slideAppIndex
                returnSlideOffset = deepJazzHandsSlideOffset
                animateReturnSlide()
            }
            slideAnimationTimer?.invalidate()
            slideAnimationTimer = nil
            deepJazzHandsSlideOffset = 0
            slideAppIndex = appIndex
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.animateDeepJazzHandsOpacity(to: 1)
            if self.settings.animateParentWedge {
                self.animateSlideOffset(to: self.deepJazzHandsSlideAmount)
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

    func cancelDeepJazzHands() {
        guard case .deep(let appIndex) = tier else { return }
        selectedIndex = -1
        centerLabel = ""
        tier = .primary
        if settings.animateParentWedge {
            slideAppIndex = appIndex
            animateSlideOffset(to: 0)
        } else {
            slideAppIndex = appIndex
        }
        animateDeepJazzHandsOpacity(to: 0) { [weak self] in
            guard let self else { return }
            if !self.settings.animateParentWedge {
                self.deepJazzHandsWindows = []
                self.slideAppIndex = -1
            }
        }
        selectedWindowIndex = -1
        hoveredIndex = -1
        cancelHoverTimer()
    }

    private var slideCompletion: (() -> Void)?

    private func animateSlideOffset(to target: CGFloat, completion: (() -> Void)? = nil) {
        slideStartValue = deepJazzHandsSlideOffset
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
                self.deepJazzHandsSlideOffset = self.slideStartValue + CGFloat(eased) * (self.slideTargetValue - self.slideStartValue)
                if t >= 1.0 {
                    timer.invalidate()
                    self.slideAnimationTimer = nil
                    let cb = self.slideCompletion
                    self.slideCompletion = nil
                    if self.slideTargetValue == 0 {
                        self.slideAppIndex = -1
                        self.deepJazzHandsWindows = []
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

    private func animateDeepJazzHandsOpacity(to target: CGFloat, completion: (() -> Void)? = nil) {
        opacityStartValue = deepJazzHandsOpacity
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
                self.deepJazzHandsOpacity = self.opacityStartValue + CGFloat(eased) * (self.opacityTargetValue - self.opacityStartValue)
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
            log("confirmSelection DEEP: windowIdx=\(selectedWindowIndex) count=\(deepJazzHandsWindows.count) distance=\(mouseDistance) deadZone=\(deepJazzHandsDeadZone)")
            if selectedWindowIndex >= 0, selectedWindowIndex < deepJazzHandsWindows.count {
                let w = deepJazzHandsWindows[selectedWindowIndex]
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
        let path = "/tmp/jazzHands.log"
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

    func deepJazzHandsAngle(windowIndex: Int, appIndex: Int) -> Double {
        let parentAngle = angleForSegment(at: appIndex, total: apps.count)
        let count = deepJazzHandsWindows.count
        let totalSpread = deepJazzHandsSpread * Double(count - 1)
        let startAngle = parentAngle - totalSpread / 2.0
        return startAngle + deepJazzHandsSpread * Double(windowIndex)
    }

    func deepJazzHandsPosition(windowIndex: Int, appIndex: Int) -> CGPoint {
        let angle = deepJazzHandsAngle(windowIndex: windowIndex, appIndex: appIndex)
        return CGPoint(
            x: deepJazzHandsRadius * CGFloat(cos(angle)),
            y: deepJazzHandsRadius * CGFloat(sin(angle))
        )
    }

    func deepJazzHandsSlideVector(appIndex: Int) -> CGPoint {
        guard apps.count > 0 else { return .zero }
        let angle = angleForSegment(at: appIndex, total: apps.count)
        return CGPoint(
            x: deepJazzHandsSlideOffset * CGFloat(cos(angle)),
            y: deepJazzHandsSlideOffset * CGFloat(sin(angle))
        )
    }

    func deepJazzHandsTargetSlideVector(appIndex: Int) -> CGPoint {
        guard apps.count > 0, settings.animateParentWedge else { return .zero }
        let angle = angleForSegment(at: appIndex, total: apps.count)
        return CGPoint(
            x: deepJazzHandsSlideAmount * CGFloat(cos(angle)),
            y: deepJazzHandsSlideAmount * CGFloat(sin(angle))
        )
    }
}
