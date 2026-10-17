import SwiftUI
import WidgetKit

/// One bar with an occupied end cap and values placed across the whole row.
struct CalorieBarRow: View {

    @Environment(\.widgetRenderingMode) private var renderingMode

    let values: EnergyGraphValues
    let side: EnergyGraphValues.Side
    let configuration: CalorieBarConfiguration
    let palette: CalorieGraphPalette
    var rendering: CalorieGraphRendering = .live
    var projectedRestingLabel: Int? = nil

    private var isTintedWidget: Bool {
        rendering == .widget && renderingMode == .accented
    }

    private var retainsWidgetProjection: Bool {
        rendering == .widget && projectedRestingLabel != nil
    }

    private var widgetFillPalette: CalorieGraphPalette {
        guard isTintedWidget else { return palette }
        var result = palette
        // WidgetKit tints all these fills to the same color. For cumulative
        // layers, solve target = overlay + underneath * (1 - overlay).
        result.active.opacity = replacementOpacity(palette.active.opacity, over: palette.resting.opacity)
        result.resting.opacity = replacementOpacity(palette.resting.opacity, over: palette.prediction.opacity)
        return result
    }

    private func replacementOpacity(_ target: Double, over underneath: Double) -> Double {
        guard underneath < 1 else { return 0 }
        return min(max((target - underneath) / (1 - underneath), 0), 1)
    }

    var body: some View {
        let segments = values.segments(for: side)
        let radius = max(0, configuration.cornerRadius)
        let row = CalorieBarRowLayout(
            values: values,
            side: side,
            labelSpacing: configuration.labelSpacing,
            labelInset: configuration.labelInset,
            retainsWidgetProjection: retainsWidgetProjection
        ) {
            CalorieGraphDrawing(values: values, rendering: rendering) { values in
                CalorieBarFillDrawing(
                    values: values,
                    side: side,
                    palette: widgetFillPalette,
                    usesCumulativeLayers: rendering == .widget
                )
            }
            .clipShape(UnevenRoundedRectangle(
                bottomTrailingRadius: side == .consumed ? radius : 0,
                topTrailingRadius: side == .burned ? radius : 0,
                style: .circular
            ))

            if configuration.showsLabels {
                ForEach(segments, id: \.id.rawValue) { segment in
                    label(for: segment)
                    .geometryGroup()
                    // In tinted widgets the mask is the only drawing of filled
                    // values. A second white numeric transition can leak through it.
                    .opacity(isTintedWidget && segment.id != .empty ? 0 : 1)
                    .zIndex(retainsWidgetProjection ? (segment.id == .prediction ? 1 : 3) : 0)
                }
            }

            if retainsWidgetProjection && configuration.showsLabels && !isTintedWidget {
                // The recorded fills cover the retained projection label with the
                // same native endpoints that reveal and close its segment.
                CalorieBarFillDrawing(
                    values: values,
                    side: side,
                    palette: palette,
                    usesCumulativeLayers: true,
                    includesProjection: false
                )
                .clipShape(UnevenRoundedRectangle(
                    bottomTrailingRadius: side == .consumed ? radius : 0,
                    topTrailingRadius: side == .burned ? radius : 0,
                    style: .circular
                ))
                .layoutValue(key: CalorieBarRowLayout.RecordedFillKey.self, value: true)
                .zIndex(2)
            }
        }
        .background(palette.empty.color.opacity(palette.empty.opacity))
        .compositingGroup()
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: side == .burned ? radius : 0,
            bottomLeadingRadius: side == .consumed ? radius : 0,
            bottomTrailingRadius: side == .consumed ? radius : 0,
            topTrailingRadius: side == .burned ? radius : 0,
            style: .continuous
        ))

        if renderingMode == .accented && configuration.showsLabels {
            row.mask(labelMask)
        } else if configuration.animatesNumericValues {
            row
        } else {
            row.drawingGroup()
        }
    }

}

extension CalorieBarRow {

    @ViewBuilder
    private func label(for segment: EnergyGraphValues.Segment) -> some View {
        if retainsWidgetProjection, segment.id == .prediction, let projectedRestingLabel {
            // Keep full glyphs in both archives. The recorded fill above this label
            // handles visibility, so WidgetKit never replaces a masked label image.
            CalorieBarLabel(
                value: max(0, projectedRestingLabel),
                animatesNumericValues: configuration.animatesNumericValues,
                reservesSpace: segment.value > 0
            )
            .accessibilityHidden(segment.value == 0)
        } else {
            CalorieBarLabel(
                value: Int(segment.value.rounded()),
                animatesNumericValues: configuration.animatesNumericValues
            )
        }
    }

    private var labelMask: some View {
        CalorieBarRowLayout(
            values: values,
            side: side,
            labelSpacing: configuration.labelSpacing,
            labelInset: configuration.labelInset,
            retainsWidgetProjection: retainsWidgetProjection
        ) {
            Color.clear
            ForEach(values.segments(for: side), id: \.id.rawValue) { segment in
                label(for: segment)
                .colorMultiply(.black)
                .opacity(segment.id == .empty ? 0 : 1)
                .geometryGroup()
                .zIndex(isTintedWidget && segment.id == .prediction ? 1 : 3)
            }
            if isTintedWidget && retainsWidgetProjection {
                // White restores mask coverage over the retained black projection
                // glyphs, using exactly the recorded fill's native endpoint.
                recordedLabelMaskCover
                    .layoutValue(key: CalorieBarRowLayout.RecordedFillKey.self, value: true)
                    .zIndex(2)
            }
        }
        .background(.white)
        .compositingGroup()
        .luminanceToAlpha()
    }

    private var recordedLabelMaskCover: some View {
        GeometryReader { geometry in
            let occupied = values.burnedSegments.dropLast().last?.range.upperBound ?? 0
            let recorded = values.burnedSegments.first(where: { $0.id == .resting })?.range.upperBound ?? 0
            let width = occupied > 0 ? geometry.size.width * recorded / occupied : 0
            Rectangle()
                .fill(.white)
                .frame(width: max(0, width), height: max(0, geometry.size.height))
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
        }
        .clipShape(UnevenRoundedRectangle(
            topTrailingRadius: max(0, configuration.cornerRadius),
            style: .circular
        ))
    }

    /// Active, resting, or consumed segments within the occupied part of a bar.
    private struct CalorieBarFillDrawing: View {

        @Environment(\.layoutDirection) private var layoutDirection

        let values: EnergyGraphValues
        let side: EnergyGraphValues.Side
        let palette: CalorieGraphPalette
        let usesCumulativeLayers: Bool
        var includesProjection = true

        var body: some View {
            GeometryReader { geometry in
                let segments = values.segments(for: side).dropLast()
                let occupied = segments.last?.range.upperBound ?? 0
                let drawnSegments = segments.filter { includesProjection || $0.id != .prediction }
                let layers = usesCumulativeLayers ? Array(drawnSegments.reversed()) : drawnSegments
                ZStack(alignment: .leading) {
                    // Paint cumulative layers from the last segment backwards. A zero-length
                    // projection stays underneath the recorded segments, so WidgetKit can
                    // reveal it by resizing their edges instead of fading a new rectangle in.
                    ForEach(layers, id: \.id.rawValue) { segment in
                        let range = segment.range
                        let start = usesCumulativeLayers ? 0 : range.lowerBound
                        let width = occupied > 0
                            ? geometry.size.width * (range.upperBound - start) / occupied
                            : 0
                        let offset = occupied > 0 ? geometry.size.width * start / occupied : 0
                        let fill = palette.fill(for: segment.id)
                        Rectangle()
                            .fill(fill.color.gradient)
                            .brightness(fill.brightness)
                            .opacity(fill.opacity)
                            .graphColorAppearance()
                            .frame(width: max(0, width), height: max(0, geometry.size.height))
                            .offset(x: layoutDirection == .rightToLeft ? -offset : offset)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
            }
        }

    }

}
