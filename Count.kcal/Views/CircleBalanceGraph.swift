import SwiftUI

/// Burned and consumed energy in rings for Now or Midnight.
struct CircleBalanceGraph: View {

    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var AppSettings: Settings
    @Environment(HealthInterface.self) private var DataViewModel

    var lineWidth: CGFloat = 8
    let mode: GraphMode
    // Accented widgets replace colors with white but retain each ring's opacity.
    var accentedWidget = false

    var body: some View {
        GeometryReader { geo in
            let energy = mode == .now ? DataViewModel.sample.now : DataViewModel.sample.midnight
            let innerInset = scheme == .dark ? lineWidth * 2.5 : lineWidth * 2.25
            let outer = CircleRingSegments(boundaries: [
                0, energy.ratio(of: energy.active), energy.ratio(of: energy.active + energy.resting),
                energy.ratio(of: energy.burned), 1
            ], radius: geo.size.width / 2)
            let inner = CircleRingSegments(boundaries: [0, energy.ratio(of: energy.consumed), 1],
                                           radius: (geo.size.width - innerInset) / 2)

            // Keep all segments present across mode changes. Built-in trim values carry
            // the moving boundaries without a custom, topology-changing mask.
            ZStack {
                segment(outer.ranges[0], color: AppSettings.burnedColor, level: .primary)
                segment(outer.ranges[1], color: AppSettings.burnedColor, level: .secondary,
                        opacity: accentedWidget ? 0.85 : 1)
                segment(outer.ranges[2], color: AppSettings.burnedColor, level: .tertiary,
                        opacity: mode == .now ? 0 : accentedWidget ? 0.45 : 1)
                emptySegment(outer.ranges[3])

                ZStack {
                    segment(inner.ranges[0], color: AppSettings.consumedColor, level: .primary,
                            context: .bargraph, opacity: accentedWidget ? 0.6 : 1)
                    emptySegment(inner.ranges[1])
                }
                .frame(width: geo.size.width - innerInset, height: geo.size.height - innerInset)
            }
            .graphColorAppearance()
        }
        .padding(lineWidth / 2)
    }

    private func segment(_ range: ClosedRange<Double>, color: Color, level: BrightnessLevel,
                         context: BrightnessContext = .circlegraphMidnight, opacity: Double = 1) -> some View {
        ZStack {
            // Retain the empty ring underneath translucent accented-widget segments.
            emptySegment(range)
            CircleProgressView(progress: range.upperBound, color: color, lineWidth: lineWidth,
                               startProgress: range.lowerBound)
                .brightness(level: level, to: context)
                .opacity(opacity)
        }
    }

    private func emptySegment(_ range: ClosedRange<Double>) -> some View {
        CircleProgressView(progress: range.upperBound, color: AppSettings.getGraphEmptyColor(scheme),
                           lineWidth: lineWidth, startProgress: range.lowerBound)
            .brightness(level: .primary, to: .bargraph)
            .opacity(accentedWidget ? 0.25 : 1)
    }

}

/// Ring endpoints with two-point transparent space between neighboring segments.
struct CircleRingSegments {

    let ranges: [ClosedRange<Double>]

    init(boundaries: [Double], radius: CGFloat) {
        let arcLength = max(0, radius) * 2 * .pi * 0.75
        let halfGap = boundaries.map { boundary -> Double in
            guard arcLength > 0,
                  let before = boundaries.last(where: { $0 < boundary }),
                  let after = boundaries.first(where: { $0 > boundary }) else { return 0 }
            // Narrow gaps around tiny segments so they retain visible color.
            return min(1 / arcLength, (boundary - before) / 4, (after - boundary) / 4)
        }
        ranges = zip(boundaries.indices.dropLast(), boundaries.indices.dropFirst()).map { lower, upper in
            guard boundaries[upper] > boundaries[lower] else {
                return boundaries[lower]...boundaries[lower]
            }
            return (boundaries[lower] + halfGap[lower])...(boundaries[upper] - halfGap[upper])
        }
    }

}

/// Time used for calorie balance graphs.
enum GraphMode {

    case now
    case midnight

}
