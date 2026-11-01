Count.kcal 1.6.0 App Store screenshots, three-image final set
Updated 20 October 2026, calendar and equal-padding revision

Use final/{locale}/ for production. Each of en-US, de-DE, fr-FR and es-ES
contains three ordered 1206 x 2622 RGB PNGs without alpha. The active total
is 12 images. Marketing headings are localized; app UI remains English.

Final sequence
01-calorie-balance.png: the approved Theme 1 dashboard and Apple frame,
resized to the shared device bounds. The approved headline pixels remain.
02-custom-colors.png: the original Affinity hardware composition with current
Themes 1, 2 and 4 mapped into its display interiors. The original rails,
metal sidewalls, lighting, perspective and overlap remain. One uniform scale
resizes the complete composition. The approved headline pixels remain.
03-progress.png: the approved native Theme 2 calendar capture. The expanded
October 2026 calendar sits above the weekly bars and Progress card. The chart
ends at 79.7 kg, below the 79.9 kg weekly mean. Weight change is -0.5 kg and
the average daily deficit is 201 kcal. The native app UI is not retouched.

Device size and padding
All three visible bodies are 2239 px high, from y=323 through y=2561. The
bottom margin is 60 px. The front phones in images 1 and 3 share the same
1086 x 2239 px crop, x=60 through x=1145, with exactly 60 px on each side.
This is the largest front-phone width that allows the 60 px minimum margins.
Their source Apple frame has transparent outer padding; the renderer removes
that padding before choosing scale, so the margins measure visible hardware.

The colors composition also starts at x=60 and ends 60 px above the bottom.
Its original third phone is cropped at the right edge of the Affinity export.
That intentional right bleed remains at the canvas edge, with 0 px right
margin. Shrinking that cropped image inside a right margin would expose a
straight screen cut. The 1189 x 2239 px resized composition starts at x=60;
the canvas clips the final 43 px. Its visible bounds are therefore
[60, 323, 1206, 2562], compared with [60, 323, 1146, 2562] for the front phones.
All bounds use an exclusive right and bottom edge.

Headings
The first two scenes preserve the approved heading strips byte-for-byte,
including placement, colors and typography. The Progress heading uses 96 px
SF Pro Display, weight 450, centered, with the full line's glyph top at y=104.
Its fragments share one baseline, using anchor='ls'. This preserves the
approved correction for the lowercase second word in English and Spanish.

Sources and reproduction
../captures/progress-theme-02-calendar-en-US.png is the approved native
1206 x 2622 calendar capture. source/current-progress-theme-02-calendar-framed.png
records it inside the original Apple frame. source/approved-first-two/
retains the eight earlier approved PNGs, and its manifest records their hashes.
These copies supply the first two heading strips and remain unchanged.

source/build_final_set.py is the current renderer. It rebuilds all 12 images,
the final manifest, pixel-bound QA and four locale contact sheets. It uses
the established original-perspective homographies and source/legacy-aperture-*.png
masks to replace display interiors, and checks that all other original pixels
remain identical before the final uniform resize. It records source hashes,
exact geometry and the right-edge exception in the final manifest and QA.

Run from the repository root:
/Users/berken/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 \
  Marketing/2026-10-app-store-1.6.0/screenshots-v2/source/build_final_set.py

source/restore_original_perspective.py and source/build_leads.py document the
earlier production stages. They produce older layouts; use build_final_set.py
to reproduce the current final set.

Review and QA
review/final-set-{locale}.jpg: three-image sheets with 18 px gutters.
review/final-set-qa.json: 12 decoded RGB PNGs, dimensions, SHA256 checksums,
measured hardware bounds, margin checks, matching heights and the colors
right-bleed exception. final/manifest.json records active order, localized
titles, source paths, source hashes and geometry.
review/calendar-candidate/ retains the approved calendar design before the
padding adjustment. The first-two approved PNGs are historical references;
the final PNGs now differ because the device padding and scale changed.

Stash
../stash/2026-10-20-before-calendar-equal-padding/ contains all 12 previous
final PNGs and their manifest, previous contact sheets and QA, the previous
renderer and this document before the revision. Its manifest lists original
paths and SHA256 checksums. The earlier stash retains superseded fourth
screenshots, design studies and both removed App Preview production trees.
No App Preview exports are active. Original materials in other Marketing
collections remain unchanged.
