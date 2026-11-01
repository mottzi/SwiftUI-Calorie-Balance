Count.kcal additional screenshot candidates
22 October 2026

Review only. These candidates are separate from the 12 active final images.
They have not been uploaded to App Store Connect.

Candidate pair
01-visual-customization.png: native customization view. English headline
"Make it yours", with "yours" in purple. The native viewport includes a
Body weight row partially clipped beneath the toolbar. All nine theme
samples are visible, and the native viewport hides the footer laurels.
The screen remains as captured, without retouching.
02-home-screen-widgets.png: native Home Screen with Count.kcal widgets and
Apple Health, Fitness and Count.kcal icons. It has two medium widgets,
Nutrients and Calorie bar, plus one small Calorie ring widget. The English
headline is "At a glance", with "glance" in blue. The native Home Screen
capture determines the widget arrangement.

Each of en-US, de-DE, fr-FR and es-ES has the two 1206 x 2622 RGB candidates.
The app and Home Screen UI remain English. Only the marketing headlines vary.
The full screenshots appear together in candidate-pair-{locale}.jpg, at
822 x 874, and candidate-pair-{locale}-full.png, at 2430 x 2622.

The native captures receive the existing Apple frame, rounded-screen mask
and uniform device resize. No screen content is painted, replaced or moved.
The phone bounds are [60, 323, 1146, 2562], with exclusive right and bottom
edges. Visible hardware is 1086 x 2239 px, leaving 60 px on both sides and
below. Headlines use 96 px SF Pro Display, weight 450. The complete heading's
top is y=104, and both fragments share a baseline.

manifest.json records the exact capture paths, source hashes, frame hash,
localized titles and geometry. qa.json records decoded image checks, measured
hardware bounds and the active-final hashes before and after rendering.
source/ contains framed native captures before their final resize.

Rebuild from the repository root after native captures are available:
/Users/berken/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 \
  Marketing/2026-10-app-store-1.6.0/screenshots-v2/source/build_new_scene_candidates_2026_10_22.py

The renderer also accepts --customization-capture and --widgets-capture for
explicit native capture paths. It writes only this review directory. Use
--check-headings to inspect localized heading geometry without rendering.
