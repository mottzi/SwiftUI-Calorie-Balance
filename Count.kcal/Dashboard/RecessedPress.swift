/// Owns press feedback sequencing; SwiftUI owns interpolation and completion.
struct RecessedPress {
    struct Input: Equatable {
        var isHeld = false
        var activation = 0
        var pulse = 0
    }

    enum Phase { case resting, pressing, pressed, releasing }
    enum Motion: Equatable { case press(Int), release(Int) }

    private(set) var phase: Phase = .resting
    private var input: Input?
    private var generation = 0

    var isDepressed: Bool { phase == .pressing || phase == .pressed }

    mutating func appear(_ input: Input) -> Motion? {
        disappear()
        self.input = input
        return input.isHeld ? press() : nil
    }

    mutating func disappear() {
        generation += 1
        input = nil
        phase = .resting
    }

    mutating func update(_ next: Input) -> Motion? {
        guard let previous = input else { return nil }
        input = next
        let touchDown = next.isHeld && !previous.isHeld
        let activated = next.activation != previous.activation
        // Touch-up and the Button action are read in one snapshot. The action
        // acknowledges a rendered physical press instead of replaying it.
        let acknowledgesTouch = activated && (previous.isHeld || next.isHeld)
        if touchDown || next.pulse != previous.pulse || (activated && !acknowledgesTouch) {
            return press() ?? releaseIfReady()
        }
        return releaseIfReady()
    }

    mutating func complete(_ motion: Motion) -> Motion? {
        switch motion {
        case .press(let token):
            guard token == generation, phase == .pressing else { return nil }
            phase = .pressed
            return releaseIfReady()
        case .release(let token):
            guard token == generation, phase == .releasing else { return nil }
            phase = .resting
            return nil
        }
    }

    private mutating func press() -> Motion? {
        guard phase == .resting || phase == .releasing else { return nil }
        generation += 1
        phase = .pressing
        return .press(generation)
    }

    private mutating func releaseIfReady() -> Motion? {
        guard input?.isHeld == false, phase == .pressed else { return nil }
        generation += 1
        phase = .releasing
        return .release(generation)
    }
}
