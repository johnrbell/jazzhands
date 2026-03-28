import SwiftUI

struct OrbitView: View {
    @ObservedObject var viewModel: OrbitViewModel

    private var s: OrbitSettings { OrbitSettings.shared }
    private var glowColor: Color { s.glowColor }
    private var deepGlowColor: Color { s.deepGlowColor }

    private func fontWeight(_ name: String) -> Font.Weight {
        switch name {
        case "ultralight": return .ultraLight
        case "thin": return .thin
        case "light": return .light
        case "regular": return .regular
        case "medium": return .medium
        case "semibold": return .semibold
        case "bold": return .bold
        case "heavy": return .heavy
        case "black": return .black
        default: return .semibold
        }
    }

    private func fontDesign(_ name: String) -> Font.Design {
        switch name {
        case "default": return .default
        case "rounded": return .rounded
        case "serif": return .serif
        case "monospaced": return .monospaced
        default: return .rounded
        }
    }

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
                            deepOrbitRing(appIndex: viewModel.deepOrbitDisplayAppIndex)
                                .opacity(Double(viewModel.deepOrbitOpacity))
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
        Group {
            if s.centerLabelEnabled {
                Text(viewModel.centerLabel)
                    .font(.system(size: CGFloat(s.centerLabelFontSize),
                                  weight: fontWeight(s.centerLabelFontWeight),
                                  design: fontDesign(s.centerLabelFontDesign)))
                    .foregroundColor(s.centerLabelColor.opacity(s.centerLabelOpacity))
                    .lineLimit(s.centerLabelWrap ? 3 : 1)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: CGFloat(s.centerLabelMaxWidth))
                    .shadow(color: s.centerLabelColor.opacity(s.centerLabelOpacity * 0.5),
                            radius: CGFloat(s.centerLabelShadowRadius))
            }
        }
        .animation(.easeOut(duration: 0.15), value: viewModel.selectedIndex)
        .animation(.easeOut(duration: 0.15), value: viewModel.isInDeepOrbit)
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
        let deepParentIndex: Int = {
            if case .deep(let idx) = viewModel.tier { return idx }
            return -1
        }()
        let dimmed = deepParentIndex >= 0
        let innerR = viewModel.centerDeadZone
        let outerR = viewModel.primaryRadius + viewModel.segmentIconSize / 2 + 10
        let iconRadius = (innerR + outerR) / 2

        return ZStack {
            orbitTrackRing(radius: viewModel.primaryRadius, color: glowColor, dimmed: dimmed, segmentCount: total, deepParentIndex: viewModel.slideAppIndex)

            if s.segmentBorderOpacity > 0, total > 0, !s.segmentBorderCutout {
                segmentBorders(total: total, radius: viewModel.primaryRadius, dimmed: dimmed)
            }

            ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
                let basePos = viewModel.positionForSegment(at: index, total: total, radius: iconRadius)
                let isSelected = index == viewModel.selectedIndex
                let isDeepParent = dimmed && isSelected
                let isSliding = index == viewModel.slideAppIndex
                let isReturning = index == viewModel.returnSlideAppIndex
                let slideVec: CGPoint = {
                    if isSliding { return viewModel.deepOrbitSlideVector(appIndex: index) }
                    if isReturning { return viewModel.returnSlideVector(appIndex: index) }
                    return .zero
                }()

                AppSegmentView(
                    app: app,
                    isSelected: isSelected,
                    glowColor: glowColor,
                    iconSize: viewModel.segmentIconSize,
                    showBackground: isDeepParent,
                    windowCount: app.windows.count,
                    segmentAngle: Angle(radians: viewModel.angleForSegment(at: index, total: total)),
                    activeWindowIndex: isDeepParent ? viewModel.selectedWindowIndex : -1
                )
                .opacity(dimmed && !isDeepParent ? s.deepOrbitDimming : 1.0)
                .animation(.easeOut(duration: 0.15), value: isSelected)
                .offset(x: basePos.x + slideVec.x, y: basePos.y + slideVec.y)
            }
        }
    }

    // MARK: - Deep Orbit (Local Arc)

    private func deepOrbitRing(appIndex: Int) -> some View {
        let windows = viewModel.deepOrbitWindows
        let innerR = viewModel.primaryRadius + viewModel.segmentIconSize / 2 + 17
        let outerR = viewModel.deepOrbitOuterRadius

        return Canvas { context, size in
            let slideVec = viewModel.deepOrbitTargetSlideVector(appIndex: appIndex)
            let center = CGPoint(x: size.width / 2 + slideVec.x, y: size.height / 2 + slideVec.y)
            let highlight = s.deepGlowColor

            for (index, window) in windows.enumerated() {
                let isSelected = index == viewModel.selectedWindowIndex
                let angle = viewModel.deepOrbitAngle(windowIndex: index, appIndex: appIndex)
                let half = viewModel.deepOrbitSpread / 2.0
                let gapPixels: Double = 3.0
                let gapOuter = gapPixels / Double(outerR)
                let gapInner = gapPixels / Double(innerR)

                var wedge = Path()
                wedge.addArc(center: center, radius: outerR,
                             startAngle: .radians(angle - half + gapOuter),
                             endAngle: .radians(angle + half - gapOuter),
                             clockwise: false)
                wedge.addArc(center: center, radius: innerR,
                             startAngle: .radians(angle + half - gapInner),
                             endAngle: .radians(angle - half + gapInner),
                             clockwise: true)
                wedge.closeSubpath()

                let baseOpacity = s.deepOrbitFillOpacity
                let fillColor = isSelected ? highlight.opacity(baseOpacity) : Color.white.opacity(baseOpacity * 0.32)
                context.fill(wedge, with: .color(fillColor))

                let strokeColor = isSelected ? highlight.opacity(min(baseOpacity * 3.6, 1.0)) : Color.white.opacity(baseOpacity * 0.6)
                context.stroke(wedge, with: .color(strokeColor), lineWidth: isSelected ? 3 : 1)

                let midR = innerR + (outerR - innerR) * 0.58
                let thumbPos = CGPoint(
                    x: center.x + midR * CGFloat(cos(angle)),
                    y: center.y + midR * CGFloat(sin(angle))
                )

                let wedgeWidth = outerR - innerR
                let thumbW: CGFloat = wedgeWidth * 0.78
                let thumbH: CGFloat = wedgeWidth * 0.54

                if let thumb = viewModel.windowThumbnails[window.id] {
                    let img = Image(nsImage: thumb)
                    let imgW = thumb.size.width
                    let imgH = thumb.size.height
                    var drawW = thumbW
                    var drawH = thumbH
                    if imgW > 0 && imgH > 0 {
                        let imgAspect = imgW / imgH
                        let boxAspect = thumbW / thumbH
                        if imgAspect > boxAspect {
                            drawH = thumbW / imgAspect
                        } else {
                            drawW = thumbH * imgAspect
                        }
                    }
                    let flipThumb: Double = sin(angle) > 0 ? .pi : 0
                    var thumbCtx = context
                    thumbCtx.translateBy(x: thumbPos.x, y: thumbPos.y)
                    thumbCtx.rotate(by: .radians(angle + .pi / 2 + flipThumb))
                    thumbCtx.clip(to: RoundedRectangle(cornerRadius: 6).path(in: CGRect(x: -drawW/2, y: -drawH/2, width: drawW, height: drawH)))
                    thumbCtx.draw(img, in: CGRect(x: -drawW/2, y: -drawH/2, width: drawW, height: drawH))
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
                let flipLabel: Double = sin(angle) > 0 ? .pi : 0
                var labelCtx = context
                labelCtx.translateBy(x: labelPos.x, y: labelPos.y)
                labelCtx.rotate(by: .radians(angle + .pi / 2 + flipLabel))
                labelCtx.draw(
                    Text(title)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(labelColor),
                    at: .zero
                )
            }
        }
        .allowsHitTesting(false)
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


    // MARK: - Segment Borders

    private func segmentBorders(total: Int, radius: CGFloat, dimmed: Bool) -> some View {
        let outerR = radius + viewModel.segmentIconSize / 2 + 10
        let segAngle = (2.0 * CGFloat.pi) / CGFloat(total)
        let opacity = dimmed ? s.segmentBorderOpacity * s.deepOrbitDimming : s.segmentBorderOpacity
        let diameter = outerR * 2 + 4

        return Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)

            let innerR = viewModel.centerDeadZone

            for i in 0..<total {
                let borderAngle = segAngle * CGFloat(i) - CGFloat.pi / 2.0 - segAngle / 2.0
                var line = Path()
                line.move(to: CGPoint(
                    x: center.x + innerR * cos(borderAngle),
                    y: center.y + innerR * sin(borderAngle)
                ))
                line.addLine(to: CGPoint(
                    x: center.x + outerR * cos(borderAngle),
                    y: center.y + outerR * sin(borderAngle)
                ))
                context.stroke(line,
                               with: .color(Color(hex: s.segmentBorderColorHex).opacity(opacity)),
                               lineWidth: CGFloat(s.segmentBorderWidth))
            }
        }
        .frame(width: diameter, height: diameter)
        .allowsHitTesting(false)
    }

    // MARK: - Track Ring

    private func orbitTrackRing(radius: CGFloat, color: Color, dimmed: Bool, segmentCount: Int = 0, deepParentIndex: Int = -1) -> some View {
        let innerR = viewModel.centerDeadZone
        let outerR = radius + viewModel.segmentIconSize / 2 + 10
        let fillOpacity = dimmed ? s.ringFillOpacity * s.deepOrbitDimming : s.ringFillOpacity
        let useCutout = s.segmentBorderCutout && segmentCount > 0 && s.segmentBorderOpacity > 0
        let slideOffset = viewModel.deepOrbitSlideOffset

        return ZStack {
            if useCutout {
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let segAngle = (2.0 * Double.pi) / Double(segmentCount)
                    let halfGapOuter = Double(s.segmentBorderWidth) / Double(outerR)
                    let halfGapInner = Double(s.segmentBorderWidth) / Double(innerR)

                    let returnIndex = viewModel.returnSlideAppIndex
                    let returnOffset = viewModel.returnSlideOffset

                    for i in 0..<segmentCount {
                        let baseAngle = segAngle * Double(i) - Double.pi / 2.0 - segAngle / 2.0
                        let nextAngle = baseAngle + segAngle
                        let isDeepParent = (i == deepParentIndex)
                        let isReturning = (i == returnIndex)

                        var wedge = Path()
                        wedge.addArc(center: center, radius: outerR,
                                     startAngle: .radians(baseAngle + halfGapOuter),
                                     endAngle: .radians(nextAngle - halfGapOuter),
                                     clockwise: false)
                        wedge.addArc(center: center, radius: innerR,
                                     startAngle: .radians(nextAngle - halfGapInner),
                                     endAngle: .radians(baseAngle + halfGapInner),
                                     clockwise: true)
                        wedge.closeSubpath()

                        let wedgeFillOpacity = (isDeepParent || isReturning) ? s.ringFillOpacity : fillOpacity
                        let wedgeStrokeOpacity = (isDeepParent || isReturning) ? s.ringOpacity : (dimmed ? s.ringOpacity * s.deepOrbitDimming : s.ringOpacity)

                        var drawCtx = context
                        if isDeepParent && slideOffset > 0 {
                            let midAngle = (baseAngle + nextAngle) / 2.0
                            drawCtx.translateBy(
                                x: CGFloat(cos(midAngle)) * slideOffset,
                                y: CGFloat(sin(midAngle)) * slideOffset
                            )
                        } else if isReturning && returnOffset > 0 {
                            let midAngle = (baseAngle + nextAngle) / 2.0
                            drawCtx.translateBy(
                                x: CGFloat(cos(midAngle)) * returnOffset,
                                y: CGFloat(sin(midAngle)) * returnOffset
                            )
                        }

                        if wedgeFillOpacity > 0 {
                            drawCtx.fill(wedge, with: .color(s.ringFillColor.opacity(wedgeFillOpacity)))
                        }
                        if wedgeStrokeOpacity > 0 {
                            drawCtx.stroke(wedge, with: .color(s.ringColor.opacity(wedgeStrokeOpacity)), lineWidth: isDeepParent ? 2 : 1.5)
                        }
                    }
                }
                .frame(width: (outerR + slideOffset) * 2 + 4, height: (outerR + slideOffset) * 2 + 4)
                .shadow(color: color.opacity((dimmed ? 0.15 * s.deepOrbitDimming : 0.15) * s.glowIntensity), radius: 20)
            } else {
                if fillOpacity > 0 {
                    Circle()
                        .fill(s.ringFillColor.opacity(fillOpacity))
                        .frame(width: outerR * 2, height: outerR * 2)
                        .mask(
                            ZStack {
                                Circle().frame(width: outerR * 2, height: outerR * 2)
                                Circle().frame(width: innerR * 2, height: innerR * 2)
                                    .blendMode(.destinationOut)
                            }
                            .compositingGroup()
                        )
                }

            }

            let centerOpacity = dimmed ? min(s.deepOrbitDimming * 0.25, s.centerRingOpacity) : s.centerRingOpacity
            if centerOpacity > 0 {
                Circle()
                    .stroke(s.ringColor.opacity(centerOpacity), lineWidth: 1.5)
                    .frame(width: radius * 2, height: radius * 2)
                    .shadow(color: color.opacity(0.15 * centerOpacity * s.glowIntensity), radius: 20)
            }
        }
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
    var segmentAngle: Angle = .degrees(90)
    var activeWindowIndex: Int = -1

    private var s: OrbitSettings { OrbitSettings.shared }

    private var indicatorCount: Int {
        guard s.deepOrbitEnabled, s.bumpOpacity > 0, windowCount > 1 else { return 0 }
        return min(windowCount, 5)
    }

    var body: some View {
        ZStack {
            if showBackground || isSelected {
                let ho = s.hoverHighlightOpacity
                let ringPad = CGFloat(s.hoverRingSize)
                Circle()
                    .fill(s.hoverColor.opacity(s.hoverFillOpacity * ho))
                    .frame(width: iconSize + ringPad, height: iconSize + ringPad)
                    .shadow(color: s.hoverColor.opacity(0.5 * s.glowIntensity * ho), radius: CGFloat(s.hoverGlowRadius))

                if s.hoverStrokeWidth > 0 {
                    Circle()
                        .stroke(s.hoverColor.opacity(0.6 * ho), lineWidth: CGFloat(s.hoverStrokeWidth))
                        .frame(width: iconSize + ringPad, height: iconSize + ringPad)
                }
            }

            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: iconSize, height: iconSize)
                .scaleEffect(isSelected ? CGFloat(s.hoverIconScale) : 1.0)
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

            if indicatorCount > 0 {
                windowIndicatorDots
            }
        }
    }

    private var windowIndicatorDots: some View {
        let edgeRadius = (iconSize / 2) + 6
        let dotSize: CGFloat = 5
        let spacing = Angle.degrees(14)
        let anchor: Angle = s.bumpStyle == "icon" ? .degrees(90) : segmentAngle
        let baseOpacity = s.bumpOpacity
        let opacity = isSelected ? min(baseOpacity * 1.6, 1.0) : baseOpacity

        return ForEach(0..<indicatorCount, id: \.self) { i in
            let offset = Double(i) - Double(indicatorCount - 1) / 2.0
            let angle = anchor + spacing * offset
            let isActive = activeWindowIndex >= 0 && i == (indicatorCount - 1 - activeWindowIndex)
            let dotOpacity = isActive ? s.bumpActiveOpacity : opacity
            let dotScale = isActive ? CGFloat(s.bumpActiveScale) : (isSelected ? 1.2 : 1.0)
            Circle()
                .fill(s.bumpColor.opacity(dotOpacity))
                .frame(width: dotSize, height: dotSize)
                .scaleEffect(dotScale)
                .shadow(color: s.bumpColor.opacity(isActive ? 0.6 : (isSelected ? 0.5 : 0.2)), radius: isActive ? 5 : 3)
                .offset(
                    x: edgeRadius * CGFloat(cos(angle.radians)),
                    y: edgeRadius * CGFloat(sin(angle.radians))
                )
                .animation(.easeOut(duration: 0.12), value: isActive)
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
        let base = centerAngle * 180.0 / .pi + 90
        return sin(centerAngle) > 0 ? base + 180 : base
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
