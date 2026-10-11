# Calorie graph colors and widget transitions

The original Today/Midnight widget recording showed temporary bar color changes.
Removing the bar `View.brightness` effects removed that change; restoring them
restored it. Replacing `compositingGroup` with `drawingGroup` did not fix it.

The first workaround resolved and bounded the bar colors before drawing.
The user confirmed that the bars, then the fork and lightning icons, stopped
flickering on a physical iPhone. However, their next screenshot from inside the
app showed that the bars were much duller than the circle graph. That workaround
changed the settled palette and did not meet the visual requirement.

## Current bar treatment

The bars now use each selected color's native gradient, matching the circle.
Their active, resting, projected, and consumed segments use the circle's
brightness levels. The old black/white overlay gradients have been removed.
The consumed bar's old overlay also used the burned color, which tinted it blue.

Both graphs use the shared `graphColorAppearance` modifier for saturation and
the final dark-appearance brightness adjustment. The bars apply that modifier
on each colored segment before clipping and row compositing. Applying the
final effects outside the clipped rows still produced dull colors in the app.
Moving them before clipping produced the circle's palette.

The bars retain their row groups, rounded edges, width animations, and numeric
transitions. The earlier resolved-color workaround remains on calorie icons.
The app and widgets use the same shared bar implementation. There is no separate
widget palette or platform branch.

The shared projected shade was reduced from 0.35 to 0.25 after the user found
the third blue segment too pale. Both bars and rings use that shade level.

This narrows the problem to the color-effect ordering in the affected view
compositions. It does not establish the exact behavior of Apple's internal
animation renderer or prove that brightness is broken in every widget.

## Ring segment boundaries

The shared circle graph has two-point transparent gaps between neighboring
segments, including the colored/gray remainder boundary. Each ring is drawn
with stable, built-in `Circle.trim` segments. The gaps are uncovered areas,
so they show the actual card background. Tiny segments use narrower gaps.
The empty ring remains behind translucent colored segments for accented widgets.
The bars retain their original rounded caps without gaps.

### Widget circle animation regression investigation

The user reports that the app's mode animation looks good, but the physical
Home Screen widget circles appear to stop animating after the gap change.
The comparison from `3913045` to `abc0cd3` isolates the structural ring change
to a custom even-odd mask around the whole graph. The toggle intent, widget
provider, arc shape, and ring transactions were unchanged. The color commit
replaced the circle's final saturation/brightness pair with a modifier that
performs the same pair, and lowered the static projected brightness level.
It did not disable or replace the ring animation.

The former mask's path topology changes across modes. A probe using its actual
source and a surplus-to-deficit example counts three move elements and nine
line elements in Now, versus four and twelve in Midnight. Gap polygons are
conditionally added for the projection and colored/gray remainder boundaries.
Its handwritten `animatableData` interpolates those ratios when the app is
running, but that alone does not establish interpolation of the archived widget.

Apple explains that widget view code runs during archiving and the system
renders the archived representation in its own process. Apple documents support
for built-in SwiftUI animations. These facts make the custom mask the leading
regression candidate; they do **not** document the exact internal treatment of
this mask or prove the cause without a physical-device comparison:

- [Bring widgets to life, WWDC23](https://developer.apple.com/videos/play/wwdc2023/10028/)
- [Animating data updates in widgets and Live Activities](https://developer.apple.com/documentation/widgetkit/animating-data-updates-in-widgets-and-live-activities)

The candidate fix removes the compound mask and custom arc interpolation from
the shared ring implementation. Built-in circle trim endpoints and shape
rotation carry each segment's geometry. All segment views remain present across
mode changes, including zero-length segments. Rotation precedes stroking, so the
gradient keeps its original vertical orientation. No widget-specific ring
implementation or color palette was introduced.

Simulator behavior is not used as proof of the physical widget regression or
its resolution. The user's iPhone comparison is still required.

## Verification

- The app and widget extension build for the simulator and physical iPhone.
- Four rendering tests pass. The new test renders the actual bar rows and
  compares all four colored segments against the circle's existing gradient
  and effect treatment in both light and dark appearance. Sampled RGB channels
  differ by no more than one point.
- The original consumed-bar simulator recording had 22 RGB channel points of
  drift. The recording with the current circle palette has 0.8 points of drift
  while the bar width changes.
- The simulator app was visually checked in dark appearance with the circle and
  bars visible together. The colored bars match the circle's blue and orange.
- Unit rendering tests do not exercise WidgetKit's system animation renderer.
  The widget recording checks that behavior; physical iPhone testing remains
  necessary for the final palette change.
- Nine targeted tests pass after the candidate ring animation fix. They include
  the existing bar/color tests, a native-circle gradient comparison against the
  original arc, actual shared-graph rendering of transparent boundaries, and
  two-point gap geometry, missing segments, empty rings, and tiny segments.
  These tests verify geometry and rendering, not WidgetKit animation.

## Physical check

The built-in trimmed-segment candidate is installed on the user's iPhone 16 Pro.
The user has confirmed the app's former mask animation looked good and reported
poor widget circle motion. That physical widget regression remains unverified by
an A/B recording. Compare the top-trailing mode toggle in the Home Screen widget
with the app's mode toggle using this candidate. The simulator mirror is updated,
but neither it nor the rendering tests establish the iPhone animation result.
