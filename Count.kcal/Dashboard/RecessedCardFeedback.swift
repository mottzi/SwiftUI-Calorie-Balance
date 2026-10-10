import SwiftUI

/// Shares one feedback sequence between the native action and its button style.
@MainActor
@Observable
final class RecessedCardFeedback {
    private var press = RecessedPress()

    var isDepressed: Bool { press.isDepressed }

    func appear(_ input: RecessedPress.Input) {
        #if DEBUG
        RecessedTrace.record("event=appear held=\(input.isHeld) pulse=\(input.pulse)")
        #endif
        update { $0.appear(input) }
    }

    func updateInput(_ input: RecessedPress.Input) {
        #if DEBUG
        RecessedTrace.record("event=input held=\(input.isHeld) pulse=\(input.pulse) phase=\(press.phase)")
        #endif
        update { $0.update(input) }
    }

    func activate() {
        #if DEBUG
        RecessedTrace.record("event=action phase=\(press.phase)")
        #endif
        update { $0.activate() }
    }

    func disappear() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { press.disappear() }
        #if DEBUG
        RecessedTrace.record("event=disappear")
        RecessedTrace.flush()
        #endif
    }

    private func update(_ change: (inout RecessedPress) -> RecessedPress.Motion?) {
        var next = press
        let result = change(&next)
        #if DEBUG
        RecessedTrace.record("event=transition from=\(press.phase) to=\(next.phase) motion=\(String(describing: result))")
        #endif
        guard let motion = result else {
            press = next
            return
        }
        let animation: Animation = switch motion {
        case .press: .easeOut(duration: 0.15)
        case .release: .smooth(duration: 0.24)
        }
        withAnimation(animation, completionCriteria: .removed) {
            press = next
        } completion: { [weak self] in
            guard let self else { return }
            #if DEBUG
            RecessedTrace.record("event=completion motion=\(motion) phase=\(press.phase)")
            #endif
            update { $0.complete(motion) }
            #if DEBUG
            if press.phase == .resting { RecessedTrace.flush() }
            #endif
        }
    }
}

#if DEBUG
/// Opt-in diagnostics: COUNT_RECESSED_TRACE=1. Flush only after active motion.
@MainActor
private enum RecessedTrace {
    private static let enabled = ProcessInfo.processInfo.environment["COUNT_RECESSED_TRACE"] == "1"
    private static var events: [String] = []

    static func record(_ event: @autoclosure () -> String) {
        guard enabled else { return }
        events.append("RecessedTrace t=\(ProcessInfo.processInfo.systemUptime) \(event())")
    }

    static func flush() {
        guard enabled, !events.isEmpty else { return }
        print(events.joined(separator: "\n"))
        events.removeAll(keepingCapacity: true)
    }
}
#endif
