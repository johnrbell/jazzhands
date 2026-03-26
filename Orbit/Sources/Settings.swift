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
    @AppStorage("deepOrbitSwitchOnHover") var deepOrbitSwitchOnHover: Bool = true
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
    @AppStorage("segmentBorderCutout") var segmentBorderCutout: Bool = false
    @AppStorage("animateParentWedge") var animateParentWedge: Bool = true
    @AppStorage("parentWedgeSlideDistance") var parentWedgeSlideDistance: Double = 30

    // Bump indicators ("ring" = half-circles on ring edge, "icon" = dots under icon)
    @AppStorage("bumpStyle") var bumpStyle: String = "ring"
    @AppStorage("bumpColorHex") var bumpColorHex: String = "#FFFFFF"
    @AppStorage("bumpOpacity") var bumpOpacity: Double = 0.55

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
    var bumpColor: Color { Color(hex: bumpColorHex) }

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
            segmentBorderOpacity: segmentBorderOpacity, segmentBorderWidth: segmentBorderWidth,
            segmentBorderCutout: segmentBorderCutout,
            animateParentWedge: animateParentWedge, parentWedgeSlideDistance: parentWedgeSlideDistance,
            bumpStyle: bumpStyle, bumpColorHex: bumpColorHex, bumpOpacity: bumpOpacity
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
        segmentBorderCutout = preset.segmentBorderCutout
        animateParentWedge = preset.animateParentWedge
        parentWedgeSlideDistance = preset.parentWedgeSlideDistance
        bumpStyle = preset.bumpStyle
        bumpColorHex = preset.bumpColorHex
        bumpOpacity = preset.bumpOpacity
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
        segmentBorderOpacity: 0.0, segmentBorderWidth: 1.0,
        segmentBorderCutout: false,
        animateParentWedge: true, parentWedgeSlideDistance: 30,
        bumpStyle: "ring", bumpColorHex: "#FFFFFF", bumpOpacity: 0.55
    )

    static let overwatchPreset = AppearancePreset(
        primaryRadius: 200, iconSize: 92, centerIconSize: 92,
        centerDeadZone: 150,
        glowColorHex: "#DEE9F8", deepGlowColorHex: "#9966FF",
        ringColorHex: "#E3F7F4", hoverColorHex: "#F4F7F7",
        backgroundColorHex: "#000000", ringFillColorHex: "#FFFFFF",
        segmentBorderColorHex: "#F0F6FF",
        backgroundOpacity: 0.65, glowIntensity: 1.0,
        ringOpacity: 0.0, ringFillOpacity: 0.0,
        deepOrbitFillOpacity: 0.5,
        cancelButtonSize: 56, cancelButtonOpacity: 0.45,
        segmentBorderOpacity: 0.45, segmentBorderWidth: 2.5,
        segmentBorderCutout: false,
        animateParentWedge: true, parentWedgeSlideDistance: 30,
        bumpStyle: "icon", bumpColorHex: "#FFFFFF", bumpOpacity: 0.3
    )

    static let whiteRingSmallPreset = AppearancePreset(
        primaryRadius: 150, iconSize: 92, centerIconSize: 92,
        centerDeadZone: 90,
        glowColorHex: "#DEE9F8", deepGlowColorHex: "#9966FF",
        ringColorHex: "#E3F7F4", hoverColorHex: "#F4F7F7",
        backgroundColorHex: "#000000", ringFillColorHex: "#FFFFFF",
        segmentBorderColorHex: "#F0F6FF",
        backgroundOpacity: 0.65, glowIntensity: 1.0,
        ringOpacity: 0.0, ringFillOpacity: 0.3,
        deepOrbitFillOpacity: 0.5,
        cancelButtonSize: 56, cancelButtonOpacity: 0.45,
        segmentBorderOpacity: 0.45, segmentBorderWidth: 2.5,
        segmentBorderCutout: true,
        animateParentWedge: true, parentWedgeSlideDistance: 30,
        bumpStyle: "icon", bumpColorHex: "#FFFFFF", bumpOpacity: 0.3
    )

    static let whiteRingPreset = AppearancePreset(
        primaryRadius: 200, iconSize: 92, centerIconSize: 92,
        centerDeadZone: 150,
        glowColorHex: "#DEE9F8", deepGlowColorHex: "#FF81FF",
        ringColorHex: "#E3F7F4", hoverColorHex: "#FF81FE",
        backgroundColorHex: "#000000", ringFillColorHex: "#FFFFFF",
        segmentBorderColorHex: "#F0F6FF",
        backgroundOpacity: 0.65, glowIntensity: 1.0,
        ringOpacity: 0.0, ringFillOpacity: 0.3,
        deepOrbitFillOpacity: 0.5,
        cancelButtonSize: 56, cancelButtonOpacity: 0.45,
        segmentBorderOpacity: 0.45, segmentBorderWidth: 2.5,
        segmentBorderCutout: true,
        animateParentWedge: true, parentWedgeSlideDistance: 30,
        bumpStyle: "icon", bumpColorHex: "#FFFFFF", bumpOpacity: 0.3
    )

    static let claudeGeneratedPreset = AppearancePreset(
        primaryRadius: 175, iconSize: 92, centerIconSize: 92,
        centerDeadZone: 110,
        glowColorHex: "#66FFCC", deepGlowColorHex: "#33CCAA",
        ringColorHex: "#44DDBB", hoverColorHex: "#88FFE0",
        backgroundColorHex: "#000000", ringFillColorHex: "#66FFCC",
        segmentBorderColorHex: "#88FFE0",
        backgroundOpacity: 0.7, glowIntensity: 0.8,
        ringOpacity: 0.15, ringFillOpacity: 0.12,
        deepOrbitFillOpacity: 0.4,
        cancelButtonSize: 56, cancelButtonOpacity: 0.5,
        segmentBorderOpacity: 0.35, segmentBorderWidth: 2.0,
        segmentBorderCutout: true,
        animateParentWedge: true, parentWedgeSlideDistance: 30,
        bumpStyle: "icon", bumpColorHex: "#66FFCC", bumpOpacity: 0.4
    )

    static let builtInPresets: [NamedPreset] = [
        NamedPreset(name: "default 1", preset: defaultPreset),
        NamedPreset(name: "overwatch", preset: overwatchPreset),
        NamedPreset(name: "white_ring_small", preset: whiteRingSmallPreset),
        NamedPreset(name: "white_ring", preset: whiteRingPreset),
        NamedPreset(name: "Claude-generated", preset: claudeGeneratedPreset),
    ]

    func savedPresets() -> [NamedPreset] {
        var presets: [NamedPreset] = []
        if let data = UserDefaults.standard.data(forKey: "appearancePresets"),
           let decoded = try? JSONDecoder().decode([NamedPreset].self, from: data) {
            presets = decoded
        }
        var changed = false
        for (i, builtIn) in Self.builtInPresets.enumerated() {
            if !presets.contains(where: { $0.name == builtIn.name }) {
                presets.insert(builtIn, at: min(i, presets.count))
                changed = true
            }
        }
        if changed {
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
    var segmentBorderCutout: Bool
    var animateParentWedge: Bool
    var parentWedgeSlideDistance: Double
    var bumpStyle: String
    var bumpColorHex: String
    var bumpOpacity: Double

    init(primaryRadius: Double, iconSize: Double, centerIconSize: Double, centerDeadZone: Double,
         glowColorHex: String, deepGlowColorHex: String, ringColorHex: String, hoverColorHex: String,
         backgroundColorHex: String, ringFillColorHex: String, segmentBorderColorHex: String,
         backgroundOpacity: Double, glowIntensity: Double, ringOpacity: Double, ringFillOpacity: Double,
         deepOrbitFillOpacity: Double, cancelButtonSize: Double, cancelButtonOpacity: Double,
         segmentBorderOpacity: Double, segmentBorderWidth: Double,
         segmentBorderCutout: Bool = false,
         animateParentWedge: Bool = true, parentWedgeSlideDistance: Double = 30,
         bumpStyle: String = "ring", bumpColorHex: String = "#FFFFFF", bumpOpacity: Double = 0.55) {
        self.primaryRadius = primaryRadius; self.iconSize = iconSize; self.centerIconSize = centerIconSize
        self.centerDeadZone = centerDeadZone; self.glowColorHex = glowColorHex
        self.deepGlowColorHex = deepGlowColorHex; self.ringColorHex = ringColorHex
        self.hoverColorHex = hoverColorHex; self.backgroundColorHex = backgroundColorHex
        self.ringFillColorHex = ringFillColorHex; self.segmentBorderColorHex = segmentBorderColorHex
        self.backgroundOpacity = backgroundOpacity; self.glowIntensity = glowIntensity
        self.ringOpacity = ringOpacity; self.ringFillOpacity = ringFillOpacity
        self.deepOrbitFillOpacity = deepOrbitFillOpacity; self.cancelButtonSize = cancelButtonSize
        self.cancelButtonOpacity = cancelButtonOpacity; self.segmentBorderOpacity = segmentBorderOpacity
        self.segmentBorderWidth = segmentBorderWidth; self.segmentBorderCutout = segmentBorderCutout
        self.animateParentWedge = animateParentWedge; self.parentWedgeSlideDistance = parentWedgeSlideDistance
        self.bumpStyle = bumpStyle; self.bumpColorHex = bumpColorHex; self.bumpOpacity = bumpOpacity
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = OrbitSettings.defaultPreset
        primaryRadius = (try? c.decode(Double.self, forKey: .primaryRadius)) ?? d.primaryRadius
        iconSize = (try? c.decode(Double.self, forKey: .iconSize)) ?? d.iconSize
        centerIconSize = (try? c.decode(Double.self, forKey: .centerIconSize)) ?? d.centerIconSize
        centerDeadZone = (try? c.decode(Double.self, forKey: .centerDeadZone)) ?? d.centerDeadZone
        glowColorHex = (try? c.decode(String.self, forKey: .glowColorHex)) ?? d.glowColorHex
        deepGlowColorHex = (try? c.decode(String.self, forKey: .deepGlowColorHex)) ?? d.deepGlowColorHex
        ringColorHex = (try? c.decode(String.self, forKey: .ringColorHex)) ?? d.ringColorHex
        hoverColorHex = (try? c.decode(String.self, forKey: .hoverColorHex)) ?? d.hoverColorHex
        backgroundColorHex = (try? c.decode(String.self, forKey: .backgroundColorHex)) ?? d.backgroundColorHex
        ringFillColorHex = (try? c.decode(String.self, forKey: .ringFillColorHex)) ?? d.ringFillColorHex
        backgroundOpacity = (try? c.decode(Double.self, forKey: .backgroundOpacity)) ?? d.backgroundOpacity
        glowIntensity = (try? c.decode(Double.self, forKey: .glowIntensity)) ?? d.glowIntensity
        ringOpacity = (try? c.decode(Double.self, forKey: .ringOpacity)) ?? d.ringOpacity
        ringFillOpacity = (try? c.decode(Double.self, forKey: .ringFillOpacity)) ?? d.ringFillOpacity
        deepOrbitFillOpacity = (try? c.decode(Double.self, forKey: .deepOrbitFillOpacity)) ?? d.deepOrbitFillOpacity
        cancelButtonSize = (try? c.decode(Double.self, forKey: .cancelButtonSize)) ?? d.cancelButtonSize
        cancelButtonOpacity = (try? c.decode(Double.self, forKey: .cancelButtonOpacity)) ?? d.cancelButtonOpacity
        // Handle renamed fields: segment border was previously spoke
        segmentBorderColorHex = (try? c.decode(String.self, forKey: .segmentBorderColorHex))
            ?? (try? c.decode(String.self, forKey: .spokeColorHex)) ?? d.segmentBorderColorHex
        segmentBorderOpacity = (try? c.decode(Double.self, forKey: .segmentBorderOpacity))
            ?? (try? c.decode(Double.self, forKey: .spokeOpacity)) ?? d.segmentBorderOpacity
        segmentBorderWidth = (try? c.decode(Double.self, forKey: .segmentBorderWidth))
            ?? (try? c.decode(Double.self, forKey: .spokeWidth)) ?? d.segmentBorderWidth
        segmentBorderCutout = (try? c.decode(Bool.self, forKey: .segmentBorderCutout)) ?? d.segmentBorderCutout
        animateParentWedge = (try? c.decode(Bool.self, forKey: .animateParentWedge)) ?? d.animateParentWedge
        parentWedgeSlideDistance = (try? c.decode(Double.self, forKey: .parentWedgeSlideDistance)) ?? d.parentWedgeSlideDistance
        bumpStyle = (try? c.decode(String.self, forKey: .bumpStyle)) ?? d.bumpStyle
        bumpColorHex = (try? c.decode(String.self, forKey: .bumpColorHex)) ?? d.bumpColorHex
        bumpOpacity = (try? c.decode(Double.self, forKey: .bumpOpacity)) ?? d.bumpOpacity
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(primaryRadius, forKey: .primaryRadius)
        try c.encode(iconSize, forKey: .iconSize)
        try c.encode(centerIconSize, forKey: .centerIconSize)
        try c.encode(centerDeadZone, forKey: .centerDeadZone)
        try c.encode(glowColorHex, forKey: .glowColorHex)
        try c.encode(deepGlowColorHex, forKey: .deepGlowColorHex)
        try c.encode(ringColorHex, forKey: .ringColorHex)
        try c.encode(hoverColorHex, forKey: .hoverColorHex)
        try c.encode(backgroundColorHex, forKey: .backgroundColorHex)
        try c.encode(ringFillColorHex, forKey: .ringFillColorHex)
        try c.encode(segmentBorderColorHex, forKey: .segmentBorderColorHex)
        try c.encode(backgroundOpacity, forKey: .backgroundOpacity)
        try c.encode(glowIntensity, forKey: .glowIntensity)
        try c.encode(ringOpacity, forKey: .ringOpacity)
        try c.encode(ringFillOpacity, forKey: .ringFillOpacity)
        try c.encode(deepOrbitFillOpacity, forKey: .deepOrbitFillOpacity)
        try c.encode(cancelButtonSize, forKey: .cancelButtonSize)
        try c.encode(cancelButtonOpacity, forKey: .cancelButtonOpacity)
        try c.encode(segmentBorderOpacity, forKey: .segmentBorderOpacity)
        try c.encode(segmentBorderWidth, forKey: .segmentBorderWidth)
        try c.encode(segmentBorderCutout, forKey: .segmentBorderCutout)
        try c.encode(animateParentWedge, forKey: .animateParentWedge)
        try c.encode(parentWedgeSlideDistance, forKey: .parentWedgeSlideDistance)
        try c.encode(bumpStyle, forKey: .bumpStyle)
        try c.encode(bumpColorHex, forKey: .bumpColorHex)
        try c.encode(bumpOpacity, forKey: .bumpOpacity)
    }

    private enum CodingKeys: String, CodingKey {
        case primaryRadius, iconSize, centerIconSize, centerDeadZone
        case glowColorHex, deepGlowColorHex, ringColorHex, hoverColorHex
        case backgroundColorHex, ringFillColorHex, segmentBorderColorHex
        case backgroundOpacity, glowIntensity, ringOpacity, ringFillOpacity
        case deepOrbitFillOpacity, cancelButtonSize, cancelButtonOpacity
        case segmentBorderOpacity, segmentBorderWidth, segmentBorderCutout
        case animateParentWedge, parentWedgeSlideDistance
        case bumpStyle, bumpColorHex, bumpOpacity
        case spokeColorHex, spokeOpacity, spokeWidth
    }
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
