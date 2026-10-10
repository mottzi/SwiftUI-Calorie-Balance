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

The shared circle graph now has two-point transparent gaps at its burned
segment boundaries. The gap also separates a colored arc from the gray
remainder: on the inner eaten ring for a deficit, or on the outer burned ring
for a surplus. A mask cuts through the complete ring after its color effects,
so the gaps show the actual card background.

The mask animates the same energy ratios as the arcs. It narrows gaps beside
very small segments and skips boundaries without neighboring segments.
The bars retain their original rounded caps without gaps.

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
- A geometry probe of the ring mask passes for deficit and surplus remainder
  gaps, isolation of the inner and outer rings, and an empty graph.

## Physical check

The updated device build is installed on the user's iPhone 16 Pro. The phone
was locked during the final launch attempt; unlock it and open the app to test.
Compare the bar and circle palettes inside the app, then toggle Today/Midnight
in the widget and check the bar colors during the animation. The earlier bar
and icon flicker fixes were confirmed by the user. The current palette change
still needs their physical-device confirmation.
