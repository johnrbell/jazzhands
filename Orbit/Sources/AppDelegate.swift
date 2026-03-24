import AppKit
import SwiftUI
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var overlayController: OverlayWindowController?
    private var globalFlagsMonitor: Any?

    private var isOrbitVisible = false
    private var activationTimestamp: Date?
    private let tapThreshold: TimeInterval = 0.2

    private var hotKeyRef: EventHotKeyRef?
    private static var shared: AppDelegate?

    private static let logFile = "/tmp/orbit.log"

    static func log(_ msg: String) {
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

        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }

        WindowManager.shared.requestScreenCaptureIfNeeded()
    }

    // MARK: - Carbon Hot Key

    private func installHotKey() {
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

    // MARK: - Orbit control

    private func onHotkeyDown() {
        AppDelegate.log("onHotkeyDown isOrbitVisible=\(isOrbitVisible)")
        guard !isOrbitVisible else { return }
        isOrbitVisible = true
        activationTimestamp = Date()

        if overlayController == nil {
            overlayController = OverlayWindowController()
        }
        overlayController?.showOrbit()
    }

    private func onOptionReleased() {
        guard isOrbitVisible else { return }

        let wasTap: Bool
        if let ts = activationTimestamp {
            wasTap = Date().timeIntervalSince(ts) < tapThreshold
        } else {
            wasTap = false
        }

        isOrbitVisible = false
        activationTimestamp = nil

        if wasTap {
            overlayController?.switchToLastApp()
        } else {
            overlayController?.confirmSelection()
        }
        overlayController?.hideOrbit()
    }

    // MARK: - Status Bar

    private var settingsWindow: NSWindow?

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "circle.circle", accessibilityDescription: "Orbit")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "About Orbit", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Orbit", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func openSettings() {
        if let w = settingsWindow {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
        let hostingView = NSHostingView(rootView: settingsView)

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "Orbit Settings"
        w.contentView = hostingView
        w.center()
        w.isReleasedWhenClosed = false
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = w
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
        if let m = globalFlagsMonitor { NSEvent.removeMonitor(m) }
    }
}
