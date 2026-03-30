import AppKit

struct OrbitApp: Identifiable, Equatable {
    let id: pid_t
    let name: String
    let bundleIdentifier: String?
    let icon: NSImage
    let runningApp: NSRunningApplication
    var windows: [OrbitWindow]

    static func == (lhs: OrbitApp, rhs: OrbitApp) -> Bool {
        lhs.id == rhs.id
    }
}

struct OrbitWindow: Identifiable, Equatable {
    let id: CGWindowID
    let title: String
    let bounds: CGRect
    let ownerPID: pid_t
    let isOnScreen: Bool

    static func == (lhs: OrbitWindow, rhs: OrbitWindow) -> Bool {
        lhs.id == rhs.id
    }
}
