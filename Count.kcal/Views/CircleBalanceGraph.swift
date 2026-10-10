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

            // Keep color effects in one rendering path; a geometry group clips brightened channels.
            ZStack {
                // base
                CircleProgressView(progress: 1, color: AppSettings.getGraphEmptyColor(scheme), lineWidth: lineWidth)
                    .brightness(level: .primary, to: .bargraph)
                    .opacity(accentedWidget ? 0.25 : 1)

                // Keep the projection's identity so its arc animates with the recorded rings.
                CircleProgressView(
                    progress: energy.ratio(of: energy.burned),
                    color: AppSettings.burnedColor,
                    lineWidth: lineWidth
                )
                .brightness(level: .tertiary, to: .circlegraphMidnight)
                .opacity(mode == .now ? 0 : accentedWidget ? 0.45 : 1)

                // passive
                CircleProgressView(
                    progress: energy.ratio(of: energy.active + energy.resting),
                    color: AppSettings.burnedColor,
                    lineWidth: lineWidth
                )
                .brightness(level: .secondary, to: .circlegraphMidnight)
                .opacity(accentedWidget ? 0.85 : 1)

                // active
                CircleProgressView(
                    progress: energy.ratio(of: energy.active),
                    color: AppSettings.burnedColor,
                    lineWidth: lineWidth
                )
                .brightness(level: .primary, to: .circlegraphMidnight)

                // base
                CircleProgressView(progress: 1, color: AppSettings.getGraphEmptyColor(scheme), lineWidth: lineWidth)
                    .frame(width: geo.size.width - innerInset, height: geo.size.height - innerInset)
                    .brightness(level: .primary, to: .bargraph)
                    .opacity(accentedWidget ? 0.25 : 1)

                // consumed
                CircleProgressView(
                    progress: energy.ratio(of: energy.consumed),
                    color: AppSettings.consumedColor,
                    lineWidth: lineWidth
                )
                .frame(width: geo.size.width - innerInset, height: geo.size.height - innerInset)
                .brightness(level: .primary, to: .bargraph)
                .opacity(accentedWidget ? 0.6 : 1)
            }

            .graphColorAppearance()
            // Remove segment boundaries after color effects, exposing the card underneath.
            .mask {
                CircleSegmentGapMask(
                    active: energy.ratio(of: energy.active),
                    recorded: energy.ratio(of: energy.active + energy.resting),
                    burned: energy.ratio(of: energy.burned),
                    consumed: energy.ratio(of: energy.consumed),
                    lineWidth: lineWidth,
                    innerInset: innerInset
                )
                .fill(style: FillStyle(eoFill: true))
            }
        }
        .padding(lineWidth / 2)
    }

}

/// Two-point transparent gaps that follow the ring segment boundaries during animation.
private struct CircleSegmentGapMask: Shape {

    var active: Double
    var recorded: Double
    var burned: Double
    var consumed: Double
    let lineWidth: CGFloat
    let innerInset: CGFloat

    var animatableData: AnimatablePair<AnimatablePair<Double, Double>, AnimatablePair<Double, Double>> {
        get { AnimatablePair(AnimatablePair(active, recorded), AnimatablePair(burned, consumed)) }
        set {
            active = max(0, newValue.first.first)
            recorded = max(0, newValue.first.second)
            burned = max(0, newValue.second.first)
            consumed = max(0, newValue.second.second)
        }
    }

    func path(in rect: CGRect) -> Path {

        var path = Path(rect.insetBy(dx: -lineWidth, dy: -lineWidth))
        let radius = rect.width / 2
        if active > 0 && recorded > active {
            addGap(at: active, before: active, after: recorded - active, radius: radius, in: rect, to: &path)
        }
        if recorded > 0 && burned > recorded {
            addGap(at: recorded, before: recorded - active > 0 ? recorded - active : active,
                   after: burned - recorded, radius: radius, in: rect, to: &path)
        }
        if burned > 0 && burned < 1 {
            let lastSegment = burned > recorded ? burned - recorded : recorded > active ? recorded - active : active
            addGap(at: burned, before: lastSegment, after: 1 - burned,
                   radius: radius, in: rect, to: &path)
        }
        if consumed > 0 && consumed < 1 {
            addGap(at: consumed, before: consumed, after: 1 - consumed,
                   radius: radius - innerInset / 2, in: rect, to: &path)
        }
        return path
    }

    private func addGap(at progress: Double, before: Double, after: Double, radius: CGFloat, in rect: CGRect, to path: inout Path) {

        let arc = ArcShape(ratio: progress, cutout: 0.25)
        let angle = (arc.interpolatedEnd - 90) * .pi / 180
        // Keep very small segments visible instead of letting adjacent gaps erase them.
        let width = min(2, radius * arc.graphEndAngle * 2 * .pi / 180 * min(before, after))
        let innerRadius = radius - lineWidth / 2 - 0.5
        let outerRadius = radius + lineWidth / 2 + 0.5
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radial = CGPoint(x: cos(angle), y: sin(angle))
        let tangent = CGPoint(x: -radial.y * width / 2, y: radial.x * width / 2)

        path.move(to: CGPoint(x: center.x + radial.x * innerRadius + tangent.x,
                             y: center.y + radial.y * innerRadius + tangent.y))
        path.addLine(to: CGPoint(x: center.x + radial.x * outerRadius + tangent.x,
                                y: center.y + radial.y * outerRadius + tangent.y))
        path.addLine(to: CGPoint(x: center.x + radial.x * outerRadius - tangent.x,
                                y: center.y + radial.y * outerRadius - tangent.y))
        path.addLine(to: CGPoint(x: center.x + radial.x * innerRadius - tangent.x,
                                y: center.y + radial.y * innerRadius - tangent.y))
        path.closeSubpath()
    }

}

/// Time used for calorie balance graphs.
enum GraphMode {

    case now
    case midnight

}
