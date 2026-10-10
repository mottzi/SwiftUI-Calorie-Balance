import Testing
@testable import Count_kcal

struct RecessedPressTests {
    @Test func quickTapCompletesDescentBeforeReturning() throws {
        var press = RecessedPress()
        let result1 = press.appear(.init())
        #expect(result1 == nil)
        let downResult = press.activate()
        let down = try #require(downResult)
        #expect(press.isDepressed)
        let upResult = press.complete(down)
        let up = try #require(upResult)
        #expect(press.phase == .releasing)
        let result2 = press.complete(up)
        #expect(result2 == nil)
        #expect(press.phase == .resting)
    }

    @Test func heldReleaseAcknowledgesItsStrokeWithoutReplayingIt() throws {
        var press = RecessedPress()
        _ = press.appear(.init())
        let downResult = press.update(.init(isHeld: true))
        let down = try #require(downResult)
        let result3 = press.complete(down)
        #expect(result3 == nil)
        #expect(press.phase == .pressed)
        _ = press.activate()
        let upResult = press.update(.init())
        let up = try #require(upResult)
        #expect(press.phase == .releasing)
        _ = press.complete(up)
        #expect(press.phase == .resting)
    }

    @Test func earlyTouchUpStillCompletesDescent() throws {
        var press = RecessedPress()
        _ = press.appear(.init())
        let downResult = press.update(.init(isHeld: true))
        let down = try #require(downResult)
        let result4 = press.activate()
        #expect(result4 == nil)
        _ = press.update(.init())
        #expect(press.phase == .pressing)
        let upResult = press.complete(down)
        let up = try #require(upResult)
        _ = press.complete(up)
        #expect(press.phase == .resting)
    }

    @Test func delayedModeRenderAfterTouchUpDoesNotRestartReturn() throws {
        var press = RecessedPress()
        var mode = TodayPageMode()
        _ = press.appear(.init())
        let downResult = press.update(.init(isHeld: true))
        let down = try #require(downResult)
        _ = press.complete(down)
        // Native action acknowledges the already rendered held stroke directly.
        let action = press.activate()
        #expect(action == nil)
        mode.toggle(from: .card)
        let upResult = press.update(.init())
        let up = try #require(upResult)
        #expect(press.phase == .releasing)
        // A subsequent mode render has the same physical input, no new event.
        #expect(mode.selection == .second)
        let modeRender = press.update(.init())
        #expect(modeRender == nil)
        #expect(press.phase == .releasing)
        _ = press.complete(up)
        #expect(press.phase == .resting)
    }

    @Test func actionBeforeRenderedTouchDownStillProducesOnlyOneStroke() throws {
        var press = RecessedPress()
        _ = press.appear(.init())
        let downResult = press.activate()
        let down = try #require(downResult)
        let touchDown = press.update(.init(isHeld: true))
        #expect(touchDown == nil)
        let touchUp = press.update(.init())
        #expect(touchUp == nil)
        let upResult = press.complete(down)
        let up = try #require(upResult)
        _ = press.complete(up)
        #expect(press.phase == .resting)
    }

    @Test func cancelledHeldPressDoesNotConsumeAQuickTapDuringReturn() throws {
        var press = RecessedPress()
        _ = press.appear(.init())
        let downResult = press.update(.init(isHeld: true))
        let down = try #require(downResult)
        _ = press.complete(down)
        // Cancellation produces touch-up without a successful activation.
        let cancelledReturnResult = press.update(.init())
        let cancelledReturn = try #require(cancelledReturnResult)
        // A fresh quick tap may activate before its held state renders.
        let nextDownResult = press.activate()
        let nextDown = try #require(nextDownResult)
        #expect(press.phase == .pressing)
        _ = press.complete(cancelledReturn)
        #expect(press.phase == .pressing)
        let nextReturnResult = press.complete(nextDown)
        let nextReturn = try #require(nextReturnResult)
        _ = press.complete(nextReturn)
        #expect(press.phase == .resting)
    }

    @Test func quickTapDuringReturnStartsAnotherDescent() throws {
        var press = RecessedPress()
        _ = press.appear(.init())
        let downResult = press.activate()
        let down = try #require(downResult)
        let oldReturnResult = press.complete(down)
        let oldReturn = try #require(oldReturnResult)
        let nextDownResult = press.activate()
        let nextDown = try #require(nextDownResult)
        #expect(press.phase == .pressing)
        let result5 = press.complete(oldReturn)
        #expect(result5 == nil)
        #expect(press.phase == .pressing)
        let nextReturnResult = press.complete(nextDown)
        let nextReturn = try #require(nextReturnResult)
        _ = press.complete(nextReturn)
        #expect(press.phase == .resting)
    }

    @Test func staleReturnCannotFinishANewerReturn() throws {
        var press = RecessedPress()
        _ = press.appear(.init())
        let downResult = press.activate()
        let down = try #require(downResult)
        let oldReturnResult = press.complete(down)
        let oldReturn = try #require(oldReturnResult)
        let nextDownResult = press.update(.init(isHeld: true))
        let nextDown = try #require(nextDownResult)
        _ = press.activate()
        _ = press.update(.init())
        let nextReturnResult = press.complete(nextDown)
        let nextReturn = try #require(nextReturnResult)
        let result6 = press.complete(oldReturn)
        #expect(result6 == nil)
        #expect(press.phase == .releasing)
        _ = press.complete(nextReturn)
        #expect(press.phase == .resting)
    }

    @Test func disappearanceInvalidatesDescentCompletion() throws {
        var press = RecessedPress()
        _ = press.appear(.init())
        let downResult = press.update(.init(isHeld: true))
        let down = try #require(downResult)
        press.disappear()
        let result7 = press.complete(down)
        #expect(result7 == nil)
        #expect(press.phase == .resting)
        let result8 = press.activate()
        #expect(result8 == nil)
        let result9 = press.appear(.init())
        #expect(result9 == nil)
        #expect(press.phase == .resting)
    }

    @Test func disappearanceInvalidatesReturnAcrossReappearance() throws {
        var press = RecessedPress()
        _ = press.appear(.init())
        let downResult = press.activate()
        let down = try #require(downResult)
        let oldReturnResult = press.complete(down)
        let oldReturn = try #require(oldReturnResult)
        press.disappear()
        _ = press.appear(.init())
        let nextDownResult = press.activate()
        let nextDown = try #require(nextDownResult)
        let nextReturnResult = press.complete(nextDown)
        let nextReturn = try #require(nextReturnResult)
        _ = press.complete(oldReturn)
        #expect(press.phase == .releasing)
        _ = press.complete(nextReturn)
        #expect(press.phase == .resting)
    }

    @Test func toolbarPulseDuringReturnRestartsDescent() throws {
        var press = RecessedPress()
        _ = press.appear(.init())
        let downResult = press.update(.init(pulse: 1))
        let down = try #require(downResult)
        let oldReturnResult = press.complete(down)
        let oldReturn = try #require(oldReturnResult)
        let nextDownResult = press.update(.init(pulse: 2))
        let nextDown = try #require(nextDownResult)
        _ = press.complete(oldReturn)
        #expect(press.phase == .pressing)
        let nextReturnResult = press.complete(nextDown)
        let nextReturn = try #require(nextReturnResult)
        _ = press.complete(nextReturn)
        #expect(press.phase == .resting)
    }

    @Test func toolbarPulseCannotReleaseAHeldCard() throws {
        var press = RecessedPress()
        _ = press.appear(.init())
        let downResult = press.update(.init(isHeld: true))
        let down = try #require(downResult)
        let result10 = press.update(.init(isHeld: true, pulse: 1))
        #expect(result10 == nil)
        let result11 = press.complete(down)
        #expect(result11 == nil)
        #expect(press.phase == .pressed)
        _ = press.activate()
        let upResult = press.update(.init(pulse: 1))
        let up = try #require(upResult)
        _ = press.complete(up)
        #expect(press.phase == .resting)
    }

    @Test func cancelledPressDoesNotConsumeTheNextQuickTap() throws {
        var press = RecessedPress()
        _ = press.appear(.init())
        let downResult = press.update(.init(isHeld: true))
        let down = try #require(downResult)
        _ = press.update(.init())
        let cancelledReturnResult = press.complete(down)
        let cancelledReturn = try #require(cancelledReturnResult)
        let nextDownResult = press.activate()
        let nextDown = try #require(nextDownResult)
        _ = press.complete(cancelledReturn)
        let nextReturnResult = press.complete(nextDown)
        let nextReturn = try #require(nextReturnResult)
        _ = press.complete(nextReturn)
        #expect(press.phase == .resting)
    }

    @Test func twoModeTogglesStillProduceAnActivationSignal() throws {
        var mode = TodayPageMode()
        var press = RecessedPress()
        _ = press.appear(.init())
        mode.toggle(from: .card)
        let downResult = press.activate()
        mode.toggle(from: .card)
        let secondAction = press.activate()
        #expect(secondAction == nil)
        #expect(mode.selection == .first)
        let down = try #require(downResult)
        let upResult = press.complete(down)
        let up = try #require(upResult)
        _ = press.complete(up)
        #expect(press.phase == .resting)
        mode.toggle(from: .toolbar)
        #expect(mode.toolbarActivations == 1)
    }
}
