import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = OrbitSettings.shared

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gear") }
            colorsTab
                .tabItem { Label("Colors", systemImage: "paintpalette") }
            appearanceTab
                .tabItem { Label("Layout", systemImage: "paintbrush") }
            advancedTab
                .tabItem { Label("Advanced", systemImage: "wrench") }
        }
        .frame(width: 460, height: 420)
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

                Picker("Key", selection: $settings.hotkeyKey) {
                    Text("Space").tag("space")
                    Text("Tab").tag("tab")
                    Text("Escape").tag("escape")
                    Text("Return").tag("return")
                }

                Text("Current: \(settings.shortcutDisplayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Behavior") {
                HStack {
                    Text("Multi-window hover delay")
                    Spacer()
                    Text("\(Int(settings.hoverTimeout * 1000))ms")
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $settings.hoverTimeout, in: 0.2...2.0, step: 0.1)

                HStack {
                    Text("Cursor sensitivity")
                    Spacer()
                    Text(String(format: "%.1fx", settings.cursorSensitivity))
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $settings.cursorSensitivity, in: 0.5...3.0, step: 0.1)
            }

            Section("Visibility") {
                Toggle("Show hidden apps", isOn: $settings.showHiddenApps)
                Text("Include apps hidden via ⌘H")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Show minimized windows", isOn: $settings.showMinimizedWindows)
                Text("Include minimized (dock) windows in app window lists")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Colors

    private var colorsTab: some View {
        Form {
            Section("Selection & Glow") {
                colorRow("Primary glow", hex: $settings.glowColorHex)
                colorRow("Deep orbit glow", hex: $settings.deepGlowColorHex)
                colorRow("Hover highlight", hex: $settings.hoverColorHex)
            }

            Section("Ring & Background") {
                colorRow("Ring color", hex: $settings.ringColorHex)
                colorRow("Background color", hex: $settings.backgroundColorHex)

                HStack {
                    Text("Ring opacity")
                    Spacer()
                    Text("\(Int(settings.ringOpacity * 100))%")
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $settings.ringOpacity, in: 0.0...1.0, step: 0.05)

                HStack {
                    Text("Background dimming")
                    Spacer()
                    Text("\(Int(settings.backgroundOpacity * 100))%")
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $settings.backgroundOpacity, in: 0.0...0.8, step: 0.05)
            }

            Section("Intensity") {
                HStack {
                    Text("Glow intensity")
                    Spacer()
                    Text(String(format: "%.0f%%", settings.glowIntensity * 100))
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $settings.glowIntensity, in: 0.0...2.0, step: 0.1)
            }

            Button("Reset Colors to Defaults") {
                settings.glowColorHex = "#4D99FF"
                settings.deepGlowColorHex = "#9966FF"
                settings.ringColorHex = "#4D99FF"
                settings.hoverColorHex = "#4D99FF"
                settings.backgroundColorHex = "#000000"
                settings.ringOpacity = 0.25
                settings.backgroundOpacity = 0.4
                settings.glowIntensity = 1.0
            }
            .font(.caption)
        }
        .formStyle(.grouped)
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

    // MARK: - Layout

    private var appearanceTab: some View {
        Form {
            Section("Layout") {
                HStack {
                    Text("Ring radius")
                    Spacer()
                    Text("\(Int(settings.primaryRadius))px")
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $settings.primaryRadius, in: 80...250, step: 10)

                HStack {
                    Text("Icon size")
                    Spacer()
                    Text("\(Int(settings.iconSize))px")
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $settings.iconSize, in: 32...72, step: 4)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Advanced

    private var advancedTab: some View {
        Form {
            Section("Debug") {
                Toggle("Show debug overlay", isOn: $settings.showDebugOverlay)

                HStack {
                    Text("Max cursor radius")
                    Spacer()
                    Text("\(Int(settings.maxCursorRadius))px")
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $settings.maxCursorRadius, in: 60...300, step: 10)
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
}
