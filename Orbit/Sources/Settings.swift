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
    @AppStorage("hideFinderUnlessWindowed") var hideFinderUnlessWindowed: Bool = false
    @AppStorage("appSortOrder") var appSortOrder: String = "recent"

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
    @AppStorage("ringFillColorHex") var ringFillColorHex: String = "#FFFFFF"
    @AppStorage("ringFillOpacity") var ringFillOpacity: Double = 0.0
    @AppStorage("deepOrbitFillOpacity") var deepOrbitFillOpacity: Double = 0.25
    @AppStorage("cancelButtonSize") var cancelButtonSize: Double = 56
    @AppStorage("cancelButtonOpacity") var cancelButtonOpacity: Double = 0.7
    @AppStorage("segmentBorderColorHex") var segmentBorderColorHex: String = "#FFFFFF"
    @AppStorage("segmentBorderOpacity") var segmentBorderOpacity: Double = 0.0
    @AppStorage("segmentBorderWidth") var segmentBorderWidth: Double = 1.0

    // Debug
    @AppStorage("showDebugOverlay") var showDebugOverlay: Bool = false

    // MARK: - Computed Colors

    var glowColor: Color { Color(hex: glowColorHex) }
    var deepGlowColor: Color { Color(hex: deepGlowColorHex) }
    var ringColor: Color { Color(hex: ringColorHex) }
    var hoverColor: Color { Color(hex: hoverColorHex) }
    var backgroundColor: Color { Color(hex: backgroundColorHex) }
    var ringFillColor: Color { Color(hex: ringFillColorHex) }
    var segmentBorderColor: Color { Color(hex: segmentBorderColorHex) }

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

    // MARK: - Appearance Presets

    func capturePreset() -> AppearancePreset {
        AppearancePreset(
            primaryRadius: primaryRadius, iconSize: iconSize, centerIconSize: centerIconSize,
            centerDeadZone: centerDeadZone,
            glowColorHex: glowColorHex, deepGlowColorHex: deepGlowColorHex,
            ringColorHex: ringColorHex, hoverColorHex: hoverColorHex,
            backgroundColorHex: backgroundColorHex, ringFillColorHex: ringFillColorHex,
            segmentBorderColorHex: segmentBorderColorHex,
            backgroundOpacity: backgroundOpacity, glowIntensity: glowIntensity,
            ringOpacity: ringOpacity, ringFillOpacity: ringFillOpacity,
            deepOrbitFillOpacity: deepOrbitFillOpacity,
            cancelButtonSize: cancelButtonSize, cancelButtonOpacity: cancelButtonOpacity,
            segmentBorderOpacity: segmentBorderOpacity, segmentBorderWidth: segmentBorderWidth
        )
    }

    func applyPreset(_ preset: AppearancePreset) {
        primaryRadius = preset.primaryRadius
        iconSize = preset.iconSize
        centerIconSize = preset.centerIconSize
        centerDeadZone = preset.centerDeadZone
        glowColorHex = preset.glowColorHex
        deepGlowColorHex = preset.deepGlowColorHex
        ringColorHex = preset.ringColorHex
        hoverColorHex = preset.hoverColorHex
        backgroundColorHex = preset.backgroundColorHex
        ringFillColorHex = preset.ringFillColorHex
        segmentBorderColorHex = preset.segmentBorderColorHex
        backgroundOpacity = preset.backgroundOpacity
        glowIntensity = preset.glowIntensity
        ringOpacity = preset.ringOpacity
        ringFillOpacity = preset.ringFillOpacity
        deepOrbitFillOpacity = preset.deepOrbitFillOpacity
        cancelButtonSize = preset.cancelButtonSize
        cancelButtonOpacity = preset.cancelButtonOpacity
        segmentBorderOpacity = preset.segmentBorderOpacity
        segmentBorderWidth = preset.segmentBorderWidth
    }

    static let defaultPreset = AppearancePreset(
        primaryRadius: 160, iconSize: 92, centerIconSize: 92,
        centerDeadZone: 80,
        glowColorHex: "#DEE9F8", deepGlowColorHex: "#9966FF",
        ringColorHex: "#4D99FF", hoverColorHex: "#4D99FF",
        backgroundColorHex: "#000000", ringFillColorHex: "#FFFFFF",
        segmentBorderColorHex: "#FFFFFF",
        backgroundOpacity: 0.65, glowIntensity: 1.0,
        ringOpacity: 0.25, ringFillOpacity: 0.0,
        deepOrbitFillOpacity: 0.25,
        cancelButtonSize: 56, cancelButtonOpacity: 0.7,
        segmentBorderOpacity: 0.0, segmentBorderWidth: 1.0
    )

    func savedPresets() -> [NamedPreset] {
        var presets: [NamedPreset] = []
        if let data = UserDefaults.standard.data(forKey: "appearancePresets"),
           let decoded = try? JSONDecoder().decode([NamedPreset].self, from: data) {
            presets = decoded
        }
        if !presets.contains(where: { $0.name == "default 1" }) {
            presets.insert(NamedPreset(name: "default 1", preset: Self.defaultPreset), at: 0)
            if let data = try? JSONEncoder().encode(presets) {
                UserDefaults.standard.set(data, forKey: "appearancePresets")
            }
        }
        return presets
    }

    func savePreset(name: String) {
        var presets = savedPresets()
        presets.removeAll { $0.name == name }
        presets.append(NamedPreset(name: name, preset: capturePreset()))
        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: "appearancePresets")
        }
    }

    func deletePreset(name: String) {
        var presets = savedPresets()
        presets.removeAll { $0.name == name }
        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: "appearancePresets")
        }
    }
}

struct AppearancePreset: Codable {
    var primaryRadius: Double
    var iconSize: Double
    var centerIconSize: Double
    var centerDeadZone: Double
    var glowColorHex: String
    var deepGlowColorHex: String
    var ringColorHex: String
    var hoverColorHex: String
    var backgroundColorHex: String
    var ringFillColorHex: String
    var segmentBorderColorHex: String
    var backgroundOpacity: Double
    var glowIntensity: Double
    var ringOpacity: Double
    var ringFillOpacity: Double
    var deepOrbitFillOpacity: Double
    var cancelButtonSize: Double
    var cancelButtonOpacity: Double
    var segmentBorderOpacity: Double
    var segmentBorderWidth: Double
}

struct NamedPreset: Codable, Identifiable {
    var id: String { name }
    let name: String
    let preset: AppearancePreset
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
