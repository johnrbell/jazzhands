import AppKit

struct JazzHandsApp: Identifiable, Equatable {
    let id: pid_t
    let name: String
    let bundleIdentifier: String?
    let icon: NSImage
    let runningApp: NSRunningApplication
    var windows: [JazzHandsWindow]

    static func == (lhs: JazzHandsApp, rhs: JazzHandsApp) -> Bool {
        lhs.id == rhs.id
    }
}

struct JazzHandsWindow: Identifiable, Equatable {
    let id: CGWindowID
    let title: String
    let bounds: CGRect
    let ownerPID: pid_t
    let isOnScreen: Bool

    static func == (lhs: JazzHandsWindow, rhs: JazzHandsWindow) -> Bool {
        lhs.id == rhs.id
    }
}
