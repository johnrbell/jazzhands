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
                            primaryRing
                            centerInfo
                            if case .deep(let appIndex) = viewModel.tier {
                                deepOrbitRing(appIndex: appIndex)
                            }
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
                    .frame(width: 56, height: 56)
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
                    .frame(width: 52, height: 52)

                Circle()
                    .fill(Color.white.opacity(hovered ? 0.18 : 0.06))
                    .frame(width: 52, height: 52)

                Circle()
                    .stroke(Color.white.opacity(hovered ? 0.6 : 0.25), lineWidth: hovered ? 2 : 1.5)
                    .frame(width: 52, height: 52)

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

                AppSegmentView(
                    app: app,
                    isSelected: isSelected,
                    glowColor: glowColor,
                    iconSize: viewModel.segmentIconSize
                )
                .offset(x: pos.x, y: pos.y)
                .opacity(dimmed ? 0.4 : 1.0)
                .animation(.easeOut(duration: 0.15), value: isSelected)
            }
        }
    }

    // MARK: - Deep Orbit (Local Arc)

    private func deepOrbitRing(appIndex: Int) -> some View {
        let windows = viewModel.deepOrbitWindows

        return ZStack {
            ForEach(Array(windows.enumerated()), id: \.element.id) { index, window in
                let isSelected = index == viewModel.selectedWindowIndex
                let icon = appIndex < viewModel.apps.count ? viewModel.apps[appIndex].icon : nil

                WindowArcSegment(
                    window: window,
                    thumbnail: viewModel.windowThumbnails[window.id],
                    appIcon: icon,
                    isSelected: isSelected,
                    glowColor: deepGlowColor,
                    centerAngle: viewModel.deepOrbitAngle(windowIndex: index, appIndex: appIndex),
                    halfSpread: viewModel.deepOrbitSpread / 2.0,
                    innerRadius: viewModel.primaryRadius + 20,
                    outerRadius: viewModel.deepOrbitRadius + 50
                )
                .animation(.easeOut(duration: 0.15), value: isSelected)
            }
        }
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

    private var s: OrbitSettings { OrbitSettings.shared }

    var body: some View {
        ZStack {
            if isSelected {
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

    private var arcPath: Path {
        let gap = 0.02
        let start = Angle.radians(centerAngle - halfSpread + gap)
        let end = Angle.radians(centerAngle + halfSpread - gap)
        var path = Path()
        path.addArc(center: .zero, radius: outerRadius, startAngle: start, endAngle: end, clockwise: false)
        path.addArc(center: .zero, radius: innerRadius, startAngle: end, endAngle: start, clockwise: true)
        path.closeSubpath()
        return path
    }

    private var midRadius: CGFloat { (innerRadius + outerRadius) / 2 }

    private var iconPos: CGPoint {
        CGPoint(
            x: midRadius * CGFloat(cos(centerAngle)),
            y: midRadius * CGFloat(sin(centerAngle))
        )
    }

    private var labelPos: CGPoint {
        let r = outerRadius + 14
        return CGPoint(
            x: r * CGFloat(cos(centerAngle)),
            y: r * CGFloat(sin(centerAngle))
        )
    }

    var body: some View {
        let highlight = s.deepGlowColor

        ZStack {
            arcPath
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)

            arcPath
                .fill(isSelected ? highlight.opacity(0.2) : Color.white.opacity(0.04))

            arcPath
                .stroke(isSelected ? highlight.opacity(0.7) : Color.white.opacity(0.2), lineWidth: isSelected ? 2 : 1)

            if let thumb = thumbnail {
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .offset(x: iconPos.x, y: iconPos.y)
            } else if let icon = appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .offset(x: iconPos.x, y: iconPos.y)
            }

            Text(window.title.isEmpty ? "Window" : String(window.title.prefix(16)))
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(isSelected ? 1.0 : 0.7))
                .lineLimit(1)
                .offset(x: labelPos.x, y: labelPos.y)
        }
        .shadow(color: isSelected ? highlight.opacity(0.4 * s.glowIntensity) : .black.opacity(0.2), radius: isSelected ? 10 : 4)
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
