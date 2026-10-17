import SwiftUI

/// A periodic highlight that crosses from top leading to bottom trailing.
struct DiagonalShine: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.layoutDirection) private var layoutDirection

    var delay: TimeInterval = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !animates)) { timeline in
            Canvas { context, size in
                let time = animates ? (timeline.date.timeIntervalSinceReferenceDate - delay)
                    .truncatingRemainder(dividingBy: Self.cycleDuration) : 0
                Self.draw(in: &context, size: size, time: time, layoutDirection: layoutDirection)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

}

extension DiagonalShine {

    static func draw(
        in context: inout GraphicsContext,
        size: CGSize,
        time: TimeInterval,
        layoutDirection: LayoutDirection
    ) {

        guard time > 3.5 else { return }
        guard time < 4.4 else { return }
        let progress = (time - 3.5) / 0.9
        let position = -16 + progress * 56
        context.scaleBy(x: size.width / 24, y: size.height / 24)
        if layoutDirection == .rightToLeft {
            context.translateBy(x: 24, y: 0)
            context.scaleBy(x: -1, y: 1)
        }
        context.opacity *= sin(progress * .pi) * 0.65
        context.fill(
            Path(CGRect(x: 0, y: 0, width: 24, height: 24)),
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white.opacity(0.8), location: 0.5),
                    .init(color: .clear, location: 1)
                ]),
                startPoint: CGPoint(x: position - 5, y: 4),
                endPoint: CGPoint(x: position + 5, y: 12)
            )
        )
    }

}

extension DiagonalShine {

    private var animates: Bool {
        !reduceMotion && scenePhase == .active
    }

    static let cycleDuration: TimeInterval = 4.8

}
