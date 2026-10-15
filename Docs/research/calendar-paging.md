# Native calendar paging

Research date: 2026-10-15.

The user reports that the custom 100-point snap rule fixes some short swipes but makes very small, moderately fast gestures look wrong. The supplied recording is the acceptance reference. This note separates Apple's documented behavior from conclusions about this app.

Frame analysis of the supplied recording found a particularly useful event: the page offset changes from about -18 points at 3.8833 seconds, to -28 points at 3.9000 seconds, then directly to 0 points at 3.9167 seconds. There is no selected-date change in this event. That abrupt cancellation is a separate issue from whether 100 projected points should turn the page.

## Measured comparisons

These results come from the app's controlled simulator replays, not Apple's documentation or a completed physical-iPhone verification.

| Candidate | Result |
| --- | --- |
| Original 100 projected-point policy | Tiny gestures can return abruptly, matching the supplied symptom. |
| Same policy, animation scoped to programmatic navigation | The 38-point gesture over 0.06 seconds still returns abruptly. The animation change does not fix this replay and was discarded from the final source. |
| Direct native `.paging` | Tiny gestures return smoothly and genuine fast flicks work. The original intentional 117-point slowing swipe still cancels. This restores the original product complaint. |
| Native paging delegation plus a 100 actual-point slow-drag supplement, candidate 4 | Core replay passes. The historical 38-point gesture over 0.06 seconds turns one page smoothly; 38 points over 0.12 seconds stays smoothly. The original 117-point slowing gesture advances one page in both directions. |
| Same delegation with a captured drag origin and mismatch guard, candidate 5 | Extended UI controls pass. The original 117-point profile advances in both directions. Stopped 38- and 81-point gestures stay. Fast 110-point flicks advance one page in both directions. Interrupted repeated gestures advance two days; immediate inverse gestures return smoothly with zero abrupt cancellations. Vertical scrolling leaves the date unchanged. |
| Final implementation, candidate 6 | Restores the original animation modifier, retains native delegation and the actual-travel supplement, and requires an aligned drag origin. The exact historical tiny regression advances smoothly with zero abrupt cancellations. The original 117-point profile advances exactly one page in both directions. Adjacent calendar navigation and week navigation animate and synchronize. A seven-day calendar jump synchronizes immediately. Physical build and eight policy tests pass. Installed and launched on the iPhone successfully. |

## Recommendation

The final implementation delegates the public properties and target calculation to `PagingScrollTargetBehavior`, then supplements only a native cancellation after at least 100 actual points of net scroll movement from a settled page. It retains full-width pages, zero stack spacing, stable date IDs, the existing outer vertical scroll view, and the shared day/week selection model. The critical gesture and navigation simulator checks, policy tests, physical build, and iPhone installation and launch pass. Physical-iPhone gesture quality remains unverified by these checks.

The original intentional 117-point slowing swipe must continue to turn a page. It is part of the user's requested behavior. A native control cancelling that gesture does not make the product requirement invalid. The direct `.paging` replay is a diagnostic control, not an acceptable final fix if it restores the original complaint. Apple explicitly supports custom scroll target behavior. Describe the candidate accurately as native paging calculation with a custom slow-drag supplement, rather than claiming complete equivalence with direct `.paging`. [Apple, custom scroll target behavior](https://developer.apple.com/documentation/swiftui/scrolltargetbehavior).

Removing the 100-point rule deliberately changes the page-acceptance policy. It is a fix for the one-frame cancellation only if the matched replay removes that cancellation, and it is a complete product fix only if it also meets the intentional short-swipe requirement. Verify true release-velocity flicks, tiny nudges, cancellation, and interruption before choosing the final implementation. Apple does not publish a universal 100-point or 50-percent acceptance rule for `.paging`. [Paging behavior](https://developer.apple.com/documentation/swiftui/pagingscrolltargetbehavior), [WWDC23, Beyond scroll views](https://developer.apple.com/videos/play/wwdc2023/10159/).

The successful matched replays do not justify migrating the layout to a different control. If later physical evidence exposes a remaining limitation, `TabView` with `.page(indexDisplayMode: .never)` is another system-pager candidate. A `UIPageViewController` bridge is a further option when explicit completed/cancelled transition events are necessary. Both replacements need layout, acceptance and nested-scroll verification; neither should be declared a fix from API names alone.

## Final implementation semantics

`CalendarPagingBehavior` now delegates `properties(context:)` to `PagingScrollTargetBehavior` and asks the same type to calculate `updateTarget` first. The modifier captures `dragOrigin` from the phase-change context's actual horizontal content offset when tracking starts. If an input skips tracking, it captures that offset on the first interacting phase only if no origin exists. It clears the origin at idle. Apple describes tracking as touch tracking before scrolling begins, notes that some kinds of input skip that phase, and documents the phase-change geometry as the geometry at the transition. [Apple, tracking](https://developer.apple.com/documentation/swiftui/scrollphase/tracking), [Apple, phase geometry](https://developer.apple.com/documentation/swiftui/scrollphasechangecontext/geometry).

The custom rule runs only during the interacting or decelerating phases, with a captured origin, horizontal scrolling, a positive width, and a starting-target width within 0.5 points of the current viewport width. The captured origin must be within 0.5 points of a page boundary and must match `originalTarget.rect.minX` within 0.5 points. If these checks fail, the native calculation remains unchanged. This avoids applying the supplement when a new gesture starts between pages, or when the captured actual start and framework target start disagree. These guards are application policy. The interruption replay passes, but the documentation does not guarantee a particular ordering of those events. [Apple, originalTarget](https://developer.apple.com/documentation/swiftui/scrolltargetbehaviorcontext/originaltarget), [Apple, updateTarget](https://developer.apple.com/documentation/swiftui/scrolltargetbehavior/updatetarget(_:context:)).

After the guards pass, if the native target remains at the starting page and `contentOffset.x - dragOrigin` has a magnitude of at least 100, the candidate targets the adjacent page in the direction of that net movement. A native destination that already changes pages wins, including native velocity-sensitive decisions. The final supplemented result is clamped to the adjacent-page range and content bounds. These details describe the repository's implementation, not an Apple-prescribed algorithm. Early guard exits intentionally preserve the native result without this custom clamp.

The meaning of 100 points therefore changes. It previously measured the proposed stopping point, which includes momentum. It now measures actual net content movement from the captured touch/drag origin. It does not count the total out-and-back path length. A tiny fast flick can still turn a page if native paging accepts it. A tiny gesture that native paging cancels does not gain a page merely because the earlier unsnapped projection exceeded 100. A slow intentional drag can gain a page after 100 actual points even when native paging would cancel it. Apple's public APIs support using a native behavior's target calculation and observing actual scroll geometry. They do not guarantee that this composite has every hidden trait of direct `.paging`. [Apple, ScrollTargetBehavior](https://developer.apple.com/documentation/swiftui/scrolltargetbehavior), [Apple, scroll geometry change](https://developer.apple.com/documentation/swiftui/view/onscrollgeometrychange(for:of:action:)), [Apple, contentOffset](https://developer.apple.com/documentation/swiftui/scrollgeometry/contentoffset).

`onScrollGeometryChange` observes an equatable value transformed from current scroll geometry. Apple warns that geometry changes frequently, so the implementation should keep updates local. `contentOffset` can exceed content bounds during rubber banding. The candidate observes only horizontal offset in the calendar modifier and clamps the resulting destination. Apple does not promise the last geometry callback and the target callback arrive as one atomic snapshot; verify near-threshold gestures and interrupted scrolling in the actual app. [Apple, scroll geometry change](https://developer.apple.com/documentation/swiftui/view/onscrollgeometrychange(for:of:action:)), [Apple, contentOffset](https://developer.apple.com/documentation/swiftui/scrollgeometry/contentoffset).

## What the APIs actually promise

- `updateTarget` receives the proposed natural stopping target after a gesture ends. SwiftUI computes it using the scroll view's deceleration rate. SwiftUI also calls this method when the scroll view changes size. It is not documented as an exclusive gesture-end callback. [Apple, updateTarget](https://developer.apple.com/documentation/swiftui/scrolltargetbehavior/updatetarget(_:context:)).
- `context.originalTarget` is the target when the gesture began. Apple does not promise that it is an aligned, settled page boundary. `context.velocity` is the scroll gesture's current velocity. [Apple, originalTarget](https://developer.apple.com/documentation/swiftui/scrolltargetbehaviorcontext/originaltarget), [Apple, velocity](https://developer.apple.com/documentation/swiftui/scrolltargetbehaviorcontext/velocity).
- `.paging` aligns targets to container geometry. Apple explicitly describes this behavior as special: it uses a custom deceleration rate and the containing scroll view size. The WWDC example pages one page at a time. Merely reproducing its rounding calculation does not reproduce its full behavior. [Apple, PagingScrollTargetBehavior](https://developer.apple.com/documentation/swiftui/pagingscrolltargetbehavior), [WWDC23, Beyond scroll views, targets and positions](https://developer.apple.com/videos/play/wwdc2023/10159/?time=254).
- `limitsScrolls` asks a scroll view to prefer a shorter scroll distance. The default is false. Apple does not document a numeric deceleration rate, a fixed distance, a snap threshold, or an exact one-page limit for this property. It does not document this flag as equivalent to using `.paging`. WWDC describes paging's special deceleration separately, so copying this flag alone is insufficient evidence that native paging physics are preserved. The installed iPhoneOS SDK declares it from iOS 18.4. [Apple, limitsScrolls](https://developer.apple.com/documentation/swiftui/scrolltargetbehaviorproperties/limitsscrolls), [WWDC23, Beyond scroll views](https://developer.apple.com/videos/play/wwdc2023/10159/).
- `.viewAligned` aligns to views marked by `scrollTargetLayout`. Its `.alwaysByOne` policy explicitly limits a single interaction to one view. This is a real documented limit, but the API does not expose a configurable acceptance threshold. The installed SDK declares `.alwaysByOne` from iOS 18. [Apple, view alignment](https://developer.apple.com/documentation/swiftui/viewalignedscrolltargetbehavior), [Apple, alwaysByOne](https://developer.apple.com/documentation/swiftui/viewalignedscrolltargetbehavior/limitbehavior/alwaysbyone).
- `onScrollTargetVisibilityChange` reports when views cross the requested visible fraction. The default is more than 50 percent on screen. This observes visibility; it does not determine where scrolling stops or whether a page turn has completed. [Apple, target visibility](https://developer.apple.com/documentation/swiftui/view/onscrolltargetvisibilitychange(idtype:threshold:_:)).
- `ScrollPosition` changes as the user scrolls and can also request a programmatic location. Applying `.animation(..., value: position)` therefore watches a value used by both paths. `withAnimation` can instead wrap a programmatic `scrollTo`. The measured 38-point replay still fails after making that change, while final candidate 6 passes with the original modifier restored. The final source therefore retains `.animation(..., value: position)` and the original direct `scrollTo`. Scoping animation was an unsuccessful hypothesis, not the fix. [Apple, ScrollPosition](https://developer.apple.com/documentation/swiftui/scrollposition), [Apple, animation](https://developer.apple.com/documentation/swiftui/view/animation(_:value:)), [Apple, withAnimation](https://developer.apple.com/documentation/swiftui/withanimation(_:_:)).

No public documentation found promises that forwarding `PagingScrollTargetBehavior.properties(context:)` through a custom conformer transfers the complete special paging behavior. The installed SDK exposes a separate paging implementation of `properties` and underscored graph/environment hooks. Those declarations do not document their implementation or make the underscored hooks an appropriate application integration point. There is no supported basis here for claiming a custom wrapper exactly preserves every native paging trait. The public contract does support customizing a proposed endpoint, which is sufficient for a custom policy if its measured motion meets the requirement. [Apple, ScrollTargetBehavior](https://developer.apple.com/documentation/swiftui/scrolltargetbehavior), [Apple, properties](https://developer.apple.com/documentation/swiftui/scrolltargetbehavior/properties(context:)).

## Why the former projected-distance rule was a weak fit

The source at the start of this investigation calculates:

```swift
start = round(original / pageWidth) * pageWidth
travel = projected - original
step = abs(travel) >= 100 ? sign(travel) : 0
destination = start + step * pageWidth
```

These are application decisions, not Apple's paging semantics. The projected endpoint includes momentum. A short finger movement can therefore exceed the projected threshold. Conversely, a larger movement with little release velocity can remain below it. Treating 100 projected points as 100 finger-travel points is incorrect. The projection comes from `updateTarget`'s documented calculation; the threshold and base rounding come from this repository's `CalendarPagingBehavior.destination`. [Apple, updateTarget](https://developer.apple.com/documentation/swiftui/scrolltargetbehavior/updatetarget(_:context:)).

An interrupted deceleration is particularly worth testing. If the next gesture begins between pages, rounding its starting target first can change the base page when that target crosses a midpoint. Adding a second threshold decision to this rounded base can then choose a destination unlike normal paging. For example, a start at page 14.7 rounds to page 15 before the projected-travel step is applied. A sufficient positive projection then selects page 16. This is a mathematical consequence of the code, not proof that this sequence occurred in the user's recording. Apple does not promise `originalTarget` is settled. [Apple, originalTarget](https://developer.apple.com/documentation/swiftui/scrolltargetbehaviorcontext/originaltarget).

The width comparison in `updateTarget` also cannot prove why SwiftUI called it. It is a heuristic that notices some resizes, while Apple documents size changes as a separate reason for calling the same method. No primary source found promises one call per finger lift or guarantees this width check distinguishes all calls. The final implementation first delegates native calculation and additionally guards on the observed user-scroll phase and aligned captured origin. Interrupted gestures were replayed successfully. This evidence does not cover every resize or input device. [Apple, updateTarget](https://developer.apple.com/documentation/swiftui/scrolltargetbehavior/updatetarget(_:context:)).

The current 50-percent visibility callback can update the selected date before a transition settles. A reversal may select the adjacent date and then select the starting date again. That is expected from a visibility observer, even when the native page ultimately cancels. If date-dependent UI or the other calendar strip makes this visible, commit selection when scrolling becomes idle, or use a pager with a completed-transition callback. Whether this is part of the supplied symptom requires measurement. [Apple, target visibility](https://developer.apple.com/documentation/swiftui/view/onscrolltargetvisibilitychange(idtype:threshold:_:)), [Apple, scroll phases](https://developer.apple.com/documentation/swiftui/scrollphase).

## Native alternatives and costs

| Choice | Documented behavior | Fit for this repository |
| --- | --- | --- |
| Direct `.paging` | Container-aligned settling, special native deceleration | Small diagnostic control. Keeps the existing layout, but fails the original slowing 117-point swipe in the observed replay. That remains a product limitation. |
| `.viewAligned(limitBehavior: .alwaysByOne)` | View-aligned settling with one view per interaction | Same layout and model fit. Previous slowing replay alone did not show improved behavior. Use only if measured gestures justify it. |
| `TabView(selection:)` and `.page` | System paged scrolling with a selection binding | Removes custom target math. Apple's docs do not promise intrinsic child-height sizing in an unbounded vertical scroll view, nor exact acceptance thresholds. Needs explicit sizing validation and buffered-ID insertion checks. |
| `UIPageViewController(.scroll, .horizontal)` | System gestures and page animations; adjacent controllers from a data source; explicit cancelled/completed callback | Strong explicit transition model. Adds hosting-controller identity, environment propagation, sizing, and programmatic-update coordination work. Use if the SwiftUI native choices fail acceptance. |
| Custom `UIScrollView` wrapper | `isPagingEnabled` stops at multiples of its bounds; delegate can modify the predicted stopping offset | Recreates layout, hosting and synchronization plumbing. Modifying `targetContentOffset` would still define custom snapping. No advantage established for this symptom. |

Sources for this comparison: [Apple, paging](https://developer.apple.com/documentation/swiftui/pagingscrolltargetbehavior), [Apple, view alignment](https://developer.apple.com/documentation/swiftui/viewalignedscrolltargetbehavior), [Apple, TabView](https://developer.apple.com/documentation/swiftui/tabview), [Apple, PageTabViewStyle](https://developer.apple.com/documentation/swiftui/pagetabviewstyle), [Apple, UIPageViewController](https://developer.apple.com/documentation/uikit/uipageviewcontroller), [Apple, scroll transition](https://developer.apple.com/documentation/uikit/uipageviewcontroller/transitionstyle-swift.enum/scroll), [Apple, completed transition](https://developer.apple.com/documentation/uikit/uipageviewcontrollerdelegate/pageviewcontroller(_:didfinishanimating:previousviewcontrollers:transitioncompleted:)), [Apple, native scroll-view paging](https://developer.apple.com/documentation/uikit/uiscrollview/ispagingenabled), [Apple, predicted scroll offset](https://developer.apple.com/documentation/uikit/uiscrollviewdelegate/scrollviewwillenddragging(_:withvelocity:targetcontentoffset:)). Fit and cost assessments are inferences from the repository's current layout.

For UIKit bridging, `UIViewControllerRepresentable.sizeThatFits` can supply a preferred composite size; its implementation may run multiple times with different proposals in one layout pass. That permits a measured-height bridge, but is extra work that a direct `.paging` change avoids. Apple's older SwiftUI tutorial demonstrates hosting SwiftUI pages in `UIPageViewController`; the tutorial now warns that its practices are dated, so use current protocol documentation for implementation. [Apple, representable sizing](https://developer.apple.com/documentation/swiftui/uiviewcontrollerrepresentable/sizethatfits(_:uiviewcontroller:context:)), [Apple, UIKit integration tutorial](https://developer.apple.com/tutorials/swiftui/interfacing-with-uikit).

`TabView`'s implementation must remain an implementation detail. Neither its current documentation nor the SDK's public `PageTabViewStyle` declaration promises that it uses `UIPageViewController` or `UICollectionView`. Apple's UIKit tutorial builds a page controller explicitly; it does not establish how `TabView.page` works internally. Choose and test the documented system pager behavior instead of depending on a particular hidden UIKit class. [Apple, TabView](https://developer.apple.com/documentation/swiftui/tabview), [Apple, PageTabViewStyle](https://developer.apple.com/documentation/swiftui/pagetabviewstyle), [Apple, UIKit integration tutorial](https://developer.apple.com/tutorials/swiftui/interfacing-with-uikit).

## Acceptance checks

Use the actual app and compare recorded motion, not only destination arithmetic. Check tiny slow and moderately fast nudges, a short high-release-velocity flick, a short drag that stops before release, a long drag, reversal before release, and another gesture during settling. Check both directions. A cancellation must leave the date and week selection coherent. A genuine page turn must settle on one full page. Also verify calendar jumps across several days, week/day synchronization, buffer growth, outer vertical scrolling, and Dynamic Type layout. These checks are derived from the user reports and this repository's integration, not an Apple-specified test suite.

All required implementation checks for this investigation completed. `CalendarPagingTests` reports eight passing tests, zero failures, covering 20 parameter cases. The final physical build succeeds. `devicectl` installed `com.count.kcal.app` on the user's iPhone and launched it successfully without launch arguments or a data reset.

The final simulator recording verifies animated adjacent-date and week navigation. A seven-day calendar jump reaches the synchronized destination immediately; this investigation does not claim that distant calendar jumps gained animation. The original broad position animation modifier remains in the shipped source. The unsuccessful animation-scoping experiment is not part of the change.

The source review, simulator replays, unit results and successful installation do not establish physical-iPhone gesture quality. A phone recording or the user's check is still needed before claiming the reported feel is fixed on the iPhone.

## Replay evidence

The recordings and helper below are local investigation artifacts in `/tmp`, not committed test fixtures. Preserve them separately if this note must survive temporary-file cleanup. The Apple interaction command is replayed within an active simulator interaction session. Coordinates below use the 402-point-wide simulator and the calories card.

For the exact tiny-gesture regression, open the calendar and select Monday, 12 October 2026. Then replay:

```text
t 201 375.3 f 163 375.3 0.06
```

The original projected-distance implementation visibly moves about -19 points, then -25 points, then returns to 0 in a single frame. The scoped-animation candidate reproduces the same failure. Candidate 4 advances smoothly from Monday 12 to Tuesday 13 with this identical command. This command is a 38-point finger gesture, not a promise of 38 points of content movement. At 0.12 seconds the candidate-4 tiny gesture returns smoothly instead. These observations separate smooth native acceptance or cancellation from the former abrupt return.

The original slowing profile and its reverse are:

```text
mt [201 375.3] 0.04 [281 375.3] 0.06 [391 375.3] 0.05 [392 375.3] 0
mt [201 375.3] 0.04 [121 375.3] 0.06 [11 375.3] 0.05 [10 375.3] 0
```

The simulator's pan activation consumes part of the commanded movement; the measured content movement in the original replay was about 117 points. The command's raw endpoint distance should not be relabelled as measured scroll travel. The local helper `/tmp/count-pager-profile-trial.py` accepts `--session`, `--command`, `--expect change`, and `--expect-step` to collect before/after hierarchy evidence. Expected calendar-day steps are -1 for the rightward profile and +1 for its reverse.

| Artifact | Purpose |
| --- | --- |
| `/tmp/count-pager-tiny-historical-baseline.mp4` | Historical-date baseline with abrupt tiny-gesture cancellation. |
| `/tmp/count-pager-tiny-scoped.mp4` | Same projected-distance policy after programmatic-only animation cleanup; regression remains. |
| `/tmp/count-pager-tiny-native.mp4` | Direct native-paging comparison. |
| `/tmp/count-pager-assisted-tiny.mp4` | Candidate-4 core replay with native delegation and actual-travel supplement. |
| `/tmp/count-pager-117pt-native-return.mp4` | Earlier native cancellation of the original slowing profile. |
| `/tmp/count-pager-final6-tiny.mp4` | Final implementation, exact historical 38-point fast gesture, smooth one-page advance and zero abrupt cancellations. |
| `/tmp/count-pager-final6-calendar-adjacent.mp4` | Final adjacent-date programmatic navigation, about 405 points of animated movement. |
| `/tmp/count-pager-final6-calendar-far.mp4` | Final seven-day calendar selection, immediate synchronized destination. |
| `/tmp/count-pager-final6-week.mp4` | Final week navigation, about 402 points of animated movement and synchronized selection. |

Frame captures accompany the final recordings in directories ending in `-frames`. The critical final-source gesture and navigation checks pass. Interaction sessions are closed. The physical-device build, eight policy tests covering 20 parameter cases, and iPhone installation and launch succeed. Physical gesture quality is not claimed from simulator or installation evidence.
