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
        .frame(minWidth: 480, maxWidth: .infinity, minHeight: 520, maxHeight: .infinity)
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
                sliderRow("Cursor sensitivity", value: $settings.cursorSensitivity,
                          range: 0.5...3.0, step: 0.1, format: { String(format: "%.1fx", $0) })

                Picker("Cursor after release", selection: $settings.cursorRestoreMode) {
                    Text("Center of screen").tag("center")
                    Text("Where you started").tag("origin")
                    Text("Where you ended").tag("current")
                }

                Picker("App sort order", selection: $settings.appSortOrder) {
                    Text("Recently used").tag("recent")
                    Text("Alphabetical").tag("alphabetical")
                }

                Picker("Window sort order", selection: $settings.windowSortOrder) {
                    Text("Recently used").tag("recent")
                    Text("Alphabetical").tag("alphabetical")
                }

                Toggle("Enable deep orbit (multi-window expansion)", isOn: $settings.deepOrbitEnabled)

                if settings.deepOrbitEnabled {
                    sliderRow("Multi-window hover delay", value: $settings.hoverTimeout,
                              range: 0...1.0, step: 0.05, format: { "\(Int($0 * 1000))ms" })
                    Toggle("Switch deep orbit on hover", isOn: $settings.deepOrbitSwitchOnHover)
                    Text("Hovering a different app while in deep orbit switches after the delay")
                        .font(.caption).foregroundColor(.secondary)
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
                    Text("App Icon").tag("icon")
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
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                Form {
                    PresetsSection()

                    Section("Layout") {
                        sliderRow("Ring radius", value: $settings.primaryRadius,
                                  range: 80...250, step: 10, format: { "\(Int($0))px" })
                        sliderRow("Icon size", value: $settings.iconSize,
                                  range: 32...192, step: 4, format: { "\(Int($0))px" })
                        sliderRow("Center dead zone", value: $settings.centerDeadZone,
                                  range: 10...(settings.primaryRadius - settings.iconSize / 2),
                                  step: 5, format: { "\(Int($0))px" })
                    }

                    Section("Colors") {
                        colorRow("Background", hex: $settings.backgroundColorHex)
                        colorRow("Ring", hex: $settings.ringColorHex)
                        colorRow("Ring fill", hex: $settings.ringFillColorHex)
                        colorRow("Icon glow", hex: $settings.glowColorHex)
                        colorRow("Hover highlight", hex: $settings.hoverColorHex)
                        colorRow("Center label", hex: $settings.centerLabelColorHex)
                        colorRow("Segment borders", hex: $settings.segmentBorderColorHex)
                        colorRow("Window indicators", hex: $settings.bumpColorHex)
                        colorRow("Deep orbit glow", hex: $settings.deepGlowColorHex)
                        colorRow("Deep orbit fill", hex: $settings.deepOrbitFillColorHex)
                    }

                    Button("Reset to Defaults") {
                        settings.applyPreset(OrbitSettings.defaultPreset)
                    }
                    .font(.caption)
                }
                .formStyle(.grouped)

                Form {
                    Section("Ring & Background") {
                        sliderRow("Background dimming", value: $settings.backgroundOpacity,
                                  range: 0...1, step: 0.01, format: { "\(Int($0 * 100))%" })
                        sliderRow("Glow intensity", value: $settings.glowIntensity,
                                  range: 0...5, step: 0.1, format: { "\(Int($0 * 100))%" })
                        sliderRow("Ring stroke opacity", value: $settings.ringOpacity,
                                  range: 0...1, step: 0.05, format: { "\(Int($0 * 100))%" })
                        sliderRow("Ring fill opacity", value: $settings.ringFillOpacity,
                                  range: 0...1, step: 0.01, format: { "\(Int($0 * 100))%" })
                        sliderRow("Center ring opacity", value: $settings.centerRingOpacity,
                                  range: 0...1, step: 0.05, format: { "\(Int($0 * 100))%" })
                    }

                    Section("Deep Orbit") {
                        sliderRow("Window arc scale", value: $settings.deepOrbitScale,
                                  range: 0.5...1.5, step: 0.05, format: { String(format: "%.0f%%", $0 * 100) })
                        sliderRow("Selected fill", value: $settings.deepOrbitFillOpacity,
                                  range: 0...1, step: 0.05, format: { "\(Int($0 * 100))%" })
                        sliderRow("Unselected fill", value: $settings.deepOrbitInactiveOpacity,
                                  range: 0...1, step: 0.05, format: { "\(Int($0 * 100))%" })
                        sliderRow("Primary ring dimming", value: $settings.deepOrbitDimming,
                                  range: 0...1, step: 0.05, format: { "\(Int($0 * 100))%" })
                        Toggle("Animate parent wedge", isOn: $settings.animateParentWedge)
                        if settings.animateParentWedge {
                            sliderRow("Slide distance", value: $settings.parentWedgeSlideDistance,
                                      range: 10...60, step: 5, format: { "\(Int($0))px" })
                        }
                    }

                    Section("Icon Hover") {
                        sliderRow("Opacity", value: $settings.hoverHighlightOpacity,
                                  range: 0...1, step: 0.05, format: { "\(Int($0 * 100))%" })
                        sliderRow("Fill opacity", value: $settings.hoverFillOpacity,
                                  range: 0...1, step: 0.05, format: { "\(Int($0 * 100))%" })
                        sliderRow("Ring size", value: $settings.hoverRingSize,
                                  range: 0...60, step: 2, format: { "\(Int($0))px" })
                        sliderRow("Stroke width", value: $settings.hoverStrokeWidth,
                                  range: 0...8, step: 0.5, format: { String(format: "%.1fpt", $0) })
                        sliderRow("Icon scale", value: $settings.hoverIconScale,
                                  range: 1.0...1.8, step: 0.05, format: { String(format: "%.2fx", $0) })
                        sliderRow("Glow radius", value: $settings.hoverGlowRadius,
                                  range: 0...50, step: 1, format: { "\(Int($0))px" })
                    }

                    Section("Center Label") {
                        Toggle("Show label", isOn: $settings.centerLabelEnabled)
                        Group {
                            sliderRow("Opacity", value: $settings.centerLabelOpacity,
                                      range: 0...1, step: 0.05, format: { "\(Int($0 * 100))%" })
                            sliderRow("Font size", value: $settings.centerLabelFontSize,
                                      range: 8...32, step: 1, format: { "\(Int($0))pt" })
                            Picker("Weight", selection: $settings.centerLabelFontWeight) {
                                Text("Ultralight").tag("ultralight")
                                Text("Thin").tag("thin")
                                Text("Light").tag("light")
                                Text("Regular").tag("regular")
                                Text("Medium").tag("medium")
                                Text("Semibold").tag("semibold")
                                Text("Bold").tag("bold")
                                Text("Heavy").tag("heavy")
                                Text("Black").tag("black")
                            }
                            Picker("Style", selection: $settings.centerLabelFontDesign) {
                                Text("Default").tag("default")
                                Text("Rounded").tag("rounded")
                                Text("Serif").tag("serif")
                                Text("Monospaced").tag("monospaced")
                            }
                            .pickerStyle(.segmented)
                            sliderRow("Max width", value: $settings.centerLabelMaxWidth,
                                      range: 60...400, step: 10, format: { "\(Int($0))px" })
                            Picker("Overflow", selection: $settings.centerLabelWrap) {
                                Text("Truncate").tag(false)
                                Text("Wrap").tag(true)
                            }
                            .pickerStyle(.segmented)
                            sliderRow("Shadow", value: $settings.centerLabelShadowRadius,
                                      range: 0...20, step: 1, format: { "\(Int($0))px" })
                        }
                        .disabled(!settings.centerLabelEnabled)
                        .opacity(settings.centerLabelEnabled ? 1 : 0.4)
                    }

                    Section("Segment Borders") {
                        Toggle("Cutout style", isOn: $settings.segmentBorderCutout)
                        Text("Cut borders as negative space instead of drawing colored lines")
                            .font(.caption).foregroundColor(.secondary)
                        sliderRow("Width", value: $settings.segmentBorderWidth,
                                  range: 0.5...5, step: 0.5, format: { String(format: "%.1fpt", $0) })
                        sliderRow("Opacity", value: $settings.segmentBorderOpacity,
                                  range: 0...1, step: 0.05, format: { "\(Int($0 * 100))%" })
                            .disabled(settings.segmentBorderCutout)
                            .opacity(settings.segmentBorderCutout ? 0.4 : 1)
                    }

                    Section("Window Indicators") {
                        Picker("Position", selection: $settings.bumpStyle) {
                            Text("Outer edge").tag("ring")
                            Text("Below icon").tag("icon")
                        }
                        .pickerStyle(.segmented)
                        sliderRow("Opacity", value: $settings.bumpOpacity,
                                  range: 0...1, step: 0.05, format: { "\(Int($0 * 100))%" })
                        sliderRow("Active scale", value: $settings.bumpActiveScale,
                                  range: 1.0...3.0, step: 0.1, format: { String(format: "%.1fx", $0) })
                        sliderRow("Active opacity", value: $settings.bumpActiveOpacity,
                                  range: 0...1, step: 0.05, format: { "\(Int($0 * 100))%" })
                    }
                }
                .formStyle(.grouped)
            }
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

