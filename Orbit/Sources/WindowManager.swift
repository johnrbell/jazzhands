import AppKit
import CoreGraphics

final class WindowManager {
    static let shared = WindowManager()

    private func log(_ msg: String) {
        let entry = "[\(Date())] \(msg)\n"
        let path = "/tmp/orbit.log"
        if let handle = FileHandle(forWritingAtPath: path) {
            handle.seekToEndOfFile()
            handle.write(entry.data(using: .utf8)!)
            handle.closeFile()
        } else {
            try? entry.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }

    func fetchActiveApps() -> [OrbitApp] {
        let settings = OrbitSettings.shared
        let includeOffScreen = settings.showMinimizedWindows

        let listOptions: CGWindowListOption = includeOffScreen
            ? [.excludeDesktopElements, .optionAll]
            : [.optionOnScreenOnly, .excludeDesktopElements]

        let windowInfoList = CGWindowListCopyWindowInfo(
            listOptions,
            kCGNullWindowID
        ) as? [[String: Any]] ?? []

        var appWindowMap: [pid_t: [OrbitWindow]] = [:]

        let minWindowDimension: CGFloat = 50

        for info in windowInfoList {
            guard let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                  let windowID = info[kCGWindowNumber as String] as? CGWindowID,
                  let layer = info[kCGWindowLayer as String] as? Int,
                  layer == 0 else { continue }

            let title = info[kCGWindowName as String] as? String ?? ""
            let bounds = CGRect(dictionaryRepresentation: info[kCGWindowBounds as String] as! CFDictionary) ?? .zero
            let isOnScreen = info[kCGWindowIsOnscreen as String] as? Bool ?? true

            if bounds.width < minWindowDimension || bounds.height < minWindowDimension {
                continue
            }

            let window = OrbitWindow(
                id: windowID,
                title: title,
                bounds: bounds,
                ownerPID: pid,
                isOnScreen: isOnScreen
            )

            appWindowMap[pid, default: []].append(window)
        }

        let runningApps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular
        }

        var orbitApps: [OrbitApp] = []

        for app in runningApps {
            if !settings.showHiddenApps && app.isHidden { continue }

            let pid = app.processIdentifier
            var windows = appWindowMap[pid] ?? []

            if settings.hideFinderUnlessWindowed && app.bundleIdentifier == "com.apple.finder" {
                let axWindows = fetchAXWindows(pid: pid)
                if axWindows.isEmpty { continue }
            }

            if settings.showHiddenApps && windows.isEmpty && !app.isHidden {
                continue
            }
            if !settings.showHiddenApps && windows.isEmpty {
                continue
            }

            let axWindows = fetchAXWindows(pid: pid)
            log("App: \(app.localizedName ?? "?") pid=\(pid) cgWindows=\(windows.count) axWindows=\(axWindows.count)")
            for (i, w) in windows.enumerated() {
                log("  CG[\(i)] id=\(w.id) title='\(w.title)' bounds=\(w.bounds)")
            }
            for (i, ax) in axWindows.enumerated() {
                log("  AX[\(i)] title='\(ax.title)' bounds=\(ax.bounds)")
            }

            if !axWindows.isEmpty {
                let before = windows.count
                windows = filterToAXWindows(cgWindows: windows, axWindows: axWindows)
                if windows.count < before {
                    log("  filtered \(before - windows.count) phantom CG window(s)")
                }
                if windows.isEmpty {
                    log("  all CG windows filtered — skipping app")
                    continue
                }
                windows = enrichWindowTitles(windows: windows, axTitles: axWindows)
            }

            for (i, w) in windows.enumerated() {
                log("  FINAL[\(i)] id=\(w.id) title='\(w.title)'")
            }

            let icon = app.icon ?? NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage()
            icon.size = NSSize(width: 48, height: 48)

            orbitApps.append(OrbitApp(
                id: pid,
                name: app.localizedName ?? "Unknown",
                bundleIdentifier: app.bundleIdentifier,
                icon: icon,
                runningApp: app,
                windows: windows
            ))
        }

        switch settings.appSortOrder {
        case "alphabetical":
            orbitApps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        default:
            break
        }

        return orbitApps
    }

    private func fetchAXWindows(pid: pid_t) -> [(title: String, bounds: CGRect)] {
        let appRef = AXUIElementCreateApplication(pid)
        var windowList: CFTypeRef?
        AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowList)
        guard let axWindows = windowList as? [AXUIElement] else { return [] }

        var results: [(title: String, bounds: CGRect)] = []
        for axWindow in axWindows {
            var titleValue: CFTypeRef?
            AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleValue)
            let title = (titleValue as? String) ?? ""

            var posValue: CFTypeRef?
            var sizeValue: CFTypeRef?
            AXUIElementCopyAttributeValue(axWindow, kAXPositionAttribute as CFString, &posValue)
            AXUIElementCopyAttributeValue(axWindow, kAXSizeAttribute as CFString, &sizeValue)

            var pos = CGPoint.zero
            var size = CGSize.zero
            if let posValue { AXValueGetValue(posValue as! AXValue, .cgPoint, &pos) }
            if let sizeValue { AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) }

            results.append((title: title, bounds: CGRect(origin: pos, size: size)))
        }
        return results
    }

    private func filterToAXWindows(cgWindows: [OrbitWindow], axWindows: [(title: String, bounds: CGRect)]) -> [OrbitWindow] {
        return cgWindows.filter { cg in
            axWindows.contains { ax in boundsMatch(cg.bounds, ax.bounds) }
        }
    }

    private func enrichWindowTitles(windows: [OrbitWindow], axTitles: [(title: String, bounds: CGRect)]) -> [OrbitWindow] {
        var result = windows
        var usedAX = Set<Int>()

        for i in 0..<result.count {
            guard result[i].title.isEmpty else { continue }
            if let matchIdx = axTitles.indices.first(where: { !usedAX.contains($0) && boundsMatch(result[i].bounds, axTitles[$0].bounds) }),
               !axTitles[matchIdx].title.isEmpty {
                usedAX.insert(matchIdx)
                result[i] = OrbitWindow(
                    id: result[i].id,
                    title: axTitles[matchIdx].title,
                    bounds: result[i].bounds,
                    ownerPID: result[i].ownerPID,
                    isOnScreen: result[i].isOnScreen
                )
            }
        }

        var axIdx = 0
        for i in 0..<result.count {
            guard result[i].title.isEmpty else { continue }
            while axIdx < axTitles.count && usedAX.contains(axIdx) { axIdx += 1 }
            guard axIdx < axTitles.count, !axTitles[axIdx].title.isEmpty else { continue }
            usedAX.insert(axIdx)
            result[i] = OrbitWindow(
                id: result[i].id,
                title: axTitles[axIdx].title,
                bounds: result[i].bounds,
                ownerPID: result[i].ownerPID,
                isOnScreen: result[i].isOnScreen
            )
            axIdx += 1
        }

        return result
    }

    private func boundsMatch(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.origin.x - b.origin.x) < 10 &&
        abs(a.origin.y - b.origin.y) < 10 &&
        abs(a.width - b.width) < 10 &&
        abs(a.height - b.height) < 10
    }

    func activateApp(_ app: OrbitApp) {
        log("activateApp: '\(app.name)' pid=\(app.id) axTrusted=\(AXIsProcessTrusted())")

        let appRef = AXUIElementCreateApplication(app.id)
        var windowList: CFTypeRef?
        AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowList)
        if let axWindows = windowList as? [AXUIElement], let first = axWindows.first {
            AXUIElementPerformAction(first, kAXRaiseAction as CFString)
        }

        app.runningApp.activate(options: [])
    }

    func activateWindow(_ window: OrbitWindow) {
        log("activateWindow: '\(window.title)' id=\(window.id) pid=\(window.ownerPID) axTrusted=\(AXIsProcessTrusted())")

        let app = NSRunningApplication(processIdentifier: window.ownerPID)
        let appRef = AXUIElementCreateApplication(window.ownerPID)
        var windowList: CFTypeRef?
        AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowList)

        guard let axWindows = windowList as? [AXUIElement], !axWindows.isEmpty else {
            log("activateWindow: no AX windows for pid=\(window.ownerPID) — falling back to app activate")
            app?.activate(options: [])
            return
        }

        var targetAXWindow: AXUIElement?

        if !window.title.isEmpty {
            for axWindow in axWindows {
                var titleValue: CFTypeRef?
                AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleValue)
                if let axTitle = titleValue as? String,
                   axTitle == window.title || axTitle.hasPrefix(window.title) || window.title.hasPrefix(axTitle) {
                    log("activateWindow: matched '\(axTitle)' by title")
                    targetAXWindow = axWindow
                    break
                }
            }
        }

        if targetAXWindow == nil {
            for axWindow in axWindows {
                var posValue: CFTypeRef?
                var sizeValue: CFTypeRef?
                AXUIElementCopyAttributeValue(axWindow, kAXPositionAttribute as CFString, &posValue)
                AXUIElementCopyAttributeValue(axWindow, kAXSizeAttribute as CFString, &sizeValue)

                var pos = CGPoint.zero
                var size = CGSize.zero
                if let posValue { AXValueGetValue(posValue as! AXValue, .cgPoint, &pos) }
                if let sizeValue { AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) }
                let axBounds = CGRect(origin: pos, size: size)

                if boundsMatch(window.bounds, axBounds) {
                    log("activateWindow: matched by bounds")
                    targetAXWindow = axWindow
                    break
                }
            }
        }

        if targetAXWindow == nil {
            log("activateWindow: no title/bounds match, using first AX window")
            targetAXWindow = axWindows.first
        }

        if let target = targetAXWindow {
            AXUIElementPerformAction(target, kAXRaiseAction as CFString)
            AXUIElementSetAttributeValue(target, kAXMainAttribute as CFString, kCFBooleanTrue)
            AXUIElementSetAttributeValue(target, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        }

        app?.activate(options: [])
    }

    var hasScreenCapturePermission: Bool {
        CGPreflightScreenCaptureAccess()
    }

    func requestScreenCaptureIfNeeded() {
        // No-op: permission is checked silently at launch in AppDelegate.
        // CGRequestScreenCaptureAccess() was triggering repeated OS prompts.
    }

    func captureWindowThumbnail(windowID: CGWindowID, maxSize: CGSize = CGSize(width: 150, height: 97)) -> NSImage? {
        guard CGPreflightScreenCaptureAccess() else {
            log("capture wid=\(windowID) skipped — no screen capture permission")
            return nil
        }
        log("capture wid=\(windowID)")
        guard let cgImage = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowID,
            [.boundsIgnoreFraming, .nominalResolution]
        ) else {
            log("  CGWindowListCreateImage returned nil")
            return nil
        }

        log("  image size=\(cgImage.width)x\(cgImage.height)")
        guard cgImage.width > 1, cgImage.height > 1 else {
            log("  image too small, skipping")
            return nil
        }

        let originalSize = CGSize(width: cgImage.width, height: cgImage.height)
        let scale = min(maxSize.width / originalSize.width, maxSize.height / originalSize.height, 1.0)
        let targetSize = NSSize(
            width: originalSize.width * scale,
            height: originalSize.height * scale
        )

        let nsImage = NSImage(cgImage: cgImage, size: targetSize)
        return nsImage
    }
}
