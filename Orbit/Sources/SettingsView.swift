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
        .frame(width: 480, height: 520)
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
                    Toggle("Animate parent wedge", isOn: $settings.animateParentWedge)
                    if settings.animateParentWedge {
                        sliderRow("Slide distance", value: $settings.parentWedgeSlideDistance,
                                  range: 10...60, step: 5, format: { "\(Int($0))px" })
                    }
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

            Section("Menu Bar") {
                Picker("Menu bar icon", selection: $settings.menuBarStyle) {
                    Text("Jazz Hand").tag("hand")
                    Text("Orbit Ring").tag("orbit")
                    Text("Hidden").tag("hidden")
                }
                .onChange(of: settings.menuBarStyle) { _ in
                    AppDelegate.shared?.updateStatusBar()
                }
                if settings.menuBarStyle == "hidden" {
                    Text("Re-launch JazzHands.app to open settings.")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Appearance

    private var appearanceTab: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Text("Use your shortcut (\(settings.shortcutDisplayName)) to preview changes live.")
                            .font(.callout)
                        Text("No in-app preview yet. It sucks, we know. 🤷")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }

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
                          range: 0...1, step: 0.01, format: { "\(Int($0 * 100))%" })
                sliderRow("Ring stroke opacity", value: $settings.ringOpacity,
                          range: 0...1, step: 0.05, format: { "\(Int($0 * 100))%" })
                sliderRow("Background dimming", value: $settings.backgroundOpacity,
                          range: 0...1, step: 0.01, format: { "\(Int($0 * 100))%" })
                sliderRow("Glow intensity", value: $settings.glowIntensity,
                          range: 0...2, step: 0.1, format: { "\(Int($0 * 100))%" })
                sliderRow("Deep orbit fill", value: $settings.deepOrbitFillOpacity,
                          range: 0...0.6, step: 0.05, format: { "\(Int($0 * 100))%" })
                sliderRow("Cancel button size", value: $settings.cancelButtonSize,
                          range: 24...128, step: 4, format: { "\(Int($0))px" })
                sliderRow("Cancel button opacity", value: $settings.cancelButtonOpacity,
                          range: 0...1, step: 0.05, format: { "\(Int($0 * 100))%" })
                Toggle("Segment border cutout", isOn: $settings.segmentBorderCutout)
                Text("Cut borders as negative space instead of drawing colored lines")
                    .font(.caption).foregroundColor(.secondary)
                colorRow("Segment border color", hex: $settings.segmentBorderColorHex)
                    .disabled(settings.segmentBorderCutout)
                    .opacity(settings.segmentBorderCutout ? 0.4 : 1)
                sliderRow("Segment border opacity", value: $settings.segmentBorderOpacity,
                          range: 0...1, step: 0.05, format: { "\(Int($0 * 100))%" })
                    .disabled(settings.segmentBorderCutout)
                    .opacity(settings.segmentBorderCutout ? 0.4 : 1)
                sliderRow("Segment border width", value: $settings.segmentBorderWidth,
                          range: 0.5...5, step: 0.5, format: { String(format: "%.1fpt", $0) })
                    .disabled(settings.segmentBorderCutout)
                    .opacity(settings.segmentBorderCutout ? 0.4 : 1)

                colorRow("Window indicator color", hex: $settings.bumpColorHex)
                sliderRow("Window indicator opacity", value: $settings.bumpOpacity,
                          range: 0...1, step: 0.05, format: { "\(Int($0 * 100))%" })
            }

            Button("Reset to Defaults") {
                settings.applyPreset(OrbitSettings.defaultPreset)
            }
            .font(.caption)
        }
        .formStyle(.grouped)
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

