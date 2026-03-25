import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = OrbitSettings.shared

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gear") }
            appearanceTab
                .tabItem { Label("Appearance", systemImage: "paintpalette") }
            advancedTab
                .tabItem { Label("Advanced", systemImage: "wrench") }
        }
        .frame(width: 680, height: 520)
        .padding()
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Section("Shortcut") {
                Picker("Modifier", selection: $settings.hotkeyModifier) {
                    Text("⌥ Option").tag("option")
                    Text("⌘ Command").tag("command")
                    Text("⌃ Control").tag("control")
                }
                .onChange(of: settings.hotkeyModifier) { _ in
                    AppDelegate.shared?.reinstallHotKey()
                }

                Picker("Key", selection: $settings.hotkeyKey) {
                    Text("Space").tag("space")
                    Text("Tab").tag("tab")
                    Text("Escape").tag("escape")
                    Text("Return").tag("return")
                }
                .onChange(of: settings.hotkeyKey) { _ in
                    AppDelegate.shared?.reinstallHotKey()
                }

                Text("Current: \(settings.shortcutDisplayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Behavior") {
                Toggle("Enable deep orbit (multi-window expansion)", isOn: $settings.deepOrbitEnabled)

                if settings.deepOrbitEnabled {
                    sliderRow("Multi-window hover delay", value: $settings.hoverTimeout,
                              range: 0.2...2.0, step: 0.1, format: { "\(Int($0 * 1000))ms" })
                    Toggle("Switch deep orbit on hover", isOn: $settings.deepOrbitSwitchOnHover)
                    Text("Hovering a different app icon while in deep orbit will switch to that app after the delay")
                        .font(.caption).foregroundColor(.secondary)
                }

                sliderRow("Cursor sensitivity", value: $settings.cursorSensitivity,
                          range: 0.5...3.0, step: 0.1, format: { String(format: "%.1fx", $0) })

                Picker("App sort order", selection: $settings.appSortOrder) {
                    Text("Recently used").tag("recent")
                    Text("Alphabetical").tag("alphabetical")
                }
            }

            Section("Visibility") {
                Toggle("Show hidden apps", isOn: $settings.showHiddenApps)
                Text("Include apps hidden via ⌘H")
                    .font(.caption).foregroundColor(.secondary)

                Toggle("Show minimized windows", isOn: $settings.showMinimizedWindows)
                Text("Include minimized (dock) windows in app window lists")
                    .font(.caption).foregroundColor(.secondary)

                Toggle("Hide Finder unless it has a window", isOn: $settings.hideFinderUnlessWindowed)
                Text("Finder is always running — hide it when no Finder windows are open")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Appearance (with live preview)

    private var appearanceTab: some View {
        HStack(spacing: 0) {
            ScrollView {
                Form {
                    PresetsSection()

                    Section("Colors") {
                        colorRow("Center icon glow", hex: $settings.glowColorHex)
                        colorRow("Deep orbit glow", hex: $settings.deepGlowColorHex)
                        colorRow("Hover highlight", hex: $settings.hoverColorHex)
                        colorRow("Ring color", hex: $settings.ringColorHex)
                        colorRow("Background", hex: $settings.backgroundColorHex)
                    }

                    Section("Layout") {
                        sliderRow("Ring radius", value: $settings.primaryRadius,
                                  range: 80...250, step: 10, format: { "\(Int($0))px" })
                        sliderRow("Icon size", value: $settings.iconSize,
                                  range: 32...192, step: 4, format: { "\(Int($0))px" })
                        sliderRow("Center icon size", value: $settings.centerIconSize,
                                  range: 24...128, step: 4, format: { "\(Int($0))px" })
                        sliderRow("Center dead zone", value: $settings.centerDeadZone,
                                  range: 10...(settings.primaryRadius - settings.iconSize / 2),
                                  step: 5, format: { "\(Int($0))px" })
                        Text("Also adjusts behavior — this value is shared with the General tab.")
                            .font(.caption).foregroundColor(.secondary)
                    }

                    Section("Effects") {
                        colorRow("Ring fill color", hex: $settings.ringFillColorHex)
                        sliderRow("Ring fill opacity", value: $settings.ringFillOpacity,
                                  range: 0...0.5, step: 0.02, format: { "\(Int($0 * 100))%" })
                        sliderRow("Ring stroke opacity", value: $settings.ringOpacity,
                                  range: 0...1, step: 0.05, format: { "\(Int($0 * 100))%" })
                        sliderRow("Background dimming", value: $settings.backgroundOpacity,
                                  range: 0...0.8, step: 0.05, format: { "\(Int($0 * 100))%" })
                        sliderRow("Glow intensity", value: $settings.glowIntensity,
                                  range: 0...2, step: 0.1, format: { "\(Int($0 * 100))%" })
                        sliderRow("Deep orbit fill", value: $settings.deepOrbitFillOpacity,
                                  range: 0...0.6, step: 0.05, format: { "\(Int($0 * 100))%" })
                        sliderRow("Cancel button size", value: $settings.cancelButtonSize,
                                  range: 24...128, step: 4, format: { "\(Int($0))px" })
                        sliderRow("Cancel button opacity", value: $settings.cancelButtonOpacity,
                                  range: 0...1, step: 0.05, format: { "\(Int($0 * 100))%" })
                        colorRow("Segment border color", hex: $settings.segmentBorderColorHex)
                        sliderRow("Segment border opacity", value: $settings.segmentBorderOpacity,
                                  range: 0...1, step: 0.05, format: { "\(Int($0 * 100))%" })
                        sliderRow("Segment border width", value: $settings.segmentBorderWidth,
                                  range: 0.5...5, step: 0.5, format: { String(format: "%.1fpt", $0) })
                    }

                    Button("Reset to Defaults") {
                        settings.applyPreset(OrbitSettings.defaultPreset)
                    }
                    .font(.caption)
                }
                .formStyle(.grouped)
            }
            .frame(width: 320)

            Divider()

            LivePreviewView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Advanced

    private var advancedTab: some View {
        Form {
            Section("Debug") {
                Toggle("Show debug overlay", isOn: $settings.showDebugOverlay)
            }

            Section("Permissions") {
                Button("Open Accessibility Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
                Button("Open Screen Recording Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Helpers

    private func sliderRow(_ label: String, value: Binding<Double>,
                           range: ClosedRange<Double>, step: Double,
                           format: @escaping (Double) -> String) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text(format(value.wrappedValue))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            Slider(value: value, in: range, step: step)
        }
    }

    private func colorRow(_ label: String, hex: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            ColorPicker("", selection: Binding<Color>(
                get: { Color(hex: hex.wrappedValue) },
                set: { hex.wrappedValue = $0.toHex() }
            ), supportsOpacity: false)
            .labelsHidden()
            .frame(width: 44)
        }
    }
}

// MARK: - Presets Section

private struct PresetsSection: View {
    @ObservedObject private var settings = OrbitSettings.shared
    @State private var presets: [NamedPreset] = []
    @State private var newPresetName = ""
    @State private var showingSaveField = false

    var body: some View {
        Section("Presets") {
            if presets.isEmpty && !showingSaveField {
                Text("No saved presets")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ForEach(presets) { preset in
                HStack {
                    Button(preset.name) {
                        settings.applyPreset(preset.preset)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button(role: .destructive) {
                        settings.deletePreset(name: preset.name)
                        presets = settings.savedPresets()
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
            }

            if showingSaveField {
                HStack(spacing: 6) {
                    TextField("Preset name", text: $newPresetName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { saveAndDismiss() }
                    Button("Save") { saveAndDismiss() }
                        .disabled(newPresetName.trimmingCharacters(in: .whitespaces).isEmpty)
                    Button("Cancel") {
                        showingSaveField = false
                        newPresetName = ""
                    }
                }
            } else {
                Button {
                    showingSaveField = true
                } label: {
                    Label("Save current as preset", systemImage: "plus")
                        .font(.caption)
                }
            }
        }
        .onAppear { presets = settings.savedPresets() }
    }

    private func saveAndDismiss() {
        let name = newPresetName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        settings.savePreset(name: name)
        presets = settings.savedPresets()
        newPresetName = ""
        showingSaveField = false
    }
}

// MARK: - Live Preview

private struct LivePreviewView: View {
    @StateObject private var viewModel = LivePreviewView.makePreviewViewModel()
    @ObservedObject private var settings = OrbitSettings.shared

    private static let sfSymbols = [
        "globe", "safari", "doc.text", "terminal", "music.note",
    ]

    static func makePreviewViewModel() -> OrbitViewModel {
        let vm = OrbitViewModel()
        vm.isVisible = true
        populateApps(vm)
        return vm
    }

    static func populateApps(_ vm: OrbitViewModel) {
        let currentApp = NSRunningApplication.current
        var fakeApps: [OrbitApp] = []

        for (i, symbol) in sfSymbols.enumerated() {
            let icon = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
                ?? NSImage(systemSymbolName: "app", accessibilityDescription: nil)!
            icon.size = NSSize(width: 48, height: 48)

            let windowCount = (i == 1) ? 3 : 1
            let windows = (0..<windowCount).map { wi in
                OrbitWindow(
                    id: CGWindowID(1000 + i * 10 + wi),
                    title: "Window \(wi + 1)",
                    bounds: .zero,
                    ownerPID: pid_t(9000 + i),
                    isOnScreen: true
                )
            }

            fakeApps.append(OrbitApp(
                id: pid_t(9000 + i),
                name: symbol.capitalized,
                bundleIdentifier: "com.preview.\(symbol)",
                icon: icon,
                runningApp: currentApp,
                windows: windows
            ))
        }

        vm.apps = fakeApps
        vm.selectedIndex = 0
        vm.centerLabel = fakeApps[0].name
    }

    var body: some View {
        GeometryReader { geo in
            let neededSize = (CGFloat(settings.primaryRadius) + CGFloat(settings.iconSize)) * 2 + 40
            let scale = min(geo.size.width / neededSize, geo.size.height / neededSize, 1.0)

            OrbitView(viewModel: viewModel)
                .frame(width: neededSize, height: neededSize)
                .scaleEffect(scale)
                .frame(width: geo.size.width, height: geo.size.height)
                .background(settings.backgroundColor.opacity(settings.backgroundOpacity))
        }
        .clipped()
        .onChange(of: settings.primaryRadius) { _ in refreshPreview() }
        .onChange(of: settings.iconSize) { _ in refreshPreview() }
        .onChange(of: settings.centerIconSize) { _ in refreshPreview() }
        .onChange(of: settings.centerDeadZone) { _ in refreshPreview() }
        .onChange(of: settings.deepOrbitEnabled) { _ in refreshPreview() }
    }

    private func refreshPreview() {
        Self.populateApps(viewModel)
    }
}
