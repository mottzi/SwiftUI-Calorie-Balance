# Recessed card quick tap research

Research date: 2026-10-10. Scope: preserve the card's complete press into its rim after a quick tap, with native SwiftUI button interaction, native animation curves, 50% inward movement, held feedback, and toolbar feedback.

## Recommendation

Keep the native `Button` and a parent-owned `RecessedCardFeedback` shared by its action and style. The action calls `activate()` synchronously before changing selection. The style supplies physical held state and toolbar pulse revisions. A rendered card activation counter is no longer needed. This avoids the split touch-up and activation updates reproduced in the native capture below.

`RecessedPress` sequences feedback and guards completion callbacks with generation tokens. The controller uses `.easeOut(duration: 0.15)` for descent and `.smooth(duration: 0.24)` for return. Release waits for native `withAnimation(..., completionCriteria: .removed)` completion and reads the latest held state. Scale and offset still provide the 50% inward movement. Apple supplies interpolation and completion; the app supplies the rule that a quick tap completes its descent. [withAnimation completion](https://developer.apple.com/documentation/swiftui/withanimation(_:completioncriteria:_:completion:)), [removed completion](https://developer.apple.com/documentation/swiftui/animationcompletioncriteria/removed), [ButtonStyle](https://developer.apple.com/documentation/swiftui/buttonstyle)

The controller coalesces actions during an existing descent or held stroke. A fresh quick tap or toolbar pulse during return starts another descent. Disappearance resets feedback and invalidates outstanding callbacks. There are no deadlines, tasks, gesture replacements, or custom animation interpolators. `TodayPageMode` retains selection and the toolbar revision.

The first candidate was the existing `phaseAnimator` driven by the selected mode. Apple's guide explicitly demonstrates `[false, true]` with a trigger as an outward-and-return pulse, so a third rest phase is not required by the documented API. [Apple timing and movement guide](https://developer.apple.com/documentation/swiftui/controlling-the-timing-and-movements-of-your-animations)

In simulator recordings, this card composition reached the full inset but remained depressed after activation. Moving the transforms out of the nested animation closure did not fix that composition. The completion latch passed the same check. This is a result for our tested composition, not a diagnosis of a SwiftUI framework bug. See verification below.

## What regressed

Before the fix, [RecessedCardStyle.swift](../../Count.kcal/Dashboard/RecessedCardStyle.swift) used `configuration.isPressed || pulsing`. Only the toolbar changed its pulse trigger. The card action changed `todayPageMode` but supplied no event pulse. A successful simulator HID tap toggled the mode with 0.00 pt peak inward movement. A hold still reached the full 5 pt inset per side. These recordings isolated the lost activation feedback from the geometry code.

`isPressed` describes the current pressing state. It does not represent a completed activation or a minimum display interval. A successful button action is the relevant event even when touch-down feedback is brief. [isPressed](https://developer.apple.com/documentation/swiftui/buttonstyleconfiguration/ispressed), [Button](https://developer.apple.com/documentation/swiftui/button)

The earlier custom implementation retained the depressed target until descent completed. Removing that rule changed the behavior, not only its implementation. A spring handles interrupted state changes smoothly, but that does not guarantee the old target will be reached before the target changes again. [Apple spring animation documentation](https://developer.apple.com/documentation/swiftui/animation/spring)

## Native choices

| Choice | Useful behavior | Cost or limit |
| --- | --- | --- |
| Activation-triggered `phaseAnimator` | Native event sequence using the same animations as normal state changes. The animator advances after each animation, then returns to its initial phase. | Must verify overlap with physical held state and changes arriving during a pulse. |
| Completion latch with `withAnimation(.smooth)` | Holds the down target until native completion, then releases or remains down according to current touch state. | Needs a few private state values and explicit coalescing of repeated presses. |
| `keyframeAnimator` | Specifies intermediate values, independent tracks, and holds. New triggers replace the current animation from its interpolated value and preserve velocity for spring or cubic keyframes without custom initial velocity. | Adds timing and track definitions that this two-state motion does not need. |
| Custom `PrimitiveButtonStyle` or gesture | Can define custom interaction behavior. | Moves away from the requested standard button interaction and is unnecessary for visual feedback. |

Sources: [Apple phase animation session](https://developer.apple.com/videos/play/wwdc2023/10157/), [withAnimation completion](https://developer.apple.com/documentation/swiftui/withanimation(_:completioncriteria:_:completion:)), [keyframe animator](https://developer.apple.com/documentation/swiftui/view/keyframeanimator(initialvalue:trigger:content:keyframes:)), [ButtonStyle](https://developer.apple.com/documentation/swiftui/buttonstyle), [PrimitiveButtonStyle](https://developer.apple.com/documentation/swiftui/primitivebuttonstyle)

## Completion latch details

For full descent, `.removed` is stricter than `.logicallyComplete`. Logical completion can occur while the spring still has a tail. Removed completion waits until the associated animations are finished, including subsequent animations created on the affected properties. Keep the completion attached only to the press transforms. [logicallyComplete](https://developer.apple.com/documentation/swiftui/animationcompletioncriteria/logicallycomplete), [removed](https://developer.apple.com/documentation/swiftui/animationcompletioncriteria/removed)

Read the latest held state when completion runs. Do not capture the old `configuration.isPressed` value from touch-down and treat it as current. Coalesce another press while already descending instead of starting another descent with another callback. A native completion always runs once, and it runs immediately when the transaction creates no animations. Those rules also require a safe Reduce Motion path. [withAnimation completion](https://developer.apple.com/documentation/swiftui/withanimation(_:completioncriteria:_:completion:))

`.smooth` supplies a preset spring with no bounce. The design uses this preset with the user-approved press and release durations. [smooth](https://developer.apple.com/documentation/swiftui/animation/smooth)

## Acceptance cases

- A quick successful tap reaches 4 pt depth and 5 pt inward movement per side, then returns.
- A long hold remains depressed and has one return after release, with no second descent.
- A short press that did render touch-down does not reverse before full depth or produce a visible gap.
- Rapid activations keep movement continuous and leave the card at rest afterward.
- A toolbar activation produces the same pulse; activation while the card is held does not release it.
- Reduce Motion uses the existing opacity feedback and does not leave a depressed target behind.
- A canceled press preserves normal button activation behavior.

These are app acceptance criteria. They are not claims that Apple has tested this card.

## Historical verification results

These recordings verified geometry and visible feedback but did not establish native event ordering. The later buffered capture below reproduced a held-release replay that these checks missed.

Tested the signed Debug build on iPhone 18 Pro Simulator, iOS 27. Recorded the actual UI at 30 fps and measured the card's left edge on a row through its face. The screen uses 3 pixels per point. Rest was x=48 and full press was x=63, giving 5 pt inward travel per side, half the fixed 10 pt rim inset.

| Case | Observed result |
| --- | --- |
| Simplified implementation, quick HID tap | Mode toggled, 0 pt inset. Regression reproduced. |
| Mode-triggered phase animator composition | 5 pt inset, failed to return to rest. Rejected. |
| Completion latch, quick HID tap | 5 pt inset, then returned to x=48. Passed. |
| Completion latch, 150 ms down/up | Full 5 pt inset before returning. Passed. |
| Long held press | Stayed at x=63; screenshot showed the rim covered. |
| Release after long hold | Edge moved monotonically from x=63 to x=48. No second inward stroke. |
| Toolbar activation | Full 5 pt inset and return. Passed. |
| Four repeated successful taps | Four visible strokes, correct final mode, returned to x=48. Passed. |

The automation serialized repeated taps roughly one second apart, so that recording does not establish behavior for several activations within one animation frame. The code coalesces activations while moving. Sub-frame multi-touch overlap and the system Reduce Motion setting were not exercised in this recording run. The Reduce Motion branch retains opacity feedback while suppressing scale and translation.

The 4 pt downward target and uniform scale remain in the style. This investigation's quantitative video assertion measured inward travel and return, not the vertical displacement or every element's aspect ratio.

Recordings and measurement scripts stayed in `/tmp`, outside the repository's generated preview folder. Builds and installation results are reported separately in the chat.

## Local SDK check

The installed Apple SDK declares `phaseAnimator` with `trigger: some Equatable`, exposes the native completion overload of `withAnimation`, and implements `Animation.smooth` through the preset smooth spring. This confirms callable public interfaces, not hidden runtime scheduling.

Inspected source:

`/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/System/Library/Frameworks/SwiftUICore.framework/Modules/SwiftUICore.swiftmodule/arm64e-apple-ios.swiftinterface`

Relevant declarations were at lines 12978, 16792 through 16796, and 18169 when inspected.

## Timing refinement

After the user tried the completion latch, its default `.smooth` timing felt too long. The quick-tap recording measured 1.00 seconds of visible down-and-return motion. The approved refinement uses `.smooth(duration: 0.15)` down and `.smooth(duration: 0.24)` back, with `.removed` completion and the same 50% inset.

The signed simulator build passed the quick-tap check again at 5 pt inward travel per side, then returned to x=48. Visible motion measured about 0.47 seconds in the 30 fps recording. A 600 ms held press reached the full inset and returned once. Toolbar feedback also reached the full inset and returned. Both iPhone and simulator builds succeeded.

## Earlier defensive behavior restoration

The following results describe the counter-based implementation before the native event-order regression was identified.

The completion latch now separates sequencing from rendering. `RecessedPress` accepts the same combined input used by the style and returns the next motion. SwiftUI still interpolates the native scale, offset, and opacity and reports completion. `TodayPageMode` keeps event identity beside selection, with one binding passed through the dashboard and toolbar.

The extracted pre-hardening rules failed six deterministic tests: a quick tap during return, a toolbar pulse during return, a quick tap following cancellation, a descent completion after disappearance, and stale return completions during a newer return with and without reappearance. After restoring event handling and generation guards, all 11 press tests and all 26 app tests passed. The tests exercise actual production sequencing with deliberately reordered completion callbacks, rather than relying on wall-clock sleeps.

Fresh 30 fps simulator recordings confirmed quick taps, a 600 ms hold, and toolbar feedback each reach x=63 from x=48, then return once to x=48. In each recording the edge after the first peak never moves inward again, so held touch-up does not replay its stroke. Signed builds succeeded; the updated app was installed and launched on iPhone and Simulator. Rapid native interaction verification is recorded separately below.

Additional native checks passed for a 120 ms hold and leaving Today for yesterday, returning, and tapping again. The short hold had one full inward stroke and a monotonic return. The reappeared card rested at x=48 and its next tap still reached x=63 and returned.

The Xcode interaction tool settled between chained taps despite a requested 200 ms gap. Its multi-touch keyframe commands produced no interaction, and its double-tap command produced only one successful activation. These recordings do not prove exact overlapping-return timing or disappearance during an active stroke. The deterministic production sequencing tests cover those event orders; UI recordings cover ordinary activations and navigation recovery. System Reduce Motion was not toggled during this run.

## Native event-order regression

The earlier verification checked mode changes and sampled geometry but missed a split rendered update. Buffered native tracing on iOS 27 reproduced an extra press in 10 of 10 long holds across two capture runs. The native action ran first. SwiftUI then delivered touch-up with the old activation revision, starting release, followed by the new revision with held state already false, starting another descent. Logging was buffered until rest in the second run, so console output did not occur during active motion.

The fix calls the shared feedback controller directly from the native action. Mode rendering can no longer supply a delayed duplicate activation. Debug instrumentation remains in `RecessedCardFeedback.swift`, opt-in with `COUNT_RECESSED_TRACE=1`, and buffers events until rest or disappearance. Release builds omit it.

All 29 app tests passed after the change. Added production-sequencing coverage exercises the captured native-action/held-update/mode-render order, delayed touch-down, and cancellation followed by a quick action during return. Stale completions and lifecycle reset coverage remain.

The initial fixed native capture verified one held stroke with one return and no replay. Another installation terminated the captured simulator process, as recorded by `installcoordinationd`. Subsequent samples from that run were excluded. Verification continued on a separate simulator with an immutable copy of the tested build.

The isolated iPhone 18 Pro simulator, iOS 27, completed five long holds, five quick taps, two short taps, two fresh taps following cancellation, and two toolbar pulses. Buffered traces recorded 14 successful card actions and 16 complete feedback cycles. Every cycle had one descent and one return, with no release-to-press replay. All five held actions occurred in the pressed phase and returned once, compared with 10 of 10 replaying held releases before the fix.

Both drag-away cancellation attempts left the mode unchanged and emitted no activation. They did not render a held stroke in the trace, so they do not verify cancellation during an active return. The deterministic tests cover that timing. The interaction tool serialized subsequent taps, so exact overlapping-return timing remains a unit-test assertion.

Frame analysis of the held recording measured x=48 to x=63 to x=48 at a row through the card face, confirming 5 pt inward travel per side and a monotonic return. The quick recording reached x=63 and began a monotonic return, but its recording stopped at x=50 before the tail finished. Its native completion trace reached rest. Recording timestamps were variable; no timing claim relies on nominal recording frame rate.

Captured logs, event analysis, videos and frame measurements are under `/tmp/count-kcal-native-order/`, including `isolated-fixed-console.log`, `analysis-isolated-fixed.json`, `isolated_hold.mp4` and `isolated_quick.mp4`. The signed device build was installed on the iPhone. Automatic launch was denied because the phone was locked.

The final settled screenshot measured the card edge at x=16 at 402 px screen width, corresponding to x=48 in the 1206 px video. Together with the quick recording and completion trace, this confirms the quick-tap feedback reached 5 pt inset and settled back to rest. The verification session was closed and the fixed simulator app relaunched with tracing disabled.
