# Circle balance graph animation

Researched on 2026-10-11 against Apple documentation, WWDC sessions, and the installed Xcode 27.0 SDK interface. Updated 2026-10-17 after reproducing abrupt Now/Midnight movement at extreme calorie scales.

## Architecture decision

Use a shared pure `EnergyGraphValues` model to normalize and partition the four calorie values. One stable native `Circle.trim` hierarchy draws its segments in the iOS app, watch app, widgets, and complications. Keep projected resting present when its length is zero. All hosts share the partition math, radius-based gap calculation, segment ordering, and drawing.

`EnergyGraphValues` uses `@Animatable` to interpolate four `Double` calorie values and four normalized endpoints. Each snapshot divides active, recorded resting, total burned, and consumed energy by its own `max(burned, consumed)`. Empty snapshots use zero endpoints. During motion the endpoints interpolate directly, without division by an animated calorie total. Numeric labels retain their complete target values and native `.numericText` transitions.

The live iOS and watch apps use `CalorieGraphDrawing.AnimatedDrawing`, a small `View, Animatable` driver. Its explicit `animatableData: EnergyGraphValues.AnimatableData` getter and setter forward the model's synthesized animation data. Configuration and palette are ordinary nonanimated properties. The shared drawing derives adaptive gaps from the current endpoints on every frame. The driver disables descendant animations so native trims draw that frame immediately, without starting a second interpolation. Bar fill drawing and label layout use the same endpoints.

Widget and complication hosts bypass the driver. They feed complete target geometry into the same native renderer and let the system interpolate its archived trim endpoints. The host context is fixed for each embedding location. This adapter exists because a live SwiftUI application and an archived WidgetKit representation execute in different ways. Apple documents built-in widget animations but does not promise execution of arbitrary custom interpolation code there. [Animating data updates in widgets and Live Activities](https://developer.apple.com/documentation/widgetkit/animating-data-updates-in-widgets-and-live-activities), [Bring widgets to life, WWDC23](https://developer.apple.com/videos/play/wwdc2023/10028/).

Both paths preserve settled normalization, segment ordering, and continuous movement. During a crossover, both paths interpolate normalized endpoints. Their intermediate trajectories can differ, while both avoid forcing one endpoint to full length before the transition finishes. Both paths share one renderer; only the owner of frame interpolation differs.

## Stable segments and separators

Preserve the existing outer ordering and screenshot semantics: active, recorded resting, predicted resting, then any empty remainder. Use three fixed child views, or a fixed collection identified by an enum. Do not filter zero values, identify views by their changing calorie values, or replace the whole graph with `.id(mode)`.

Apple describes shared identity as different states of one conceptual element. Distinct identities instead describe distinct elements that transition independently. Keeping the projection as a zero-length segment applies that identity model to this graph. [Demystify SwiftUI, WWDC21](https://developer.apple.com/videos/play/wwdc2021/10022/).

At Now, collapse the predicted segment to the end of recorded resting, before any empty remainder. Give it identical native trim start and end values. Preserve its color treatment across modes. Its growth already reveals the color, so a mode-driven opacity fade adds another changing value without being needed for appearance.

Calculate all segment ranges, both gray remainders, and any separators from the same shared geometry. Live apps calculate it from the current interpolated endpoints. Widgets calculate it from each timeline snapshot. A transparent separator can simply be the uncovered space between adjacent trims. A full background ring would fill that space with gray, so any gray support behind translucent accented segments must use the same segmented ranges.

For a nominal two-point gap, calculate the angular half-gap from the ring's actual radius and visible arc length. Each segment owns its leading and trailing cuts. For normalized start `s`, end `e`, and nominal half-gap `h`, the current implementation uses `leading = min(h, (e-s)/4, s/4)` and `trailing = min(h, (e-s)/4, (1-e)/4)`. It draws `s+leading ... e-trailing`.

This rule depends on the segment's own length and distance to the respective outer arc edge. A zero-length slot owns zero cuts. Neighboring segments retain their own continuous cuts when projection grows from zero to a small positive value. Searching for nearest nonzero neighbors would change the selected neighbor at that instant and could abruptly change an existing separator. With the implemented rule, a tiny middle segment retains at least half its original length, and separators vanish smoothly at the outer arc edges. These are mathematical consequences of the shared gap formulas. Do not remove a zero slot's view or position in the hierarchy.

The following is a mathematical inference, not a separate Apple rendering guarantee. Suppose each snapshot has ordered ranges satisfying `start[i] <= end[i] <= start[i+1]`. If every native endpoint uses the same interpolation fraction `t` in `0...1`, then every inequality remains true because each difference is a weighted average of nonnegative endpoint differences. A zero-length segment can therefore grow without crossing its neighbors. Gaps also grow or shrink continuously. This proof covers bounded endpoint interpolation; spring extrapolation needs separate treatment.

Attach a single `.animation(_:value:)` using the complete energy input. In live apps this animates the endpoint driver, whose descendant transaction disables additional interpolation. Each frame then uses one normalized partition for every endpoint and gap. In widgets the driver and its descendant transaction override are absent, allowing the native trim endpoints to receive the system animation. Apple explains that transactions carry animation context and built-in animatable attributes interpolate their presentation values without calling application view code. [Explore SwiftUI animation, WWDC23](https://developer.apple.com/videos/play/wwdc2023/10156/).

The graph uses `.smooth` with its default duration of 0.5 seconds, adjustable through configuration. The Today card uses the same curve and duration for its numeric content transitions. Reduce Motion disables animation. Live drawing clamps endpoints to ordered ranges within `0...1`, keeping segments valid if a parent supplies extrapolated animation data. Stored animation data remains unchanged so these bounds do not alter interpolation.

## Widget view identity

The ring's `ForEach` uses the stable string raw value of `EnergyGraphValues.Part` as its identity. Using the enum value directly preserved identity in the app but caused Home Screen widget arcs to jump between snapshots in this composition. Replacing the collection with fixed structural children restored interpolation. Keeping the collection and changing only its identities to strings also restored interpolation, without changing calculations, the native circle trims, or the animation trigger.

This was reproduced on an iOS 27 Simulator with Reduce Motion off. A recording of the original Now/Midnight toggle loop contained 105 frames and zero intermediate consumed-arc endpoint positions. The same loop with string identities contained 101 frames, including 53 intermediate frames with 14 distinct intermediate angles. Small and medium widgets shared the update. The test sampled the colored arc rather than the animated numbers or widget dimming.

This is an observed archive-matching behavior, not an Apple-documented restriction on enum identities. `ForEach` requires a `Hashable` identity, and `.animation(_:value:)` requires an `Equatable` trigger. The complete `EnergyGraphValues` trigger remains unchanged. A unit test of the partition math cannot exercise this WidgetKit archive behavior; the regression check must run in a real widget host. [ForEach](https://developer.apple.com/documentation/swiftui/foreach), [Widget animation guidance](https://developer.apple.com/documentation/widgetkit/animating-data-updates-in-widgets-and-live-activities).

## Energy interpolation versus endpoint interpolation

The October 11 implementation interpolated raw calorie values and a common scale. That fixed a different early-stop problem: recalculating `max(burned, consumed)` on every frame made the formerly smaller ring reach full length halfway through a balance crossover. Animating the scale kept both changing endpoints moving, but did not distribute their visible travel evenly for extreme totals.

The October 17 recording showed Now burned/consumed energy `3/2` and Midnight `1717/2`. At 10% interpolation, dividing by the animated scale placed the consumed endpoint at `0.01147`, down from `0.66667`. Nearly all visible travel happened at the beginning, while the number transition continued. In reverse, movement was compressed near the end. A bouncy scale could also cross zero and temporarily collapse both colored graphs.

The current implementation normalizes each snapshot first, then interpolates its endpoints. The same 10% sample is `0.60012`, and halfway is `0.33392`. Every changing endpoint uses the whole transition regardless of the ratio between calorie totals. Both rings can have unused space during a balance crossover; their settled normalization is unchanged. Empty graphs reveal from zero endpoints without a separate presence multiplier.

`zsh Tests/run-graph-transitions.sh` exercises production `animatableData`. The original implementation failed the 10% extreme-case assertion. The replacement passes that check and 144 snapshot pairs sampled at 101 positions each, including both supplied recordings, empty states, crossovers, and large digit changes. Additional samples verify ordered bounded geometry under extrapolation and retargeting without a presentation jump. These checks verify interpolation math, not font rendering or the WidgetKit animation host.

Simulator recordings of the production calorie card verified both directions for early-day extremes, ordinary balance crossover, narrow labels, empty data, and 99-to-10,000 calorie changes. Bars, rings, and labels moved through intermediate positions without the previous collapse or endpoint jump. The temporary fixture screen was removed afterward. The 12 existing bar-fill and circle-ring rendering tests passed on the final source. UI automation serialized rapid taps, so interrupted transitions were checked in the model rather than established by those recordings. The recordings do not verify Home Screen widget animation.

A custom `Shape` suits a single path. It cannot by itself provide the ring's multiple independently shaded segments. Multiple custom shapes can receive identical animated data, but this repeats per-frame calculations and still relies on custom application code. Neither approach solves the archived-widget constraint.

Apple's `Animatable` documentation states that SwiftUI interpolates `animatableData` and invokes its setter on successive frames. The macro synthesizes data for the scalar model. Geometry derives from current fields rather than a custom normalization setter. The view's handwritten conformance only forwards `EnergyGraphValues.AnimatableData`. [Animatable](https://developer.apple.com/documentation/swiftui/animatable).

During implementation, applying `@Animatable` to the containing view failed compilation because synthesis inferred an opaque `some VectorArithmetic` from the macro-backed model. Explicitly naming and forwarding `EnergyGraphValues.AnimatableData` resolved that issue while keeping macro synthesis on the scalar model. This is a project implementation finding, not a documented general limitation of every nested animatable type.

Normalize each snapshot first, then interpolate its resulting angular endpoints. For example, start with burned/consumed ratios `0.5/1` and end with `1/0.5`. At halfway the interpolated endpoints are `0.75/0.75`. Recomputing the maximum from halfway energy would make both `1`, but introduces the early stop described above. The live renderer recalculates adaptive gaps from the current segment lengths. In WidgetKit, gap limits calculated at endpoint snapshots are interpolated with native trim geometry.

The live adapter supplies interpolated normalized endpoints and current-length adaptive gaps. The widget adapter supplies settled normalization and continuous ordered native motion. During a crossover, either path can show unused space in both rings while the graph resizes. This is deliberate transition behavior; the larger side fills its ring in the settled state. Arbitrary nonlinear per-frame calculations inside WidgetKit cannot be guaranteed using only the documented native endpoint animation model.

## SDK and deployment support

The project sets iOS deployment to 17.0 and watchOS deployment to 10.5. Its Swift language mode is 5.0. The installed toolchain is Xcode 27.0, build 27A266a.

The installed Apple `SwiftUICore.swiftinterface` declares these availabilities:

| API | iOS | watchOS | Consequence |
| --- | --- | --- | --- |
| `Animatable` | 13.0 | 6.0 | Available throughout this project's deployment range. |
| `@Animatable` and `@AnimatableIgnored` | 13.0 | 6.0 | Current SDK macros are back-deployed. Their WWDC25 introduction does not mean their declared runtime minimum is 26. |
| `AnimatableValues` | 26.0 | 26.0 | Cannot be used unguarded by shared code at the current minimum targets. |
| `AnimatablePair` | 13.0 | 6.0 | Available if explicit animation data is needed at these deployment targets. |

The interface also exposes a pre-26 macro expansion helper using `AnimatablePair`, alongside the 26+ `AnimatableValues` helper. No macro expansion compilation probe was performed during this research. The final scalar model uses `@Animatable`; the live view forwards its named `AnimatableData` type. Geometry derives from current model fields, so no handwritten normalization setter or explicit pair construction is needed. [Animatable](https://developer.apple.com/documentation/swiftui/animatable), [What's new in SwiftUI, WWDC25](https://developer.apple.com/videos/play/wwdc2025/256/).

Local primary source: `/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/System/Library/Frameworks/SwiftUICore.framework/Modules/SwiftUICore.swiftmodule/arm64e-apple-ios.swiftinterface`, lines 7272, 18933, and 19863 onward. Availability statements describe this installed SDK, not every historical Xcode version.

## WidgetKit and watchOS constraints

Widget animations compare timeline-entry representations. Widget extensions generate and archive their views; the system displays those archives in another process. Apple's WWDC23 explanation states that view code runs during archiving. A custom animatable parent's per-frame body recomputation therefore cannot be assumed to execute during an archived widget animation. Prefer native trim and transform parameters that the system can animate. This is an architecture-based inference; Apple does not publish a guarantee for every custom Shape path interpolation case. [Bring widgets to life, WWDC23](https://developer.apple.com/videos/play/wwdc2023/10028/).

WidgetKit caps animation duration at two seconds, supports built-in transitions and animations, and suppresses animation in Always On. Its animation article also says that `Transaction` is unavailable to widgets and Live Activities, so do not rely on clearing a transaction's animation to control widget behavior. Use the documented animation modifiers. [Animating data updates in widgets and Live Activities](https://developer.apple.com/documentation/widgetkit/animating-data-updates-in-widgets-and-live-activities).

The watch app is a running SwiftUI application, while its WidgetKit complications and Smart Stack widgets use timelines. Keep that distinction when evaluating animation support. Apple documents that widgets and watch complications hand timelines to WidgetKit, with updates scheduled and budgeted by the system. [Developing a WidgetKit strategy](https://developer.apple.com/documentation/widgetkit/developing-a-widgetkit-strategy).

For a watch app's Always On state, `TimelineView` cadence can drop to seconds or minutes. Apple advises replacing animation with a static representation when cadence drops. Continuous animation is not a dependable background mechanism for either widgets or the watch app. [Updating watchOS apps with timelines](https://developer.apple.com/documentation/watchos-apps/updating-watchos-apps-with-timelines).

The documentation establishes the supported design and the mathematical conditions for continuity. It does not establish that a particular physical Home Screen widget or complication will animate every update. That remains a device-observation question.
