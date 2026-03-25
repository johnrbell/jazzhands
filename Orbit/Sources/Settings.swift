import SwiftUI
import Carbon.HIToolbox

final class OrbitSettings: ObservableObject {
    static let shared = OrbitSettings()

    // Shortcut
    @AppStorage("hotkeyModifier") var hotkeyModifier: String = "option"
    @AppStorage("hotkeyKey") var hotkeyKey: String = "space"

    // Behavior
    @AppStorage("deepOrbitEnabled") var deepOrbitEnabled: Bool = true
    @AppStorage("hoverTimeout") var hoverTimeout: Double = 0.5
    @AppStorage("cursorSensitivity") var cursorSensitivity: Double = 1.0
    @AppStorage("centerDeadZone") var centerDeadZone: Double = 80
    @AppStorage("maxCursorRadius") var maxCursorRadius: Double = 120
    @AppStorage("showHiddenApps") var showHiddenApps: Bool = false
    @AppStorage("showMinimizedWindows") var showMinimizedWindows: Bool = false

    // Layout
    @AppStorage("primaryRadius") var primaryRadius: Double = 160
    @AppStorage("iconSize") var iconSize: Double = 92
    @AppStorage("centerIconSize") var centerIconSize: Double = 92

    // Colors (stored as hex strings)
    @AppStorage("glowColorHex") var glowColorHex: String = "#DEE9F8"
    @AppStorage("deepGlowColorHex") var deepGlowColorHex: String = "#9966FF"
    @AppStorage("ringColorHex") var ringColorHex: String = "#4D99FF"
    @AppStorage("hoverColorHex") var hoverColorHex: String = "#4D99FF"
    @AppStorage("backgroundColorHex") var backgroundColorHex: String = "#000000"

    // Effects
    @AppStorage("backgroundOpacity") var backgroundOpacity: Double = 0.65
    @AppStorage("glowIntensity") var glowIntensity: Double = 1.0
    @AppStorage("ringOpacity") var ringOpacity: Double = 0.25
    @AppStorage("centerFillOpacity") var centerFillOpacity: Double = 0.0
    @AppStorage("deepOrbitFillOpacity") var deepOrbitFillOpacity: Double = 0.25

    // Debug
    @AppStorage("showDebugOverlay") var showDebugOverlay: Bool = false

    // MARK: - Computed Colors

    var glowColor: Color { Color(hex: glowColorHex) }
    var deepGlowColor: Color { Color(hex: deepGlowColorHex) }
    var ringColor: Color { Color(hex: ringColorHex) }
    var hoverColor: Color { Color(hex: hoverColorHex) }
    var backgroundColor: Color { Color(hex: backgroundColorHex) }

    var modifierFlag: CGEventFlags {
        switch hotkeyModifier {
        case "command": return .maskCommand
        case "control": return .maskControl
        case "option": return .maskAlternate
        default: return .maskAlternate
        }
    }

    var nsModifierFlag: NSEvent.ModifierFlags {
        switch hotkeyModifier {
        case "command": return .command
        case "control": return .control
        case "option": return .option
        default: return .option
        }
    }

    var keyCode: Int64 {
        switch hotkeyKey {
        case "space": return Int64(kVK_Space)
        case "tab": return Int64(kVK_Tab)
        case "escape": return Int64(kVK_Escape)
        case "return": return Int64(kVK_Return)
        default: return Int64(kVK_Space)
        }
    }

    var shortcutDisplayName: String {
        let mod = hotkeyModifier.capitalized
        let key = hotkeyKey.capitalized
        let symbol: String
        switch hotkeyModifier {
        case "option": symbol = "⌥"
        case "command": symbol = "⌘"
        case "control": symbol = "⌃"
        default: symbol = mod
        }
        return "\(symbol) + \(key)"
    }
}

// MARK: - Color Hex Conversion

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >> 8) & 0xFF) / 255.0,
            blue: Double(rgb & 0xFF) / 255.0
        )
    }

    func toHex() -> String {
        guard let c = NSColor(self).usingColorSpace(.sRGB) else { return "#FFFFFF" }
        let r = Int(c.redComponent * 255)
        let g = Int(c.greenComponent * 255)
        let b = Int(c.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
