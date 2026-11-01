import SwiftUI
import Observation

@MainActor @Observable
/// One clock drives every flame in a visible sharing screen.
final class StreakAnimationClock {
    var time: TimeInterval = 0
}

extension EnvironmentValues {
    @Entry var streakAnimationClock: StreakAnimationClock? = nil
}

struct StreakAnimationScope: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var clock = StreakAnimationClock()

    func body(content: Content) -> some View {
        content
            .environment(\.streakAnimationClock, clock)
            .task(id: scenePhase == .active && !reduceMotion) {
                guard scenePhase == .active, !reduceMotion else { return }
                while !Task.isCancelled {
                    clock.time = Date.now.timeIntervalSinceReferenceDate
                    do { try await Task.sleep(for: .seconds(1.0 / 30)) } catch { return }
                }
            }
    }
}
