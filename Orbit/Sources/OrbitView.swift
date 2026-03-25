import SwiftUI

struct OrbitView: View {
    @ObservedObject var viewModel: OrbitViewModel

    private var s: OrbitSettings { OrbitSettings.shared }
    private var glowColor: Color { s.glowColor }
    private var deepGlowColor: Color { s.deepGlowColor }

    var body: some View {
        ZStack {
            backgroundBlur

            if viewModel.isVisible {
                GeometryReader { geo in
                    let cx = geo.size.width / 2
                    let cy = geo.size.height / 2

                    ZStack {
                        if viewModel.showDebug {
                            DebugCanvasView(viewModel: viewModel)
                        }
                        ZStack {
                            if case .deep(let appIndex) = viewModel.tier {
                                deepOrbitRing(appIndex: appIndex)
                            }
                            primaryRing
                            centerInfo
                            cursorIndicator
                        }
                        .position(x: cx, y: cy)
                        if viewModel.showDebug {
                            debugInfoText.position(x: 120, y: cy - 220)
                        }
                    }
                }
                .transition(.scale(scale: 0.8).combined(with: .opacity))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.isVisible)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Background

    private var backgroundBlur: some View {
        s.backgroundColor.opacity(viewModel.isVisible ? s.backgroundOpacity : 0)
            .animation(.easeInOut(duration: 0.2), value: viewModel.isVisible)
    }

    // MARK: - Center Info

    private var centerInfo: some View {
        VStack(spacing: 6) {
            if viewModel.isInDeepOrbit {
                cancelButton
            } else if viewModel.selectedIndex >= 0,
                      viewModel.selectedIndex < viewModel.apps.count {
                Image(nsImage: viewModel.apps[viewModel.selectedIndex].icon)
                    .resizable()
                    .frame(width: CGFloat(s.centerIconSize), height: CGFloat(s.centerIconSize))
                    .shadow(color: glowColor.opacity(0.6), radius: 12)
            }

            Text(viewModel.centerLabel)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(maxWidth: 160)
        }
        .animation(.easeOut(duration: 0.15), value: viewModel.selectedIndex)
        .animation(.easeOut(duration: 0.15), value: viewModel.isInDeepOrbit)
    }

    @ViewBuilder
    private var cancelButton: some View {
        let hovered = viewModel.isCancelHovered
        Button(action: {
            viewModel.cancelDeepOrbit()
        }) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .frame(width: CGFloat(s.centerIconSize), height: CGFloat(s.centerIconSize))

                Circle()
                    .fill(Color.white.opacity(hovered ? 0.18 : 0.06))
                    .frame(width: CGFloat(s.centerIconSize), height: CGFloat(s.centerIconSize))

                Circle()
                    .stroke(Color.white.opacity(hovered ? 0.6 : 0.25), lineWidth: hovered ? 2 : 1.5)
                    .frame(width: CGFloat(s.centerIconSize), height: CGFloat(s.centerIconSize))

                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(hovered ? 1.0 : 0.7))
            }
            .scaleEffect(hovered ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
        .shadow(color: hovered ? .white.opacity(0.15) : .black.opacity(0.4), radius: hovered ? 12 : 8)
        .animation(.easeOut(duration: 0.12), value: hovered)
        .transition(.scale(scale: 0.5).combined(with: .opacity))
    }

    // MARK: - Cursor Indicator

    private var cursorIndicator: some View {
        let pos = viewModel.debugCursorPos
        return Circle()
            .fill(Color.white.opacity(0.5))
            .frame(width: 10, height: 10)
            .shadow(color: .white.opacity(0.4), radius: 4)
            .offset(x: pos.x, y: pos.y)
            .allowsHitTesting(false)
    }

    // MARK: - Primary Ring

    private var primaryRing: some View {
        let apps = viewModel.apps
        let total = apps.count
        let dimmed = {
            if case .deep = viewModel.tier { return true }
            return false
        }()

        return ZStack {
            orbitTrackRing(radius: viewModel.primaryRadius, color: glowColor, dimmed: dimmed)

            ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
                let pos = viewModel.positionForSegment(at: index, total: total, radius: viewModel.primaryRadius)
                let isSelected = index == viewModel.selectedIndex
                let isDeepParent = dimmed && isSelected

                AppSegmentView(
                    app: app,
                    isSelected: isSelected,
                    glowColor: glowColor,
                    iconSize: viewModel.segmentIconSize,
                    showBackground: isDeepParent,
                    windowCount: app.windows.count
                )
                .offset(x: pos.x, y: pos.y)
                .opacity(dimmed && !isDeepParent ? 0.4 : 1.0)
                .animation(.easeOut(duration: 0.15), value: isSelected)
            }
        }
    }

    // MARK: - Deep Orbit (Local Arc)

    private func deepOrbitRing(appIndex: Int) -> some View {
        let windows = viewModel.deepOrbitWindows
        let innerR = viewModel.primaryRadius + 15
        let outerR = viewModel.deepOrbitOuterRadius

        return Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let highlight = s.deepGlowColor

            for (index, window) in windows.enumerated() {
                let isSelected = index == viewModel.selectedWindowIndex
                let angle = viewModel.deepOrbitAngle(windowIndex: index, appIndex: appIndex)
                let half = viewModel.deepOrbitSpread / 2.0
                let gap = 0.015
                let startA = Angle.radians(angle - half + gap)
                let endA = Angle.radians(angle + half - gap)

                var wedge = Path()
                wedge.addArc(center: center, radius: outerR, startAngle: startA, endAngle: endA, clockwise: false)
                wedge.addArc(center: center, radius: innerR, startAngle: endA, endAngle: startA, clockwise: true)
                wedge.closeSubpath()

                let baseOpacity = s.deepOrbitFillOpacity
                let fillColor = isSelected ? highlight.opacity(baseOpacity) : Color.white.opacity(baseOpacity * 0.32)
                context.fill(wedge, with: .color(fillColor))

                let strokeColor = isSelected ? highlight.opacity(min(baseOpacity * 3.6, 1.0)) : Color.white.opacity(baseOpacity * 0.6)
                context.stroke(wedge, with: .color(strokeColor), lineWidth: isSelected ? 3 : 1)

                let midR = innerR + (outerR - innerR) * 0.62
                let thumbPos = CGPoint(
                    x: center.x + midR * CGFloat(cos(angle)),
                    y: center.y + midR * CGFloat(sin(angle))
                )

                let wedgeWidth = outerR - innerR
                let thumbW: CGFloat = wedgeWidth * 0.55
                let thumbH: CGFloat = wedgeWidth * 0.38

                if let thumb = viewModel.windowThumbnails[window.id] {
                    let img = Image(nsImage: thumb)
                    var thumbCtx = context
                    thumbCtx.translateBy(x: thumbPos.x, y: thumbPos.y)
                    thumbCtx.rotate(by: .radians(angle + .pi / 2))
                    thumbCtx.clip(to: RoundedRectangle(cornerRadius: 6).path(in: CGRect(x: -thumbW/2, y: -thumbH/2, width: thumbW, height: thumbH)))
                    thumbCtx.draw(img, in: CGRect(x: -thumbW/2, y: -thumbH/2, width: thumbW, height: thumbH))
                } else if let icon = (appIndex < viewModel.apps.count ? viewModel.apps[appIndex].icon : nil) {
                    let img = Image(nsImage: icon)
                    context.draw(img, in: CGRect(x: thumbPos.x - 18, y: thumbPos.y - 18, width: 36, height: 36))
                }

                let labelR = innerR + (outerR - innerR) * 0.18
                let labelPos = CGPoint(
                    x: center.x + labelR * CGFloat(cos(angle)),
                    y: center.y + labelR * CGFloat(sin(angle))
                )
                let title = window.title.isEmpty ? "Window" : String(window.title.prefix(20))
                let labelColor: Color = isSelected ? .white : .white.opacity(0.7)
                var labelCtx = context
                labelCtx.translateBy(x: labelPos.x, y: labelPos.y)
                labelCtx.rotate(by: .radians(angle + .pi / 2))
                labelCtx.draw(
                    Text(title)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(labelColor),
                    at: .zero
                )
            }
        }
        .allowsHitTesting(false)
        .transition(.opacity)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.tier == .primary)
    }

    // MARK: - Debug Info

    private var debugInfoText: some View {
        let angleDeg = viewModel.mouseAngle * 180.0 / Double.pi
        return VStack(alignment: .leading, spacing: 2) {
            Text(String(format: "angle: %.1f°", angleDeg))
            Text(String(format: "dist: %.1f", viewModel.mouseDistance))
            Text("seg: \(viewModel.selectedIndex)")
            Text(String(format: "cursor: (%.0f, %.0f)", viewModel.debugCursorPos.x, viewModel.debugCursorPos.y))
            Text("apps: \(viewModel.apps.count)")
        }
        .font(.system(size: 11, weight: .medium, design: .monospaced))
        .foregroundColor(Color.green.opacity(0.8))
        .padding(8)
        .background(Color.black.opacity(0.5))
        .cornerRadius(6)
    }

    // MARK: - Track Ring

    private func orbitTrackRing(radius: CGFloat, color: Color, dimmed: Bool) -> some View {
        Circle()
            .stroke(s.ringColor.opacity(dimmed ? 0.1 : s.ringOpacity), lineWidth: 1.5)
            .frame(width: radius * 2, height: radius * 2)
            .shadow(color: color.opacity((dimmed ? 0.05 : 0.15) * s.glowIntensity), radius: 20)
    }
}

// MARK: - App Segment

struct AppSegmentView: View {
    let app: OrbitApp
    let isSelected: Bool
    let glowColor: Color
    let iconSize: CGFloat
    var showBackground: Bool = false
    var windowCount: Int = 1

    private var s: OrbitSettings { OrbitSettings.shared }

    private var bumpCount: Int {
        guard s.deepOrbitEnabled, windowCount > 1 else { return 0 }
        return min(windowCount, 5)
    }

    var body: some View {
        ZStack {
            if showBackground {
                Circle()
                    .fill(Color.black.opacity(0.7))
                    .frame(width: iconSize + 24, height: iconSize + 24)

                Circle()
                    .stroke(s.hoverColor.opacity(0.8), lineWidth: 2)
                    .frame(width: iconSize + 24, height: iconSize + 24)
            } else if isSelected {
                Circle()
                    .fill(s.hoverColor.opacity(0.2))
                    .frame(width: iconSize + 20, height: iconSize + 20)
                    .shadow(color: s.hoverColor.opacity(0.5 * s.glowIntensity), radius: 15)

                Circle()
                    .stroke(s.hoverColor.opacity(0.6), lineWidth: 2)
                    .frame(width: iconSize + 20, height: iconSize + 20)
            }

            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: iconSize, height: iconSize)
                .scaleEffect(isSelected ? 1.2 : 1.0)
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

            if bumpCount > 0 {
                multiWindowBumps
            }
        }
    }

    private var multiWindowBumps: some View {
        let edgeRadius = (iconSize / 2) + 6
        let bumpSize: CGFloat = 5
        let spacing = Angle.degrees(14)
        let baseAngle = Angle.degrees(90)

        return ForEach(0..<bumpCount, id: \.self) { i in
            let offset = Double(i) - Double(bumpCount - 1) / 2.0
            let angle = baseAngle + spacing * offset
            Circle()
                .fill(Color.white.opacity(isSelected ? 0.95 : 0.55))
                .frame(width: bumpSize, height: bumpSize)
                .shadow(color: glowColor.opacity(isSelected ? 0.7 : 0.3), radius: 3)
                .offset(
                    x: edgeRadius * CGFloat(cos(angle.radians)),
                    y: edgeRadius * CGFloat(sin(angle.radians))
                )
                .scaleEffect(isSelected ? 1.2 : 1.0)
        }
    }
}

// MARK: - Window Arc Segment

struct WindowArcSegment: View {
    let window: OrbitWindow
    let thumbnail: NSImage?
    let appIcon: NSImage?
    let isSelected: Bool
    let glowColor: Color
    let centerAngle: Double
    let halfSpread: Double
    let innerRadius: CGFloat
    let outerRadius: CGFloat

    private var s: OrbitSettings { OrbitSettings.shared }

    private var wedgePath: Path {
        let gap = 0.015
        let start = Angle.radians(centerAngle - halfSpread + gap)
        let end = Angle.radians(centerAngle + halfSpread - gap)
        var path = Path()
        path.addArc(center: .zero, radius: outerRadius, startAngle: start, endAngle: end, clockwise: false)
        path.addArc(center: .zero, radius: innerRadius, startAngle: end, endAngle: start, clockwise: true)
        path.closeSubpath()
        return path
    }

    private var previewCenter: CGPoint {
        let r = innerRadius + (outerRadius - innerRadius) * 0.62
        return CGPoint(
            x: r * CGFloat(cos(centerAngle)),
            y: r * CGFloat(sin(centerAngle))
        )
    }

    private var previewSize: CGSize {
        let wedgeWidth = outerRadius - innerRadius
        return CGSize(width: wedgeWidth * 0.55, height: wedgeWidth * 0.38)
    }

    private var labelPos: CGPoint {
        let r = innerRadius + (outerRadius - innerRadius) * 0.15
        return CGPoint(
            x: r * CGFloat(cos(centerAngle)),
            y: r * CGFloat(sin(centerAngle))
        )
    }

    private var rotationDegrees: Double {
        centerAngle * 180.0 / .pi + 90
    }

    var body: some View {
        let highlight = s.deepGlowColor

        ZStack {
            wedgePath
                .fill(isSelected ? highlight.opacity(0.25) : Color.white.opacity(0.08))

            wedgePath
                .stroke(isSelected ? highlight.opacity(0.9) : Color.white.opacity(0.15), lineWidth: isSelected ? 3 : 1)

            if let thumb = thumbnail {
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: previewSize.width, height: previewSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .rotationEffect(.degrees(rotationDegrees))
                    .offset(x: previewCenter.x, y: previewCenter.y)
                    .allowsHitTesting(false)
            } else if let icon = appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
                    .offset(x: previewCenter.x, y: previewCenter.y)
                    .allowsHitTesting(false)
            }

            Text(window.title.isEmpty ? "Window" : String(window.title.prefix(20)))
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(isSelected ? 1.0 : 0.7))
                .lineLimit(1)
                .rotationEffect(.degrees(rotationDegrees))
                .offset(x: labelPos.x, y: labelPos.y)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Debug Canvas

struct DebugCanvasView: View {
    @ObservedObject var viewModel: OrbitViewModel

    private static let sliceColors: [NSColor] = [
        .systemBlue, .systemPurple, .systemOrange, .systemTeal,
        .systemPink, .systemMint, .systemYellow, .systemIndigo,
        .systemCyan, .systemRed, .systemGreen, .systemBrown,
    ]

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let total = viewModel.apps.count
            guard total > 0 else { return }

            let outerRadius: CGFloat = viewModel.primaryRadius + 60
            let labelRadius: CGFloat = viewModel.primaryRadius + 40
            let segAngle = (2.0 * CGFloat.pi) / CGFloat(total)

            // Draw each pie slice
            for i in 0..<total {
                let startAngle = segAngle * CGFloat(i) - CGFloat.pi / 2.0 - segAngle / 2.0
                let endAngle = startAngle + segAngle
                let isSelected = i == viewModel.selectedIndex
                let baseColor = DebugCanvasView.sliceColors[i % DebugCanvasView.sliceColors.count]

                var slicePath = Path()
                slicePath.move(to: center)
                slicePath.addArc(center: center, radius: outerRadius,
                                 startAngle: .radians(Double(startAngle)),
                                 endAngle: .radians(Double(endAngle)),
                                 clockwise: false)
                slicePath.closeSubpath()

                let fillColor: Color = isSelected
                    ? Color.green.opacity(0.15)
                    : Color(nsColor: baseColor).opacity(0.08)
                context.fill(slicePath, with: .color(fillColor))

                let strokeColor: Color = isSelected
                    ? Color.green.opacity(0.6)
                    : Color(nsColor: baseColor).opacity(0.35)
                context.stroke(slicePath, with: .color(strokeColor),
                               lineWidth: isSelected ? 2 : 1)

                // Index label
                let midAngle = segAngle * CGFloat(i) - CGFloat.pi / 2.0
                let labelPt = CGPoint(
                    x: center.x + labelRadius * cos(midAngle),
                    y: center.y + labelRadius * sin(midAngle)
                )
                let labelColor: Color = isSelected ? .green : .white.opacity(0.5)
                context.draw(
                    Text("\(i)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(labelColor),
                    at: labelPt
                )
            }

            // Dead zone
            let dzRect = CGRect(
                x: center.x - viewModel.centerDeadZone,
                y: center.y - viewModel.centerDeadZone,
                width: viewModel.centerDeadZone * 2,
                height: viewModel.centerDeadZone * 2
            )
            context.fill(Path(ellipseIn: dzRect), with: .color(.black.opacity(0.3)))
            context.stroke(Path(ellipseIn: dzRect), with: .color(.red.opacity(0.5)), lineWidth: 1.5)

            // Max radius ring (dashed)
            let maxR: CGFloat = 120
            let maxRect = CGRect(
                x: center.x - maxR, y: center.y - maxR,
                width: maxR * 2, height: maxR * 2
            )
            context.stroke(Path(ellipseIn: maxRect),
                           with: .color(.red.opacity(0.2)),
                           style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

            // Cursor line
            let cursorEnd = CGPoint(
                x: center.x + viewModel.debugCursorPos.x,
                y: center.y + viewModel.debugCursorPos.y
            )
            var cursorLine = Path()
            cursorLine.move(to: center)
            cursorLine.addLine(to: cursorEnd)
            context.stroke(cursorLine, with: .color(.red.opacity(0.7)), lineWidth: 1.5)

            // Cursor dot
            let dotSize: CGFloat = 8
            let dotRect = CGRect(
                x: cursorEnd.x - dotSize / 2,
                y: cursorEnd.y - dotSize / 2,
                width: dotSize, height: dotSize
            )
            context.fill(Path(ellipseIn: dotRect), with: .color(.red))
        }
    }
}

extension OrbitTier: Equatable {
    static func == (lhs: OrbitTier, rhs: OrbitTier) -> Bool {
        switch (lhs, rhs) {
        case (.primary, .primary): return true
        case (.deep(let a), .deep(let b)): return a == b
        default: return false
        }
    }
}
