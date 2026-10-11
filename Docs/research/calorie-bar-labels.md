# Calorie bar labels

Researched and updated on 2026-10-11 against Apple documentation and the current shared bar implementation. Native span placement restored synchronized widget label motion in the recorded comparison.

## Implemented geometry

`EnergyGraphValues` supplies raw calorie values, an animated common scale, and stable semantic slots. Both circle and bar geometry derive from that model. The common scale avoids forcing one side to full width midway through a transition when the larger energy total changes. See the [circle findings](circle-balance-graph.md) for the model and crossover examples.

`CalorieBarRowLayout` owns the same animation data. It places the occupied fill group and measures every actual styled label with `sizeThatFits(.unspecified)` before resolving label positions in one pass. It uses `Cache = Void`, with no per-label width state or preferences. Apple provides measurement and placement through layout subview proxies; `.unspecified` obtains ideal dimensions. `Layout` inherits `Animatable`. [Layout](https://developer.apple.com/documentation/swiftui/layout), [LayoutSubview.sizeThatFits](https://developer.apple.com/documentation/swiftui/layoutsubview/sizethatfits(_:)), [ProposedViewSize.unspecified](https://developer.apple.com/documentation/swiftui/proposedviewsize/unspecified).

This lets a Now two-segment to Midnight three-segment update use current text widths and segment geometry together. A preferences-to-state design would add a measurement feedback update before sibling placement could use new widths. Avoiding that feedback loop removes a source of stale measurements; it is not a claim that Apple guarantees a visible one-frame delay with preferences.

Stable String identities preserve active, resting, prediction, and empty slots, including zero-length slots. The ring investigation observed successful widget archive matching with String IDs. Apple does not document a general prohibition on enum identities. [Circle identity findings](circle-balance-graph.md), [Demystify SwiftUI, WWDC21](https://developer.apple.com/videos/play/wwdc2021/10022/).

## Label policy and appearance

The solver first computes the earliest centers that leave room for every visible leading label. It then chooses preferred centers from trailing to leading, respecting those reservations and each trailing neighbor's gap. Primary labels prefer their segment midpoint and may extend into following segments or the gray remainder when needed. Prediction and empty-remainder labels may extend into preceding segments while keeping a trailing inset. Complete labels stay inside the row and never overlap. If all labels cannot satisfy their bounds together, the solver preserves trailing priority and hides only labels that cannot fit.

The 262 active / 226 resting / 2,959 consumed reproduction exposed the need for the leading reservation. Placing 226 first with only its own segment constraints left too little space for 262, despite the wide gray remainder. Reserving both text widths and their gap shifts 226 slightly into that remainder and keeps both values visible. Native simulator fixtures also showed readable 349 / 202 and Midnight labels with the same policy.

Custom layout placement uses ordinary coordinates and a fixed leading anchor. SwiftUI mirrors subview positions in right-to-left environments. Manually mirroring both coordinates and anchors duplicated that behavior and clustered the labels at the opposite edge. Removing that manual mapping restored the mirrored fixture, including the widget drawing path. [LayoutSubviews.layoutDirection](https://developer.apple.com/documentation/swiftui/layoutsubviews/layoutdirection).


The layout places every label wrapper at the fixed semantic leading origin of the row. Its proposed width is the resolved center plus half the measured text width. The label's native flexible frame aligns the complete text to the trailing edge, putting its glyph center at the resolved position. This encodes horizontal movement as native frame geometry rather than a changing custom-layout placement point. Hidden slots retain that width and semantic position, but receive a zero-height proposal. The label frame accepts the flexible height and clips its contents; text taller than the row also stays hidden.

This preserves the trailing-label behavior, adds its leading-edge counterpart, and checks collisions across the row. A 100-calorie active segment on a 2,146-calorie scale can be narrower than its text. Its label stays readable at the leading inset instead of disappearing, just as a narrow trailing balance label stays readable at the trailing inset. Exact centering, complete digits, and no overlap cannot all hold for arbitrary tiny segments. The implemented policy favors readable trailing values and hides a label if neighboring labels leave too little room. That is a geometry and product decision, not a SwiftUI restriction.

Each label supplies its target visibility to the layout with `LayoutValueKey`. Collision reservations use that visibility alongside interpolated segment geometry. A hidden target zero must not reserve space when a spring bounces above zero. The 210 active / 347 resting / 2,826 consumed reproduction showed an invisible prediction reserving space at 0.0049 interpolated calories and repeatedly hiding the resting label after the bars appeared settled. The visibility key removed those reservations in the same replay without changing the spring or graph calculations. Apple documents custom layout values for subviews to guide container placement. [LayoutValueKey](https://developer.apple.com/documentation/swiftui/layoutvaluekey).

`CalorieBarLabel` retains complete target integers and the existing caption, rounded, semibold font, `GraphTextColor`, shadow, and appearance-dependent contrast. One stable `Text` carries `.numericText(value:)` when configured. Apple defines that transition for numeric content and uses the difference between old and new values to choose direction. It does not drive bar geometry or promise every intermediate calorie value. [numericText(value:)](https://developer.apple.com/documentation/swiftui/contenttransition/numerictext(value:)).

## Fill animation

`CalorieBarFill` uses `AnimatedCalorieGraph` for the live app. That adapter recomputes native rectangle frames and offsets from interpolated energy values, and disables further descendant interpolation within the fill drawing. Numeric labels remain outside that suppression. The widget path bypasses the adapter and supplies complete target geometry to the same native drawing.

The former custom fill layout produced a jumping blue boundary in the widget host. Replacing it with native `.frame` and `.offset` drawing restored intermediate boundary positions in the local widget comparison. This is observed behavior in this composition, not proof that all custom layouts fail to animate in WidgetKit.

Apple's animation session explains that default layout motion interpolates child positions, while a custom animatable parent can rerun layout using an interpolated input to produce a nonlinear path. That supports the live recomputation mechanism. It does not document every combination of nested layout and drawing interpolation. [Explore SwiftUI animation, WWDC23](https://developer.apple.com/videos/play/wwdc2023/10156/).

## Widget labels and geometry grouping

Widget view code runs during archiving; the system later renders the archived representation in another process. The custom row layout can calculate each entry's settled geometry, but its collision solver cannot be assumed to run on each system animation frame. Apple documents native animations and numeric content transitions for widgets. [Bring widgets to life, WWDC23](https://developer.apple.com/videos/play/wwdc2023/10028/).

Each stable label wrapper retains `.geometryGroup()`. Apple explains that ordinary geometry changes propagate to drawing leaves. A geometry group creates a barrier so the parent resolves and animates position and size before passing them to children. That supports keeping a wrapper's geometry together while its numeric content changes. [geometryGroup](https://developer.apple.com/documentation/swiftui/view/geometrygroup()).

Center placement with a geometry group still showed inconsistent forward timing in the widget comparison. With native frame spans, recordings show unchanged label values moving through multiple center positions in both directions over approximately 0.36 seconds. Their centers settle with the fill endpoints within pixel rounding. This confirms synchronized span and fill motion in the tested widget host. It does not establish a universal restriction on custom layouts, or guarantee identical behavior for every widget composition.

Widget animations last at most two seconds and do not run in Always On. Apple's guidance says `Transaction` cannot disable widget animation; the live fill adapter therefore does not run in the widget path. [Widget animation guidance](https://developer.apple.com/documentation/widgetkit/animating-data-updates-in-widgets-and-live-activities).

The final widget recording confirmed readable settled Now and Midnight labels, with no visible zero labels. The prediction label appears and disappears within the rightmost segment. Existing labels and fills move together in both directions. These observations cover the recorded transitions; they do not prove collision-free intermediate frames for every possible digit-width change or visibility transition.

## Row clipping

Composite the row contents before applying the outer rounded shape. Applying the clip before `compositingGroup()` left the leading filled corners square in the live Today card. Moving the group before the clip restored the configured rounding in the simulator screenshot. The occupied fill retains its separate trailing cap. This is a result observed in this hierarchy; Apple's compositing documentation explains how modifier order separates effect stages. [compositingGroup](https://developer.apple.com/documentation/swiftui/view/compositinggroup()).
