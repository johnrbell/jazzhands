import SwiftUI
import Carbon.HIToolbox

final class JazzHandsSettings: ObservableObject {
    static let shared = JazzHandsSettings()

    // Shortcut
    @AppStorage("hotkeyModifier") var hotkeyModifier: String = "option"
    @AppStorage("hotkeyKey") var hotkeyKey: String = "space"

    // Behavior
    @AppStorage("fingersEnabled") var fingersEnabled: Bool = true
    @AppStorage("hoverTimeout") var hoverTimeout: Double = 0.5
    @AppStorage("cursorSensitivity") var cursorSensitivity: Double = 1.0
    @AppStorage("centerDeadZone") var centerDeadZone: Double = 80
    @AppStorage("maxCursorRadius") var maxCursorRadius: Double = 120
    @AppStorage("fingersSwitchOnHover") var fingersSwitchOnHover: Bool = true
    @AppStorage("showHiddenApps") var showHiddenApps: Bool = false
    @AppStorage("showMinimizedWindows") var showMinimizedWindows: Bool = false
    @AppStorage("hideFinderUnlessWindowed") var hideFinderUnlessWindowed: Bool = false
    @AppStorage("cursorRestoreMode") var cursorRestoreMode: String = "center"
    @AppStorage("centerCursorOnApp") var centerCursorOnApp: Bool = false
    @AppStorage("appSortOrder") var appSortOrder: String = "recent"
    @AppStorage("windowSortOrder") var windowSortOrder: String = "recent"

    // Layout
    @AppStorage("primaryRadius") var primaryRadius: Double = 160
    @AppStorage("iconSize") var iconSize: Double = 92

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
    @AppStorage("centerRingOpacity") var centerRingOpacity: Double = 0.25
    @AppStorage("hoverHighlightOpacity") var hoverHighlightOpacity: Double = 1.0
    @AppStorage("centerFillOpacity") var centerFillOpacity: Double = 0.0
    @AppStorage("ringFillColorHex") var ringFillColorHex: String = "#FFFFFF"
    @AppStorage("ringFillOpacity") var ringFillOpacity: Double = 0.0
    @AppStorage("fingersFillColorHex") var fingersFillColorHex: String = "#FFFFFF"
    @AppStorage("fingersFillOpacity") var fingersFillOpacity: Double = 0.25
    @AppStorage("fingersInactiveOpacity") var fingersInactiveOpacity: Double = 0.15
    @AppStorage("fingersDimming") var fingersDimming: Double = 0.4
    @AppStorage("segmentBorderColorHex") var segmentBorderColorHex: String = "#FFFFFF"
    @AppStorage("segmentBorderOpacity") var segmentBorderOpacity: Double = 0.0
    @AppStorage("segmentBorderWidth") var segmentBorderWidth: Double = 1.0
    @AppStorage("segmentBorderCutout") var segmentBorderCutout: Bool = false
    @AppStorage("animateParentWedge") var animateParentWedge: Bool = true
    @AppStorage("parentWedgeSlideDistance") var parentWedgeSlideDistance: Double = 30
    @AppStorage("fingersScale") var fingersScale: Double = 1.0

    // Icon Hover
    @AppStorage("hoverRingSize") var hoverRingSize: Double = 20
    @AppStorage("hoverStrokeWidth") var hoverStrokeWidth: Double = 2
    @AppStorage("hoverFillOpacity") var hoverFillOpacity: Double = 0.2
    @AppStorage("hoverIconScale") var hoverIconScale: Double = 1.2
    @AppStorage("hoverGlowRadius") var hoverGlowRadius: Double = 15

    // Center Label
    @AppStorage("centerLabelEnabled") var centerLabelEnabled: Bool = true
    @AppStorage("centerLabelFontSize") var centerLabelFontSize: Double = 14
    @AppStorage("centerLabelFontWeight") var centerLabelFontWeight: String = "semibold"
    @AppStorage("centerLabelFontDesign") var centerLabelFontDesign: String = "rounded"
    @AppStorage("centerLabelColorHex") var centerLabelColorHex: String = "#FFFFFF"
    @AppStorage("centerLabelOpacity") var centerLabelOpacity: Double = 1.0
    @AppStorage("centerLabelMaxWidth") var centerLabelMaxWidth: Double = 160
    @AppStorage("centerLabelWrap") var centerLabelWrap: Bool = false
    @AppStorage("centerLabelShadowRadius") var centerLabelShadowRadius: Double = 0

    // Window indicators
    @AppStorage("bumpStyle") var bumpStyle: String = "ring"
    @AppStorage("bumpColorHex") var bumpColorHex: String = "#FFFFFF"
    @AppStorage("bumpOpacity") var bumpOpacity: Double = 0.55
    @AppStorage("bumpActiveScale") var bumpActiveScale: Double = 1.5
    @AppStorage("bumpActiveOpacity") var bumpActiveOpacity: Double = 1.0

    // Menu Bar
    @AppStorage("menuBarStyle") var menuBarStyle: String = "hand"

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
    var fingersFillColor: Color { Color(hex: fingersFillColorHex) }
    var centerLabelColor: Color { Color(hex: centerLabelColorHex) }
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
            primaryRadius: primaryRadius, iconSize: iconSize,
            centerDeadZone: centerDeadZone,
            glowColorHex: glowColorHex, deepGlowColorHex: deepGlowColorHex,
            ringColorHex: ringColorHex, hoverColorHex: hoverColorHex,
            backgroundColorHex: backgroundColorHex, ringFillColorHex: ringFillColorHex,
            segmentBorderColorHex: segmentBorderColorHex,
            backgroundOpacity: backgroundOpacity, glowIntensity: glowIntensity,
            ringOpacity: ringOpacity, ringFillOpacity: ringFillOpacity,
            fingersFillOpacity: fingersFillOpacity,
            segmentBorderOpacity: segmentBorderOpacity, segmentBorderWidth: segmentBorderWidth,
            segmentBorderCutout: segmentBorderCutout,
            animateParentWedge: animateParentWedge, parentWedgeSlideDistance: parentWedgeSlideDistance,
            hoverRingSize: hoverRingSize, hoverStrokeWidth: hoverStrokeWidth,
            hoverFillOpacity: hoverFillOpacity, hoverIconScale: hoverIconScale, hoverGlowRadius: hoverGlowRadius,
            centerLabelEnabled: centerLabelEnabled, centerLabelFontSize: centerLabelFontSize,
            centerLabelFontWeight: centerLabelFontWeight, centerLabelFontDesign: centerLabelFontDesign,
            centerLabelColorHex: centerLabelColorHex, centerLabelOpacity: centerLabelOpacity,
            centerLabelMaxWidth: centerLabelMaxWidth, centerLabelShadowRadius: centerLabelShadowRadius,
            centerLabelWrap: centerLabelWrap,
            centerRingOpacity: centerRingOpacity, hoverHighlightOpacity: hoverHighlightOpacity,
            centerFillOpacity: centerFillOpacity,
            fingersFillColorHex: fingersFillColorHex, fingersInactiveOpacity: fingersInactiveOpacity,
            fingersDimming: fingersDimming, fingersScale: fingersScale,
            bumpStyle: bumpStyle, bumpColorHex: bumpColorHex, bumpOpacity: bumpOpacity,
            bumpActiveScale: bumpActiveScale, bumpActiveOpacity: bumpActiveOpacity
        )
    }

    func applyPreset(_ preset: AppearancePreset) {
        primaryRadius = preset.primaryRadius
        iconSize = preset.iconSize
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
        fingersFillOpacity = preset.fingersFillOpacity
        segmentBorderOpacity = preset.segmentBorderOpacity
        segmentBorderWidth = preset.segmentBorderWidth
        segmentBorderCutout = preset.segmentBorderCutout
        animateParentWedge = preset.animateParentWedge
        parentWedgeSlideDistance = preset.parentWedgeSlideDistance
        hoverRingSize = preset.hoverRingSize
        hoverStrokeWidth = preset.hoverStrokeWidth
        hoverFillOpacity = preset.hoverFillOpacity
        hoverIconScale = preset.hoverIconScale
        hoverGlowRadius = preset.hoverGlowRadius
        centerLabelEnabled = preset.centerLabelEnabled
        centerLabelFontSize = preset.centerLabelFontSize
        centerLabelFontWeight = preset.centerLabelFontWeight
        centerLabelFontDesign = preset.centerLabelFontDesign
        centerLabelColorHex = preset.centerLabelColorHex
        centerLabelOpacity = preset.centerLabelOpacity
        centerLabelMaxWidth = preset.centerLabelMaxWidth
        centerLabelShadowRadius = preset.centerLabelShadowRadius
        centerLabelWrap = preset.centerLabelWrap
        centerRingOpacity = preset.centerRingOpacity
        hoverHighlightOpacity = preset.hoverHighlightOpacity
        centerFillOpacity = preset.centerFillOpacity
        fingersFillColorHex = preset.fingersFillColorHex
        fingersInactiveOpacity = preset.fingersInactiveOpacity
        fingersDimming = preset.fingersDimming
        fingersScale = preset.fingersScale
        bumpStyle = preset.bumpStyle
        bumpColorHex = preset.bumpColorHex
        bumpOpacity = preset.bumpOpacity
        bumpActiveScale = preset.bumpActiveScale
        bumpActiveOpacity = preset.bumpActiveOpacity
    }

    static let defaultPreset = AppearancePreset(
        primaryRadius: 160, iconSize: 92,
        centerDeadZone: 80,
        glowColorHex: "#DEE9F8", deepGlowColorHex: "#9966FF",
        ringColorHex: "#4D99FF", hoverColorHex: "#4D99FF",
        backgroundColorHex: "#000000", ringFillColorHex: "#FFFFFF",
        segmentBorderColorHex: "#FFFFFF",
        backgroundOpacity: 0.65, glowIntensity: 1.0,
        ringOpacity: 0.25, ringFillOpacity: 0.0,
        fingersFillOpacity: 0.25,
        segmentBorderOpacity: 0.0, segmentBorderWidth: 1.0,
        segmentBorderCutout: false,
        animateParentWedge: true, parentWedgeSlideDistance: 30,
        bumpStyle: "ring", bumpColorHex: "#FFFFFF", bumpOpacity: 0.55
    )

    static let overwatchPreset = AppearancePreset(
        primaryRadius: 200, iconSize: 92,
        centerDeadZone: 150,
        glowColorHex: "#DEE9F8", deepGlowColorHex: "#9966FF",
        ringColorHex: "#E3F7F4", hoverColorHex: "#F4F7F7",
        backgroundColorHex: "#000000", ringFillColorHex: "#FFFFFF",
        segmentBorderColorHex: "#F0F6FF",
        backgroundOpacity: 0.65, glowIntensity: 1.0,
        ringOpacity: 0.0, ringFillOpacity: 0.0,
        fingersFillOpacity: 0.5,
        segmentBorderOpacity: 0.45, segmentBorderWidth: 2.5,
        segmentBorderCutout: false,
        animateParentWedge: true, parentWedgeSlideDistance: 30,
        bumpStyle: "icon", bumpColorHex: "#FFFFFF", bumpOpacity: 0.3
    )

    static let whiteRingSmallPreset = AppearancePreset(
        primaryRadius: 150, iconSize: 92,
        centerDeadZone: 90,
        glowColorHex: "#DEE9F8", deepGlowColorHex: "#9966FF",
        ringColorHex: "#E3F7F4", hoverColorHex: "#F4F7F7",
        backgroundColorHex: "#000000", ringFillColorHex: "#FFFFFF",
        segmentBorderColorHex: "#F0F6FF",
        backgroundOpacity: 0.65, glowIntensity: 1.0,
        ringOpacity: 0.0, ringFillOpacity: 0.3,
        fingersFillOpacity: 0.5,
        segmentBorderOpacity: 0.45, segmentBorderWidth: 2.5,
        segmentBorderCutout: true,
        animateParentWedge: true, parentWedgeSlideDistance: 30,
        bumpStyle: "icon", bumpColorHex: "#FFFFFF", bumpOpacity: 0.3
    )

    static let whiteRingPreset = AppearancePreset(
        primaryRadius: 200, iconSize: 92,
        centerDeadZone: 150,
        glowColorHex: "#DEE9F8", deepGlowColorHex: "#FF81FF",
        ringColorHex: "#E3F7F4", hoverColorHex: "#FF81FE",
        backgroundColorHex: "#000000", ringFillColorHex: "#FFFFFF",
        segmentBorderColorHex: "#F0F6FF",
        backgroundOpacity: 0.65, glowIntensity: 1.0,
        ringOpacity: 0.0, ringFillOpacity: 0.3,
        fingersFillOpacity: 0.5,
        segmentBorderOpacity: 0.45, segmentBorderWidth: 2.5,
        segmentBorderCutout: true,
        animateParentWedge: true, parentWedgeSlideDistance: 30,
        bumpStyle: "icon", bumpColorHex: "#FFFFFF", bumpOpacity: 0.3
    )

    static let claudeGeneratedPreset = AppearancePreset(
        primaryRadius: 175, iconSize: 92,
        centerDeadZone: 110,
        glowColorHex: "#66FFCC", deepGlowColorHex: "#33CCAA",
        ringColorHex: "#44DDBB", hoverColorHex: "#88FFE0",
        backgroundColorHex: "#000000", ringFillColorHex: "#66FFCC",
        segmentBorderColorHex: "#88FFE0",
        backgroundOpacity: 0.7, glowIntensity: 0.8,
        ringOpacity: 0.15, ringFillOpacity: 0.12,
        fingersFillOpacity: 0.4,
        segmentBorderOpacity: 0.35, segmentBorderWidth: 2.0,
        segmentBorderCutout: true,
        animateParentWedge: true, parentWedgeSlideDistance: 30,
        bumpStyle: "icon", bumpColorHex: "#66FFCC", bumpOpacity: 0.4
    )

    static let whiteoutPreset = AppearancePreset(
        primaryRadius: 175, iconSize: 92,
        centerDeadZone: 110,
        glowColorHex: "#AAAAAA", deepGlowColorHex: "#999999",
        ringColorHex: "#CCCCCC", hoverColorHex: "#888888",
        backgroundColorHex: "#FFFFFF", ringFillColorHex: "#000000",
        segmentBorderColorHex: "#AAAAAA",
        backgroundOpacity: 0.75, glowIntensity: 0.6,
        ringOpacity: 0.2, ringFillOpacity: 0.08,
        fingersFillOpacity: 0.3,
        segmentBorderOpacity: 0.3, segmentBorderWidth: 2.0,
        segmentBorderCutout: true,
        animateParentWedge: true, parentWedgeSlideDistance: 30,
        bumpStyle: "icon", bumpColorHex: "#777777", bumpOpacity: 0.5
    )

    static let builtInPresets: [NamedPreset] = [
        NamedPreset(name: "basic", preset: defaultPreset),
        NamedPreset(name: "overwatch", preset: overwatchPreset),
        NamedPreset(name: "white_ring_small", preset: whiteRingSmallPreset),
        NamedPreset(name: "white_ring_lrg", preset: whiteRingPreset),
        NamedPreset(name: "Claude-generated", preset: claudeGeneratedPreset),
        NamedPreset(name: "whiteout", preset: whiteoutPreset),
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
    var fingersFillOpacity: Double
    var segmentBorderOpacity: Double
    var segmentBorderWidth: Double
    var segmentBorderCutout: Bool
    var animateParentWedge: Bool
    var parentWedgeSlideDistance: Double
    var hoverRingSize: Double
    var hoverStrokeWidth: Double
    var hoverFillOpacity: Double
    var hoverIconScale: Double
    var hoverGlowRadius: Double
    var centerLabelEnabled: Bool
    var centerLabelFontSize: Double
    var centerLabelFontWeight: String
    var centerLabelFontDesign: String
    var centerLabelColorHex: String
    var centerLabelOpacity: Double
    var centerLabelMaxWidth: Double
    var centerLabelShadowRadius: Double
    var centerRingOpacity: Double
    var hoverHighlightOpacity: Double
    var centerFillOpacity: Double
    var fingersFillColorHex: String
    var fingersInactiveOpacity: Double
    var fingersDimming: Double
    var fingersScale: Double
    var centerLabelWrap: Bool
    var bumpStyle: String
    var bumpColorHex: String
    var bumpOpacity: Double
    var bumpActiveScale: Double
    var bumpActiveOpacity: Double

    init(primaryRadius: Double, iconSize: Double, centerDeadZone: Double,
         glowColorHex: String, deepGlowColorHex: String, ringColorHex: String, hoverColorHex: String,
         backgroundColorHex: String, ringFillColorHex: String, segmentBorderColorHex: String,
         backgroundOpacity: Double, glowIntensity: Double, ringOpacity: Double, ringFillOpacity: Double,
         fingersFillOpacity: Double,
         segmentBorderOpacity: Double, segmentBorderWidth: Double,
         segmentBorderCutout: Bool = false,
         animateParentWedge: Bool = true, parentWedgeSlideDistance: Double = 30,
         hoverRingSize: Double = 20, hoverStrokeWidth: Double = 2,
         hoverFillOpacity: Double = 0.2, hoverIconScale: Double = 1.2, hoverGlowRadius: Double = 15,
         centerLabelEnabled: Bool = true, centerLabelFontSize: Double = 14,
         centerLabelFontWeight: String = "semibold", centerLabelFontDesign: String = "rounded",
         centerLabelColorHex: String = "#FFFFFF", centerLabelOpacity: Double = 1.0,
         centerLabelMaxWidth: Double = 160, centerLabelShadowRadius: Double = 0,
         centerLabelWrap: Bool = false,
         centerRingOpacity: Double = 0.25, hoverHighlightOpacity: Double = 1.0,
         centerFillOpacity: Double = 0.0,
         fingersFillColorHex: String = "#FFFFFF", fingersInactiveOpacity: Double = 0.15,
         fingersDimming: Double = 0.4, fingersScale: Double = 1.0,
         bumpStyle: String = "ring", bumpColorHex: String = "#FFFFFF", bumpOpacity: Double = 0.55,
         bumpActiveScale: Double = 1.5, bumpActiveOpacity: Double = 1.0) {
        self.primaryRadius = primaryRadius; self.iconSize = iconSize
        self.centerDeadZone = centerDeadZone; self.glowColorHex = glowColorHex
        self.deepGlowColorHex = deepGlowColorHex; self.ringColorHex = ringColorHex
        self.hoverColorHex = hoverColorHex; self.backgroundColorHex = backgroundColorHex
        self.ringFillColorHex = ringFillColorHex; self.segmentBorderColorHex = segmentBorderColorHex
        self.backgroundOpacity = backgroundOpacity; self.glowIntensity = glowIntensity
        self.ringOpacity = ringOpacity; self.ringFillOpacity = ringFillOpacity
        self.fingersFillOpacity = fingersFillOpacity; self.segmentBorderOpacity = segmentBorderOpacity
        self.segmentBorderWidth = segmentBorderWidth; self.segmentBorderCutout = segmentBorderCutout
        self.animateParentWedge = animateParentWedge; self.parentWedgeSlideDistance = parentWedgeSlideDistance
        self.hoverRingSize = hoverRingSize; self.hoverStrokeWidth = hoverStrokeWidth
        self.hoverFillOpacity = hoverFillOpacity; self.hoverIconScale = hoverIconScale; self.hoverGlowRadius = hoverGlowRadius
        self.centerLabelEnabled = centerLabelEnabled; self.centerLabelFontSize = centerLabelFontSize
        self.centerLabelFontWeight = centerLabelFontWeight; self.centerLabelFontDesign = centerLabelFontDesign
        self.centerLabelColorHex = centerLabelColorHex; self.centerLabelOpacity = centerLabelOpacity
        self.centerLabelMaxWidth = centerLabelMaxWidth; self.centerLabelShadowRadius = centerLabelShadowRadius
        self.centerLabelWrap = centerLabelWrap
        self.centerRingOpacity = centerRingOpacity; self.hoverHighlightOpacity = hoverHighlightOpacity
        self.centerFillOpacity = centerFillOpacity
        self.fingersFillColorHex = fingersFillColorHex; self.fingersInactiveOpacity = fingersInactiveOpacity
        self.fingersDimming = fingersDimming; self.fingersScale = fingersScale
        self.bumpStyle = bumpStyle; self.bumpColorHex = bumpColorHex; self.bumpOpacity = bumpOpacity
        self.bumpActiveScale = bumpActiveScale; self.bumpActiveOpacity = bumpActiveOpacity
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = JazzHandsSettings.defaultPreset
        primaryRadius = (try? c.decode(Double.self, forKey: .primaryRadius)) ?? d.primaryRadius
        iconSize = (try? c.decode(Double.self, forKey: .iconSize)) ?? d.iconSize
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
        fingersFillOpacity = (try? c.decode(Double.self, forKey: .fingersFillOpacity)) ?? d.fingersFillOpacity
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
        hoverRingSize = (try? c.decode(Double.self, forKey: .hoverRingSize)) ?? d.hoverRingSize
        hoverStrokeWidth = (try? c.decode(Double.self, forKey: .hoverStrokeWidth)) ?? d.hoverStrokeWidth
        hoverFillOpacity = (try? c.decode(Double.self, forKey: .hoverFillOpacity)) ?? d.hoverFillOpacity
        hoverIconScale = (try? c.decode(Double.self, forKey: .hoverIconScale)) ?? d.hoverIconScale
        hoverGlowRadius = (try? c.decode(Double.self, forKey: .hoverGlowRadius)) ?? d.hoverGlowRadius
        centerLabelEnabled = (try? c.decode(Bool.self, forKey: .centerLabelEnabled)) ?? d.centerLabelEnabled
        centerLabelFontSize = (try? c.decode(Double.self, forKey: .centerLabelFontSize)) ?? d.centerLabelFontSize
        centerLabelFontWeight = (try? c.decode(String.self, forKey: .centerLabelFontWeight)) ?? d.centerLabelFontWeight
        centerLabelFontDesign = (try? c.decode(String.self, forKey: .centerLabelFontDesign)) ?? d.centerLabelFontDesign
        centerLabelColorHex = (try? c.decode(String.self, forKey: .centerLabelColorHex)) ?? d.centerLabelColorHex
        centerLabelOpacity = (try? c.decode(Double.self, forKey: .centerLabelOpacity)) ?? d.centerLabelOpacity
        centerLabelMaxWidth = (try? c.decode(Double.self, forKey: .centerLabelMaxWidth)) ?? d.centerLabelMaxWidth
        centerLabelShadowRadius = (try? c.decode(Double.self, forKey: .centerLabelShadowRadius)) ?? d.centerLabelShadowRadius
        centerLabelWrap = (try? c.decode(Bool.self, forKey: .centerLabelWrap)) ?? d.centerLabelWrap
        centerRingOpacity = (try? c.decode(Double.self, forKey: .centerRingOpacity)) ?? d.centerRingOpacity
        hoverHighlightOpacity = (try? c.decode(Double.self, forKey: .hoverHighlightOpacity)) ?? d.hoverHighlightOpacity
        centerFillOpacity = (try? c.decode(Double.self, forKey: .centerFillOpacity)) ?? d.centerFillOpacity
        fingersFillColorHex = (try? c.decode(String.self, forKey: .fingersFillColorHex)) ?? d.fingersFillColorHex
        fingersInactiveOpacity = (try? c.decode(Double.self, forKey: .fingersInactiveOpacity)) ?? d.fingersInactiveOpacity
        fingersDimming = (try? c.decode(Double.self, forKey: .fingersDimming)) ?? d.fingersDimming
        fingersScale = (try? c.decode(Double.self, forKey: .fingersScale)) ?? d.fingersScale
        bumpStyle = (try? c.decode(String.self, forKey: .bumpStyle)) ?? d.bumpStyle
        bumpColorHex = (try? c.decode(String.self, forKey: .bumpColorHex)) ?? d.bumpColorHex
        bumpOpacity = (try? c.decode(Double.self, forKey: .bumpOpacity)) ?? d.bumpOpacity
        bumpActiveScale = (try? c.decode(Double.self, forKey: .bumpActiveScale)) ?? d.bumpActiveScale
        bumpActiveOpacity = (try? c.decode(Double.self, forKey: .bumpActiveOpacity)) ?? d.bumpActiveOpacity
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(primaryRadius, forKey: .primaryRadius)
        try c.encode(iconSize, forKey: .iconSize)
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
        try c.encode(fingersFillOpacity, forKey: .fingersFillOpacity)
        try c.encode(segmentBorderOpacity, forKey: .segmentBorderOpacity)
        try c.encode(segmentBorderWidth, forKey: .segmentBorderWidth)
        try c.encode(segmentBorderCutout, forKey: .segmentBorderCutout)
        try c.encode(animateParentWedge, forKey: .animateParentWedge)
        try c.encode(parentWedgeSlideDistance, forKey: .parentWedgeSlideDistance)
        try c.encode(hoverRingSize, forKey: .hoverRingSize)
        try c.encode(hoverStrokeWidth, forKey: .hoverStrokeWidth)
        try c.encode(hoverFillOpacity, forKey: .hoverFillOpacity)
        try c.encode(hoverIconScale, forKey: .hoverIconScale)
        try c.encode(hoverGlowRadius, forKey: .hoverGlowRadius)
        try c.encode(centerLabelEnabled, forKey: .centerLabelEnabled)
        try c.encode(centerLabelFontSize, forKey: .centerLabelFontSize)
        try c.encode(centerLabelFontWeight, forKey: .centerLabelFontWeight)
        try c.encode(centerLabelFontDesign, forKey: .centerLabelFontDesign)
        try c.encode(centerLabelColorHex, forKey: .centerLabelColorHex)
        try c.encode(centerLabelOpacity, forKey: .centerLabelOpacity)
        try c.encode(centerLabelMaxWidth, forKey: .centerLabelMaxWidth)
        try c.encode(centerLabelShadowRadius, forKey: .centerLabelShadowRadius)
        try c.encode(centerLabelWrap, forKey: .centerLabelWrap)
        try c.encode(centerRingOpacity, forKey: .centerRingOpacity)
        try c.encode(hoverHighlightOpacity, forKey: .hoverHighlightOpacity)
        try c.encode(centerFillOpacity, forKey: .centerFillOpacity)
        try c.encode(fingersFillColorHex, forKey: .fingersFillColorHex)
        try c.encode(fingersInactiveOpacity, forKey: .fingersInactiveOpacity)
        try c.encode(fingersDimming, forKey: .fingersDimming)
        try c.encode(fingersScale, forKey: .fingersScale)
        try c.encode(bumpStyle, forKey: .bumpStyle)
        try c.encode(bumpColorHex, forKey: .bumpColorHex)
        try c.encode(bumpOpacity, forKey: .bumpOpacity)
        try c.encode(bumpActiveScale, forKey: .bumpActiveScale)
        try c.encode(bumpActiveOpacity, forKey: .bumpActiveOpacity)
    }

    private enum CodingKeys: String, CodingKey {
        case primaryRadius, iconSize, centerDeadZone
        case glowColorHex, deepGlowColorHex, ringColorHex, hoverColorHex
        case backgroundColorHex, ringFillColorHex, segmentBorderColorHex
        case backgroundOpacity, glowIntensity, ringOpacity, ringFillOpacity
        case centerRingOpacity, hoverHighlightOpacity, centerFillOpacity
        case fingersFillOpacity, fingersFillColorHex, fingersInactiveOpacity
        case fingersDimming, fingersScale
        case segmentBorderOpacity, segmentBorderWidth, segmentBorderCutout
        case animateParentWedge, parentWedgeSlideDistance
        case hoverRingSize, hoverStrokeWidth, hoverFillOpacity, hoverIconScale, hoverGlowRadius
        case centerLabelEnabled, centerLabelFontSize, centerLabelFontWeight, centerLabelFontDesign
        case centerLabelColorHex, centerLabelOpacity, centerLabelMaxWidth, centerLabelShadowRadius
        case centerLabelWrap
        case bumpStyle, bumpColorHex, bumpOpacity, bumpActiveScale, bumpActiveOpacity
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
