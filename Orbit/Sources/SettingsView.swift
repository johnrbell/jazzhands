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
                }

                sliderRow("Cursor sensitivity", value: $settings.cursorSensitivity,
                          range: 0.5...3.0, step: 0.1, format: { String(format: "%.1fx", $0) })
                sliderRow("Center dead zone", value: $settings.centerDeadZone,
                          range: 10...80, step: 5, format: { "\(Int($0))px" })
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
                    }

                    Section("Effects") {
                        sliderRow("Ring opacity", value: $settings.ringOpacity,
                                  range: 0...1, step: 0.05, format: { "\(Int($0 * 100))%" })
                        sliderRow("Background dimming", value: $settings.backgroundOpacity,
                                  range: 0...0.8, step: 0.05, format: { "\(Int($0 * 100))%" })
                        sliderRow("Glow intensity", value: $settings.glowIntensity,
                                  range: 0...2, step: 0.1, format: { "\(Int($0 * 100))%" })
                        sliderRow("Deep orbit fill", value: $settings.deepOrbitFillOpacity,
                                  range: 0...0.6, step: 0.05, format: { "\(Int($0 * 100))%" })
                    }

                    Button("Reset to Defaults") {
                        settings.glowColorHex = "#DEE9F8"
                        settings.deepGlowColorHex = "#9966FF"
                        settings.ringColorHex = "#4D99FF"
                        settings.hoverColorHex = "#4D99FF"
                        settings.backgroundColorHex = "#000000"
                        settings.ringOpacity = 0.25
                        settings.backgroundOpacity = 0.65
                        settings.glowIntensity = 1.0
                        settings.primaryRadius = 160
                        settings.iconSize = 92
                        settings.centerIconSize = 92
                        settings.deepOrbitFillOpacity = 0.25
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

    private struct PreviewParams {
        let center: CGPoint
        let radius: CGFloat
        let iconSz: CGFloat
        let innerR: CGFloat
        let outerR: CGFloat
        let parentAngle: Double
        let total: Int
        let deepAppIndex: Int
    }

    private static let previewApps: [(String, Color)] = [
        ("globe", .blue), ("safari", .cyan), ("doc.text", .orange),
        ("terminal", .green), ("music.note", .pink), ("gear", .gray),
        ("envelope.fill", .blue), ("photo", .teal),
    ]
    private static let previewWindowTitles = ["window a", "window b"]

    private var appearancePreview: some View {
        Canvas { context, size in
            let sc: CGFloat = 0.38
            let radius = CGFloat(settings.primaryRadius) * sc
            let iconSz = CGFloat(settings.iconSize) * sc
            let total = Self.previewApps.count
            let deepAppIndex = 1
            let p = PreviewParams(
                center: CGPoint(x: size.width / 2, y: size.height / 2),
                radius: radius, iconSz: iconSz,
                innerR: radius + 10,
                outerR: (CGFloat(settings.primaryRadius) + 200) * sc,
                parentAngle: (2.0 * .pi / Double(total)) * Double(deepAppIndex) - .pi / 2.0,
                total: total, deepAppIndex: deepAppIndex
            )
            drawPreviewWedges(&context, p: p)
            drawPreviewRing(&context, p: p)
            drawPreviewCancelButton(&context, p: p)
            drawPreviewIcons(&context, p: p)
        }
        .animation(.easeOut(duration: 0.2), value: settings.primaryRadius)
        .animation(.easeOut(duration: 0.2), value: settings.iconSize)
        .animation(.easeOut(duration: 0.2), value: settings.glowColorHex)
        .animation(.easeOut(duration: 0.2), value: settings.deepGlowColorHex)
        .animation(.easeOut(duration: 0.2), value: settings.hoverColorHex)
        .animation(.easeOut(duration: 0.2), value: settings.ringColorHex)
        .animation(.easeOut(duration: 0.2), value: settings.ringOpacity)
        .animation(.easeOut(duration: 0.2), value: settings.glowIntensity)
        .animation(.easeOut(duration: 0.2), value: settings.backgroundOpacity)
    }

    private func drawPreviewWedges(_ context: inout GraphicsContext, p: PreviewParams) {
        let spread: Double = 0.7
        let windowCount = Self.previewWindowTitles.count
        let totalSpread = spread * Double(windowCount - 1)

        for wi in 0..<windowCount {
            let wAngle = p.parentAngle - totalSpread / 2.0 + spread * Double(wi)
            let half = spread / 2.0
            let gap = 0.02
            var wedge = Path()
            wedge.addArc(center: p.center, radius: p.outerR,
                         startAngle: .radians(wAngle - half + gap),
                         endAngle: .radians(wAngle + half - gap), clockwise: false)
            wedge.addArc(center: p.center, radius: p.innerR,
                         startAngle: .radians(wAngle + half - gap),
                         endAngle: .radians(wAngle - half + gap), clockwise: true)
            wedge.closeSubpath()

            let isSel = wi == 0
            let hl = settings.deepGlowColor
            let fillC: Color = isSel ? hl.opacity(0.25) : Color.white.opacity(0.08)
            let strokeC: Color = isSel ? hl.opacity(0.9) : Color.white.opacity(0.15)
            context.fill(wedge, with: .color(fillC))
            context.stroke(wedge, with: .color(strokeC), lineWidth: isSel ? 3 : 1)

            drawPreviewThumb(&context, p: p, wAngle: wAngle, wi: wi)
            drawPreviewWedgeLabel(&context, p: p, wAngle: wAngle, wi: wi, isSel: isSel)

            if isSel {
                let dotR = p.innerR + (p.outerR - p.innerR) * 0.42
                let dp = CGPoint(x: p.center.x + dotR * CGFloat(cos(wAngle)),
                                 y: p.center.y + dotR * CGFloat(sin(wAngle)))
                let dotRect = CGRect(x: dp.x - 3, y: dp.y - 3, width: 6, height: 6)
                context.fill(Circle().path(in: dotRect), with: .color(.white.opacity(0.7)))
            }
        }
    }

    private func drawPreviewThumb(_ context: inout GraphicsContext, p: PreviewParams,
                                   wAngle: Double, wi: Int) {
        let depth = p.outerR - p.innerR
        let thumbR = p.innerR + depth * 0.62
        let thumbPos = CGPoint(x: p.center.x + thumbR * CGFloat(cos(wAngle)),
                                y: p.center.y + thumbR * CGFloat(sin(wAngle)))
        let thumbW: CGFloat = depth * 0.55
        let thumbH: CGFloat = thumbW * 0.65
        let rect = CGRect(x: -thumbW/2, y: -thumbH/2, width: thumbW, height: thumbH)

        var tc = context
        tc.translateBy(x: thumbPos.x, y: thumbPos.y)
        tc.rotate(by: .radians(wAngle + .pi / 2))
        tc.clip(to: RoundedRectangle(cornerRadius: 5).path(in: rect))

        if wi == 0 {
            tc.fill(Rectangle().path(in: rect), with: .color(Color(white: 0.10)))
            let widths: [CGFloat] = [0.75, 0.55, 0.85, 0.40, 0.65]
            for row in 0..<5 {
                let y = -thumbH/2 + 5 + CGFloat(row) * 7
                let lineRect = CGRect(x: -thumbW/2 + 5, y: y, width: widths[row] * thumbW, height: 3)
                tc.fill(Rectangle().path(in: lineRect), with: .color(Color.green.opacity(0.4)))
            }
        } else {
            tc.fill(Rectangle().path(in: rect), with: .color(Color(white: 0.88)))
            let headerRect = CGRect(x: -thumbW/2, y: -thumbH/2, width: thumbW, height: 8)
            tc.fill(Rectangle().path(in: headerRect), with: .color(Color(white: 0.75)))
            let b1 = CGRect(x: -thumbW/2 + 4, y: -thumbH/2 + 12,
                            width: thumbW * 0.5, height: thumbH * 0.55)
            tc.fill(RoundedRectangle(cornerRadius: 3).path(in: b1), with: .color(Color(white: 0.70)))
            let b2 = CGRect(x: 5, y: -thumbH/2 + 12,
                            width: thumbW * 0.35, height: thumbH * 0.35)
            tc.fill(RoundedRectangle(cornerRadius: 2).path(in: b2), with: .color(Color(white: 0.65)))
        }
    }

    private func drawPreviewWedgeLabel(_ context: inout GraphicsContext, p: PreviewParams,
                                        wAngle: Double, wi: Int, isSel: Bool) {
        let labelR = p.innerR + (p.outerR - p.innerR) * 0.20
        let labelPos = CGPoint(x: p.center.x + labelR * CGFloat(cos(wAngle)),
                                y: p.center.y + labelR * CGFloat(sin(wAngle)))
        let labelColor: Color = isSel ? .white : .white.opacity(0.7)
        var lc = context
        lc.translateBy(x: labelPos.x, y: labelPos.y)
        lc.rotate(by: .radians(wAngle + .pi / 2))
        lc.draw(
            Text(Self.previewWindowTitles[wi])
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(labelColor),
            at: .zero
        )
    }

    private func drawPreviewRing(_ context: inout GraphicsContext, p: PreviewParams) {
        let ringRect = CGRect(x: p.center.x - p.radius, y: p.center.y - p.radius,
                              width: p.radius * 2, height: p.radius * 2)
        context.stroke(Circle().path(in: ringRect),
                       with: .color(settings.ringColor.opacity(0.1)),
                       lineWidth: 1.5)
        let glowRect = CGRect(x: p.center.x - p.radius - 10, y: p.center.y - p.radius - 10,
                              width: (p.radius + 10) * 2, height: (p.radius + 10) * 2)
        context.fill(Circle().path(in: glowRect),
                     with: .color(settings.glowColor.opacity(0.05 * settings.glowIntensity)))
    }

    private func drawPreviewCancelButton(_ context: inout GraphicsContext, p: PreviewParams) {
        let xPos = p.center
        let sc: CGFloat = 0.38
        let sz: CGFloat = CGFloat(settings.centerIconSize) * sc
        let glowSz: CGFloat = sz + 14
        let glowRect = CGRect(x: xPos.x - glowSz/2, y: xPos.y - glowSz/2,
                               width: glowSz, height: glowSz)
        context.fill(Circle().path(in: glowRect),
                     with: .color(settings.glowColor.opacity(0.15 * settings.glowIntensity)))
        let rect = CGRect(x: xPos.x - sz/2, y: xPos.y - sz/2, width: sz, height: sz)
        context.fill(Circle().path(in: rect), with: .color(Color.white.opacity(0.10)))
        context.stroke(Circle().path(in: rect), with: .color(Color.white.opacity(0.25)), lineWidth: 1.5)
        context.draw(
            Text("\u{2715}").font(.system(size: sz * 0.4, weight: .semibold))
                .foregroundColor(.white.opacity(0.7)),
            at: xPos
        )
    }

    private func drawPreviewIcons(_ context: inout GraphicsContext, p: PreviewParams) {
        for i in 0..<p.total {
            let angle = (2.0 * .pi / Double(p.total)) * Double(i) - .pi / 2.0
            let pos = CGPoint(x: p.center.x + p.radius * CGFloat(cos(angle)),
                              y: p.center.y + p.radius * CGFloat(sin(angle)))
            let isParent = i == p.deepAppIndex

            if isParent {
                let bgSz = p.iconSz + 16
                let bgRect = CGRect(x: pos.x - bgSz/2, y: pos.y - bgSz/2,
                                    width: bgSz, height: bgSz)
                context.fill(Circle().path(in: bgRect), with: .color(Color.black.opacity(0.7)))
                context.stroke(Circle().path(in: bgRect),
                               with: .color(settings.hoverColor.opacity(0.8)), lineWidth: 2)
                context.draw(
                    Text(Image(systemName: Self.previewApps[i].0))
                        .font(.system(size: p.iconSz * 0.45))
                        .foregroundColor(Self.previewApps[i].1),
                    at: pos
                )
            } else {
                context.drawLayer { layerCtx in
                    layerCtx.opacity = 0.4
                    let bgSz = p.iconSz + 8
                    let bgRect = CGRect(x: pos.x - bgSz/2, y: pos.y - bgSz/2,
                                        width: bgSz, height: bgSz)
                    layerCtx.fill(Circle().path(in: bgRect), with: .color(Color(white: 0.10).opacity(0.55)))
                    layerCtx.draw(
                        Text(Image(systemName: Self.previewApps[i].0))
                            .font(.system(size: p.iconSz * 0.45))
                            .foregroundColor(Self.previewApps[i].1),
                        at: pos
                    )
                }
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
