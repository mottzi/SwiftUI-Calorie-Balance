import SwiftUI

/// Switches today's calorie graphs in place while retaining the selected mode.
struct CaloriesMidnightCard: View {

    nonisolated static let rimDepth: CGFloat = 6
    nonisolated private static let rimOpacity: Double = 0.15

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(HealthInterface.self) private var day

    @EnvironmentObject private var settings: Settings

    @Binding var todayPageMode: PagerSelection
    var pressTrigger: Int = 0

    var body: some View {
        Button(action: toggleMode) {
            CaloriesCard(mode: mode, animateNumericValues: true)
                .animation(reduceMotion ? nil : .snappy, value: todayPageMode)
                .contentShape(.rect(cornerRadius: 10))
        }
        .buttonStyle(PressStyle(
            pressTrigger: pressTrigger,
            reduceMotion: reduceMotion,
            background: settings.CardBackground
        ))
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
        let pressTrigger: Int
        let reduceMotion: Bool
        let background: Color

        func makeBody(configuration: Configuration) -> some View {
            PressedCard(
                label: configuration.label,
                isPressed: configuration.isPressed,
                pressTrigger: pressTrigger,
                reduceMotion: reduceMotion,
                background: background
            )
        }
    }

    private struct PressedCard: View {
        @State private var depth: CGFloat = 0
        @State private var releaseDeadline: ContinuousClock.Instant?
        @State private var pressGeneration = 0

        let label: ButtonStyleConfiguration.Label
        let isPressed: Bool
        let pressTrigger: Int
        let reduceMotion: Bool
        let background: Color

        var body: some View {
            label
                .modifier(PressOffset(depth: depth, reduceMotion: reduceMotion, background: background))
                .padding(.bottom, rimDepth)
                .contentShape(.rect(cornerRadius: 10))
                .onChange(of: isPressed) { _, pressed in
                    guard pressed else { return }
                    // Native press changes are synchronous, including very short taps.
                    press()
                }
                .onChange(of: pressTrigger) { _, _ in
                    press()
                }
                // Holds cancel release; repeated requests replace it rather than queue it.
                .task(id: isPressed ? nil : releaseDeadline) {
                    await releaseIfNeeded()
                }
                .onDisappear {
                    pressGeneration &+= 1
                    depth = 0
                    releaseDeadline = nil
                }
        }

        private func press() {
            // Preserve the existing descent and release when already targeting the base.
            if depth == rimDepth { return }
            pressGeneration &+= 1
            let generation = pressGeneration
            let minimumDeadline = ContinuousClock.now.advanced(by: .milliseconds(130))
            // Cancel release until the face has actually reached the base.
            releaseDeadline = nil
            withAnimation(.easeOut(duration: 0.08), completionCriteria: .logicallyComplete) {
                depth = rimDepth
            } completion: {
                // Interrupted presses and disappearing cards cannot schedule a stale release.
                guard pressGeneration == generation else { return }
                releaseDeadline = max(
                    minimumDeadline,
                    ContinuousClock.now.advanced(by: .milliseconds(50))
                )
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

    /// Press depth stays within the physical base throughout interpolation.
    private struct PressOffset: ViewModifier, Animatable {
        var depth: CGFloat
        let reduceMotion: Bool
        let background: Color

        var animatableData: CGFloat {
            get { depth }
            set { depth = min(max(newValue, 0), rimDepth) }
        }

        func body(content: Content) -> some View {
            content
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color("TextColor").opacity(0.06), lineWidth: 2)
                        .mask(alignment: .top) {
                            LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .bottom)
                                .frame(height: 10)
                        }
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                .offset(y: reduceMotion ? 0 : depth)
                .opacity(reduceMotion ? 1 - 0.15 * depth / rimDepth : 1)
                .background {
                    let shape = RoundedRectangle(cornerRadius: 10)
                    shape.fill(background)
                        .overlay {
                            shape.fill(Color("TextColor").opacity(rimOpacity))
                        }
                        .overlay(alignment: .bottom) {
                            LinearGradient(colors: [.clear, .black.opacity(0.18)], startPoint: .bottom, endPoint: .top)
                                .frame(height: rimDepth)
                        }
                        .clipShape(shape)
                        // A matching base below the face exposes only its lower edge.
                        .offset(y: rimDepth)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                // This modifier interpolates depth; its offset must not animate again.
                .transaction { $0.animation = nil }
        }
    }

}

#Preview { PreviewPager }
