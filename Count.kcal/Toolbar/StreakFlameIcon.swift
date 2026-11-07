import SwiftUI

/// Compact flame with moving tips and a brief size pulse before each glint.
struct StreakFlameIcon: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric(relativeTo: .body) private var size = 29.04

    let color: Color
    var isAnimating = true

    var body: some View {
        // Clock updates belong to the drawing view, so brightness conversion
        // runs when this view's inputs change rather than on every frame.
        AnimatedStreakFlame(
            gradient: Gradient(colors: [color.brighten(0.2), color, color.brighten(-0.18)]),
            animates: isAnimating && !reduceMotion && scenePhase == .active
        )
        .frame(width: size * 0.82, height: size)
        .offset(y: -2)
        .accessibilityHidden(true)
    }

}

private struct AnimatedStreakFlame: View {
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.streakAnimationClock) private var clock

    let gradient: Gradient
    let animates: Bool

    private static let coreGradient = Gradient(colors: [.white.opacity(0.85), .white.opacity(0.3)])

    var body: some View {
        Group {
            if let clock {
                flame(at: animates ? clock.time.truncatingRemainder(dividingBy: DiagonalShine.cycleDuration) : 0)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !animates)) { timeline in
                    flame(at: animates ? timeline.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: DiagonalShine.cycleDuration) : 0)
                }
            }
        }
    }

}

private extension AnimatedStreakFlame {

    private func flame(at time: TimeInterval) -> some View {
        Canvas { context, size in
            draw(in: &context, size: size, time: time)
        }
        .scaleEffect(pulseScale(at: time))
    }

    private func pulseScale(at time: TimeInterval) -> Double {

        guard time >= 3.25 else { return 1 }
        guard time < 3.78 else { return 1 }
        if time < 3.43 {
            let progress = (time - 3.25) / 0.18
            return 1 - 0.1 * progress * progress * (3 - 2 * progress)
        }
        if time < 3.53 { return 0.9 }
        let progress = (time - 3.53) / 0.25
        return 0.9 + 0.1 * progress * progress * (3 - 2 * progress)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {

        context.scaleBy(x: size.width / 24, y: size.height / 24)
        let phase = time / DiagonalShine.cycleDuration * 2 * .pi
        let sway = sin(phase * 3) * 0.85 + sin(phase * 5) * 0.3
        let flutter = sin(phase * 4) * 0.65
        let outline = outline(sway: sway, flutter: flutter)

        context.fill(
            outline,
            with: .linearGradient(
                gradient,
                startPoint: CGPoint(x: 7, y: 2),
                endPoint: CGPoint(x: 17, y: 23)
            )
        )
        context.fill(
            core(sway: sway, flutter: flutter),
            with: .linearGradient(
                Self.coreGradient,
                startPoint: CGPoint(x: 10, y: 11),
                endPoint: CGPoint(x: 14, y: 22)
            )
        )

        if animates {
            context.clip(to: outline)
            DiagonalShine.draw(
                in: &context,
                size: CGSize(width: 24, height: 24),
                time: time,
                layoutDirection: layoutDirection
            )
        }
    }

    private func outline(sway: Double, flutter: Double) -> Path {

        Path { path in
            path.move(to: CGPoint(x: 12 + sway, y: 1.4 + flutter * 0.4))
            path.addCurve(
                to: CGPoint(x: 15.8, y: 10.2),
                control1: CGPoint(x: 11.4 + sway, y: 5.2),
                control2: CGPoint(x: 16.3 + sway, y: 6.2)
            )
            path.addQuadCurve(
                to: CGPoint(x: 18.6 + sway * 0.35, y: 6.3 - flutter),
                control: CGPoint(x: 18.2, y: 8.8)
            )
            path.addCurve(
                to: CGPoint(x: 22, y: 15.5),
                control1: CGPoint(x: 20.2 + sway * 0.35, y: 9.3),
                control2: CGPoint(x: 22, y: 12.1)
            )
            path.addCurve(
                to: CGPoint(x: 12, y: 23),
                control1: CGPoint(x: 22, y: 20.3),
                control2: CGPoint(x: 17.6, y: 23)
            )
            path.addCurve(
                to: CGPoint(x: 2, y: 15.5),
                control1: CGPoint(x: 6.4, y: 23),
                control2: CGPoint(x: 2, y: 20.2)
            )
            path.addCurve(
                to: CGPoint(x: 6.1 - sway * 0.3, y: 7.5 + flutter),
                control1: CGPoint(x: 2, y: 12.3),
                control2: CGPoint(x: 4.4, y: 10.1)
            )
            path.addQuadCurve(to: CGPoint(x: 6.9, y: 12), control: CGPoint(x: 5.8, y: 10.4))
            path.addCurve(
                to: CGPoint(x: 12 + sway, y: 1.4 + flutter * 0.4),
                control1: CGPoint(x: 9.4 + sway, y: 9.3),
                control2: CGPoint(x: 11.6 + sway, y: 5.9)
            )
            path.closeSubpath()
        }
    }

    private func core(sway: Double, flutter: Double) -> Path {

        Path { path in
            path.move(to: CGPoint(x: 12.2 - sway * 0.5, y: 10.4 - flutter))
            path.addCurve(
                to: CGPoint(x: 16.5, y: 18.1),
                control1: CGPoint(x: 12.5 - sway * 0.5, y: 13.9),
                control2: CGPoint(x: 16.5, y: 14.4)
            )
            path.addCurve(
                to: CGPoint(x: 12, y: 21.7),
                control1: CGPoint(x: 16.5, y: 20.3),
                control2: CGPoint(x: 14.5, y: 21.7)
            )
            path.addCurve(
                to: CGPoint(x: 7.8, y: 18.1),
                control1: CGPoint(x: 9.5, y: 21.7),
                control2: CGPoint(x: 7.8, y: 20.1)
            )
            path.addCurve(
                to: CGPoint(x: 12.2 - sway * 0.5, y: 10.4 - flutter),
                control1: CGPoint(x: 7.8, y: 15.3),
                control2: CGPoint(x: 10.9 - sway * 0.5, y: 13.9)
            )
            path.closeSubpath()
        }
    }

}

#Preview("Toolbar flame") {
    NavigationStack {
        Color.backGround.ignoresSafeArea()
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {} label: {
                        HStack(spacing: 5) {
                            StreakFlameIcon(color: .blue)
                            Text("1")
                                .font(.callout.bold())
                                .fontDesign(.rounded)
                                .offset(y: 1.5)
                        }
                    }
                    CalendarToolbarButton(showCalendar: .constant(false), controlsDisabled: false, toggleCalendar: {})
                    SettingsToolbarButton(showSettings: .constant(false))
                }
            }
    }
    .preferredColorScheme(.dark)
}
