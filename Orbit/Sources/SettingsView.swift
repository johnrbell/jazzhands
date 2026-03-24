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
                sliderRow("Multi-window hover delay", value: $settings.hoverTimeout,
                          range: 0.2...2.0, step: 0.1, format: { "\(Int($0 * 1000))ms" })
                sliderRow("Cursor sensitivity", value: $settings.cursorSensitivity,
                          range: 0.5...3.0, step: 0.1, format: { String(format: "%.1fx", $0) })
            }

            Section("Visibility") {
                Toggle("Show hidden apps", isOn: $settings.showHiddenApps)
                Text("Include apps hidden via ⌘H")
                    .font(.caption).foregroundColor(.secondary)

                Toggle("Show minimized windows", isOn: $settings.showMinimizedWindows)
                Text("Include minimized (dock) windows in app window lists")
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
                    Section("Colors") {
                        colorRow("Primary glow", hex: $settings.glowColorHex)
                        colorRow("Deep orbit glow", hex: $settings.deepGlowColorHex)
                        colorRow("Hover highlight", hex: $settings.hoverColorHex)
                        colorRow("Ring color", hex: $settings.ringColorHex)
                        colorRow("Background", hex: $settings.backgroundColorHex)
                    }

                    Section("Layout") {
                        sliderRow("Ring radius", value: $settings.primaryRadius,
                                  range: 80...250, step: 10, format: { "\(Int($0))px" })
                        sliderRow("Icon size", value: $settings.iconSize,
                                  range: 32...72, step: 4, format: { "\(Int($0))px" })
                    }

                    Section("Effects") {
                        sliderRow("Ring opacity", value: $settings.ringOpacity,
                                  range: 0...1, step: 0.05, format: { "\(Int($0 * 100))%" })
                        sliderRow("Background dimming", value: $settings.backgroundOpacity,
                                  range: 0...0.8, step: 0.05, format: { "\(Int($0 * 100))%" })
                        sliderRow("Glow intensity", value: $settings.glowIntensity,
                                  range: 0...2, step: 0.1, format: { "\(Int($0 * 100))%" })
                    }

                    Button("Reset to Defaults") {
                        settings.glowColorHex = "#4D99FF"
                        settings.deepGlowColorHex = "#9966FF"
                        settings.ringColorHex = "#4D99FF"
                        settings.hoverColorHex = "#4D99FF"
                        settings.backgroundColorHex = "#000000"
                        settings.ringOpacity = 0.25
                        settings.backgroundOpacity = 0.4
                        settings.glowIntensity = 1.0
                        settings.primaryRadius = 140
                        settings.iconSize = 48
                    }
                    .font(.caption)
                }
                .formStyle(.grouped)
            }
            .frame(width: 320)

            Divider()

            appearancePreview
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(settings.backgroundColor.opacity(settings.backgroundOpacity))
        }
    }

    // MARK: - Live Preview

    private var appearancePreview: some View {
        let radius = CGFloat(settings.primaryRadius) * 0.55
        let iconSz = CGFloat(settings.iconSize) * 0.6
        let sampleApps: [(String, Color)] = [
            ("globe", .blue), ("safari", .cyan), ("envelope", .orange),
            ("terminal", .green), ("music.note", .pink), ("gear", .gray),
        ]
        let total = sampleApps.count

        return ZStack {
            Circle()
                .stroke(settings.ringColor.opacity(settings.ringOpacity), lineWidth: 1.5)
                .frame(width: radius * 2, height: radius * 2)
                .shadow(color: settings.glowColor.opacity(0.15 * settings.glowIntensity), radius: 12)

            ForEach(0..<total, id: \.self) { i in
                let angle = (2.0 * Double.pi / Double(total)) * Double(i) - Double.pi / 2.0
                let x = radius * CGFloat(cos(angle))
                let y = radius * CGFloat(sin(angle))
                let selected = i == 0

                ZStack {
                    if selected {
                        Circle()
                            .fill(settings.hoverColor.opacity(0.2))
                            .frame(width: iconSz + 14, height: iconSz + 14)

                        Circle()
                            .stroke(settings.hoverColor.opacity(0.6), lineWidth: 1.5)
                            .frame(width: iconSz + 14, height: iconSz + 14)
                    }

                    Image(systemName: sampleApps[i].0)
                        .font(.system(size: iconSz * 0.5))
                        .foregroundColor(sampleApps[i].1)
                        .frame(width: iconSz, height: iconSz)
                        .scaleEffect(selected ? 1.15 : 1.0)
                }
                .offset(x: x, y: y)
            }

            Text("Preview")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
        }
        .animation(.easeOut(duration: 0.2), value: settings.primaryRadius)
        .animation(.easeOut(duration: 0.2), value: settings.iconSize)
        .animation(.easeOut(duration: 0.2), value: settings.glowColorHex)
        .animation(.easeOut(duration: 0.2), value: settings.hoverColorHex)
        .animation(.easeOut(duration: 0.2), value: settings.ringColorHex)
        .animation(.easeOut(duration: 0.2), value: settings.ringOpacity)
        .animation(.easeOut(duration: 0.2), value: settings.glowIntensity)
    }

    // MARK: - Advanced

    private var advancedTab: some View {
        Form {
            Section("Debug") {
                Toggle("Show debug overlay", isOn: $settings.showDebugOverlay)

                sliderRow("Max cursor radius", value: $settings.maxCursorRadius,
                          range: 60...300, step: 10, format: { "\(Int($0))px" })
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
