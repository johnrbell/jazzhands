import AppKit
import SwiftUI
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var overlayController: OverlayWindowController?
    private var globalFlagsMonitor: Any?
    private var backtickMonitor: Any?

    private var isOrbitVisible = false
    private var activationTimestamp: Date?
    private let tapThreshold: TimeInterval = 0.2
    private var didCycle = false

    private var hotKeyRef: EventHotKeyRef?
    nonisolated(unsafe) var eventTap: CFMachPort?
    private var tapRunLoopSource: CFRunLoopSource?
    nonisolated(unsafe) static var shared: AppDelegate?

    private nonisolated static let logFile = "/tmp/orbit.log"

    nonisolated static func log(_ msg: String) {
        let line = "\(Date()): \(msg)\n"
        if let handle = FileHandle(forWritingAtPath: logFile) {
            handle.seekToEndOfFile()
            handle.write(line.data(using: .utf8)!)
            handle.closeFile()
        } else {
            FileManager.default.createFile(atPath: logFile, contents: line.data(using: .utf8))
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        try? FileManager.default.removeItem(atPath: AppDelegate.logFile)
        AppDelegate.log("Launch. PID=\(ProcessInfo.processInfo.processIdentifier)")

        setupStatusBar()
        installHotKey()
        installFlagsMonitor()
        installBacktickMonitor()
        installSpaceChangeObserver()

        if !AXIsProcessTrusted() || !CGPreflightScreenCaptureAccess() {
            showOnboarding()
        }
    }

    // MARK: - Hotkey Installation

    private func tearDownHotKey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = tapRunLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
            eventTap = nil
            tapRunLoopSource = nil
        }
    }

    func reinstallHotKey() {
        tearDownHotKey()
        installHotKey()
        AppDelegate.log("Hotkey reinstalled")
    }

    private func installHotKey() {
        let s = OrbitSettings.shared
        let keyCode = s.keyCode
        let modFlag = s.modifierFlag

        let isSystemShortcut = modFlag == .maskCommand && keyCode == Int64(kVK_Tab)

        if isSystemShortcut {
            installEventTap()
        } else {
            installCarbonHotKey()
        }
    }

    private func installCarbonHotKey() {
        let s = OrbitSettings.shared

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData -> OSStatus in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
            Task { @MainActor in
                delegate.onHotkeyDown()
            }
            return noErr
        }, 1, &eventType, selfPtr, nil)

        let hotKeyID = EventHotKeyID(signature: OSType(0x4F524254), id: 1) // "ORBT"
        let keyCode = UInt32(s.keyCode)
        var modifiers: UInt32 = 0
        if s.modifierFlag.contains(.maskAlternate) { modifiers |= UInt32(optionKey) }
        if s.modifierFlag.contains(.maskCommand) { modifiers |= UInt32(cmdKey) }
        if s.modifierFlag.contains(.maskControl) { modifiers |= UInt32(controlKey) }
        if s.modifierFlag.contains(.maskShift) { modifiers |= UInt32(shiftKey) }

        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        AppDelegate.log("RegisterEventHotKey status=\(status) keyCode=\(keyCode) modifiers=\(modifiers)")
    }

    private nonisolated func installEventTap() {
        let selfPtr = Unmanaged.passUnretained(AppDelegate.shared!).toOpaque()

        func tapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let refcon {
                    let delegate = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()
                    if let tap = delegate.eventTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                }
                return Unmanaged.passUnretained(event)
            }

            guard type == .keyDown else {
                return Unmanaged.passUnretained(event)
            }

            let s = OrbitSettings.shared
            let kc = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags
            let targetMod = s.modifierFlag

            let modMatch: Bool
            if targetMod == .maskCommand {
                modMatch = flags.contains(.maskCommand)
            } else if targetMod == .maskAlternate {
                modMatch = flags.contains(.maskAlternate)
            } else if targetMod == .maskControl {
                modMatch = flags.contains(.maskControl)
            } else {
                modMatch = false
            }

            if kc == s.keyCode && modMatch {
                if let refcon {
                    let delegate = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()
                    Task { @MainActor in
                        delegate.onHotkeyDown()
                    }
                }
                return nil
            }

            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: tapCallback,
            userInfo: selfPtr
        ) else {
            AppDelegate.log("CGEventTap creation failed — falling back to Carbon")
            Task { @MainActor in
                self.installCarbonHotKey()
            }
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        Task { @MainActor in
            self.eventTap = tap
            self.tapRunLoopSource = source
        }

        AppDelegate.log("CGEventTap installed for system shortcut override")
    }

    // MARK: - Flags Monitor (for key release detection)

    private func installFlagsMonitor() {
        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self else { return }
            if !event.modifierFlags.contains(OrbitSettings.shared.nsModifierFlag) && self.isOrbitVisible {
                Task { @MainActor in self.onOptionReleased() }
            }
        }

        let localFlags = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self else { return event }
            if !event.modifierFlags.contains(OrbitSettings.shared.nsModifierFlag) && self.isOrbitVisible {
                Task { @MainActor in self.onOptionReleased() }
            }
            return event
        }
        _ = localFlags

        AppDelegate.log("Flags monitors installed")
    }

    private func installBacktickMonitor() {
        let kVK_ANSI_Grave: UInt16 = 50

        backtickMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isOrbitVisible, event.keyCode == kVK_ANSI_Grave else { return event }
            self.didCycle = true
            self.overlayController?.cycleSelectionReverse()
            return nil
        }

        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isOrbitVisible, event.keyCode == kVK_ANSI_Grave else { return }
            Task { @MainActor in
                self.didCycle = true
                self.overlayController?.cycleSelectionReverse()
            }
        }
    }

    // MARK: - Space Change

    private func installSpaceChangeObserver() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isOrbitVisible else { return }
                AppDelegate.log("Space changed while orbit visible — dismissing")
                self.isOrbitVisible = false
                self.activationTimestamp = nil
                self.didCycle = false
                self.overlayController?.hideOrbit()
            }
        }
    }

    // MARK: - Orbit control

    private func onHotkeyDown() {
        AppDelegate.log("onHotkeyDown isOrbitVisible=\(isOrbitVisible)")

        if isMissionControlActive() {
            AppDelegate.log("Mission Control active — ignoring hotkey")
            return
        }

        if isOrbitVisible {
            didCycle = true
            overlayController?.cycleSelection()
            return
        }
        isOrbitVisible = true
        activationTimestamp = Date()
        didCycle = false

        if overlayController == nil {
            overlayController = OverlayWindowController()
        }
        overlayController?.showOrbit()
    }

    private func onOptionReleased() {
        guard isOrbitVisible else { return }

        let wasTap: Bool
        if !didCycle, let ts = activationTimestamp {
            wasTap = Date().timeIntervalSince(ts) < tapThreshold
        } else {
            wasTap = false
        }

        isOrbitVisible = false
        activationTimestamp = nil
        didCycle = false

        if wasTap {
            overlayController?.switchToLastApp()
        } else {
            overlayController?.confirmSelection()
        }
        overlayController?.hideOrbit()
    }

    // MARK: - Mission Control Detection

    private func isMissionControlActive() -> Bool {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
        ) as? [[String: Any]] else { return false }

        for info in windowList {
            guard let owner = info[kCGWindowOwnerName as String] as? String,
                  owner == "Dock",
                  let layer = info[kCGWindowLayer as String] as? Int,
                  layer > 0 else { continue }
            return true
        }
        return false
    }

    // MARK: - Status Bar

    private var settingsWindow: NSWindow?
    private var settingsCloseObserver: Any?
    private var previewController: PreviewWindowController?
    private var onboardingWindow: NSWindow?

    private func showOnboarding() {
        if let w = onboardingWindow {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingView = NSHostingView(rootView: OnboardingView())
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 340),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        w.title = "JazzHands Setup"
        w.contentView = hostingView
        w.center()
        w.isReleasedWhenClosed = false
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow = w
    }

    private func setupStatusBar() {
        let style = OrbitSettings.shared.menuBarStyle
        if style == "hidden" {
            statusItem = nil
            return
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            switch style {
            case "orbit": button.image = makeOrbitRingIcon()
            case "icon": button.image = makeAppIcon()
            default: button.image = makeHandIcon()
            }
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "About JazzHands", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit JazzHands", action: #selector(quitApp), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    func updateStatusBar() {
        if let existing = statusItem {
            NSStatusBar.system.removeStatusItem(existing)
            statusItem = nil
        }
        setupStatusBar()
    }

    private func makeHandIcon() -> NSImage {
        let bundle = Bundle.main
        if let url = bundle.url(forResource: "MenuBarIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = true
            image.accessibilityDescription = "JazzHands"
            return image
        }
        let fallback = NSImage(size: NSSize(width: 18, height: 18))
        fallback.isTemplate = true
        return fallback
    }

    private func makeOrbitRingIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let radius: CGFloat = 7.0
            let segmentArc: CGFloat = .pi * 2.0 / 3.0 * 0.75
            let gap: CGFloat = (.pi * 2.0 / 3.0 - segmentArc) / 2.0
            let lineWidth: CGFloat = 1.8

            NSColor.black.setStroke()

            for i in 0..<3 {
                let baseAngle = CGFloat(i) * .pi * 2.0 / 3.0 - .pi / 2.0
                let startAngle = baseAngle + gap
                let endAngle = startAngle + segmentArc

                let path = NSBezierPath()
                path.appendArc(
                    withCenter: center,
                    radius: radius,
                    startAngle: startAngle * 180.0 / .pi,
                    endAngle: endAngle * 180.0 / .pi,
                    clockwise: false
                )
                path.lineWidth = lineWidth
                path.lineCapStyle = .round
                path.stroke()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "JazzHands"
        return image
    }

    private func makeAppIcon() -> NSImage {
        let bundle = Bundle.main
        if let url = bundle.url(forResource: "MenuBarAppIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = true
            image.accessibilityDescription = "JazzHands"
            return image
        }
        let fallback = NSImage(size: NSSize(width: 18, height: 18))
        fallback.isTemplate = true
        return fallback
    }

    @objc private func openSettings() {
        if let w = settingsWindow {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            showPreview()
            return
        }

        let settingsView = SettingsView()
        let hostingView = NSHostingView(rootView: settingsView)

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        w.title = "JazzHands Settings"
        w.contentView = hostingView
        w.setFrameAutosaveName("SettingsWindow")
        if !w.setFrameUsingName("SettingsWindow") {
            w.center()
        }
        w.isReleasedWhenClosed = false
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = w

        settingsCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: w,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.previewController?.hidePreview()
            }
        }

        showPreview()
    }

    private func showPreview() {
        if previewController == nil {
            previewController = PreviewWindowController()
        }
        previewController?.showPreview(relativeTo: settingsWindow)
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        previewController?.hidePreview()
        if let obs = settingsCloseObserver { NotificationCenter.default.removeObserver(obs) }
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = tapRunLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
        }
        if let m = globalFlagsMonitor { NSEvent.removeMonitor(m) }
    }
}
