import SwiftUI

/// Switches today's calorie graphs in place while retaining the selected mode.
struct CaloriesMidnightCard: View {

    nonisolated static let rimDepth: CGFloat = 3
    nonisolated static let rimSideDepth: CGFloat = rimDepth

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(HealthInterface.self) private var day

    @EnvironmentObject private var settings: Settings

    @Binding var todayPageMode: PagerSelection

    var body: some View {
        Button(action: toggleMode) {
            CaloriesCard(mode: mode, animateNumericValues: true)
                .animation(reduceMotion ? nil : .snappy, value: todayPageMode)
                .contentShape(.rect(cornerRadius: 10))
        }
        .buttonStyle(PressStyle(reduceMotion: reduceMotion, background: settings.CardBackground))
        .accessibilityLabel("Calories")
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(mode == .now ? "Show the midnight estimate" : "Show the current balance")
        .accessibilityInputLabels(["Calories", "Calorie balance"])
    }

}

extension CaloriesMidnightCard {

    private func toggleMode() {
        todayPageMode.toggle()
    }

    private var mode: GraphMode { todayPageMode == .first ? .now : .midnight }

    private var accessibilityValue: Text {
        let energy = mode == .now ? day.sample.now : day.sample.midnight
        let unit = settings.energyUnit == .kJ ? "kJ" : "kcal"
        let modeTitle: LocalizedStringKey = mode == .now ? "Now" : "Midnight"
        let balanceTitle: LocalizedStringKey = energy.isEmpty || energy.balance == 0
            ? "Balance"
            : energy.balance > 0 ? "Deficit" : "Surplus"
        return Text(
            "\(Text(modeTitle)). \(Text(balanceTitle)) \(abs(energy.balance)) \(unit). Burned \(energy.burned) \(unit). Eaten \(energy.consumed) \(unit)."
        )
    }

    private struct PressStyle: ButtonStyle {
        let reduceMotion: Bool
        let background: Color

        func makeBody(configuration: Configuration) -> some View {
            PressedCard(
                label: configuration.label,
                isPressed: configuration.isPressed,
                reduceMotion: reduceMotion,
                background: background
            )
        }
    }

    private struct PressedCard: View {
        @Environment(\.layoutDirection) private var layoutDirection
        @State private var depth: CGFloat = 0
        @State private var releaseDeadline: ContinuousClock.Instant?

        let label: ButtonStyleConfiguration.Label
        let isPressed: Bool
        let reduceMotion: Bool
        let background: Color

        private var horizontalDepth: CGFloat {
            layoutDirection == .leftToRight ? rimSideDepth : -rimSideDepth
        }

        var body: some View {
            label
                .modifier(PressOffset(depth: depth, horizontalDepth: horizontalDepth, reduceMotion: reduceMotion))
                .background {
                    let shape = RoundedRectangle(cornerRadius: 10)
                    shape.fill(background)
                        .overlay {
                            shape.fill(Color("TextColor").opacity(0.28))
                        }
                        .offset(x: horizontalDepth, y: rimDepth)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                .padding(.bottom, rimDepth)
                .padding(.trailing, rimSideDepth)
                .contentShape(.rect(cornerRadius: 10))
                .onChange(of: isPressed) { _, pressed in
                    guard pressed else { return }
                    // Native press changes are synchronous, including very short taps.
                    releaseDeadline = ContinuousClock.now.advanced(by: .milliseconds(130))
                    withAnimation(.easeOut(duration: 0.08)) {
                        depth = rimDepth
                    }
                }
                .task(id: isPressed) {
                    await releaseIfNeeded()
                }
                .onDisappear {
                    depth = 0
                    releaseDeadline = nil
                }
        }

        private func releaseIfNeeded() async {
            guard !isPressed, let releaseDeadline else { return }
            do {
                // A new press or disappearance cancels this view-owned task.
                try await ContinuousClock().sleep(until: releaseDeadline)
                try Task.checkCancellation()
            } catch {
                return
            }
            withAnimation(.spring(duration: 0.28, bounce: 0)) {
                depth = 0
            }
        }
    }

    /// One interpolated position drives both edges, bounded by the physical base.
    private struct PressOffset: ViewModifier, Animatable {
        var depth: CGFloat
        let horizontalDepth: CGFloat
        let reduceMotion: Bool

        var animatableData: CGFloat {
            get { depth }
            set { depth = min(max(newValue, 0), rimDepth) }
        }

        func body(content: Content) -> some View {
            content
                .offset(x: reduceMotion ? 0 : depth / rimDepth * horizontalDepth, y: reduceMotion ? 0 : depth)
                .opacity(reduceMotion ? 1 - 0.15 * depth / rimDepth : 1)
                // This modifier interpolates depth; its offset must not animate again.
                .transaction { $0.animation = nil }
        }
    }

}

#Preview { PreviewPager }
