Count.kcal 1.6.0 App Store screenshots, three-image final set
Updated 20 October 2026

Use final/{locale}/ for production. Each of en-US, de-DE, fr-FR and es-ES
contains three ordered 1206 x 2622 RGB PNGs without alpha. The active total
is 12 images. Marketing headings are localized; app UI remains English.

Final sequence
01-calorie-balance.png: approved large Theme 1 dashboard, unchanged.
02-custom-colors.png: approved original Affinity hardware composition with
current Themes 1, 2 and 4 mapped into the visible display interiors. Its
uniform 1.03x scale from the native 1284 x 2778 original is preserved, which
is 9.13% larger than the initial export. The original rails, light, metal
sidewalls and overlap remain. Every approved PNG byte is unchanged.
03-progress.png: the new native Theme 2 capture at the top of the dashboard.
Progress is above Calories, with no Steps or Nutrients visible. The indigo
weight chart declines to 79.7 kg, below the 79.9 kg weekly mean. Current
weight change is -0.5 kg and average deficit is 201 kcal per day. The Calories
card is in Now mode: 2,280 kcal burned, 2,000 eaten and a 280 kcal deficit.

The Progress phone keeps the approved hero's 1160 px width and position
x=23, y=255, with its original proportions. The new purple heading is 96 px
SF Pro Display, weight 450, centered, with its overall top at y=104.

Heading correction
The former per-fragment anchor='lt' aligned each text fragment's glyph top.
That gave English and Spanish fragments baselines 18 px apart because the
second word begins with a lowercase letter. The new heading uses anchor='ls'
and a single baseline derived from the complete line. All fragments now share
that baseline, while the top of the complete line remains at y=104. The two
previously approved images were not regenerated.

Capture and sources
../captures/progress-theme-02-top-en-US.png is the native 1206 x 2622 capture
provided by the parent simulator workflow. It uses dark appearance, Theme 2,
Marketing Mode sample data and an unscrolled layout. The native UI is not
retouched. final/manifest.json records its SHA256 and the original Apple frame
path. No personal HealthKit data appears.

Approved image preservation
source/approved-first-two/ contains byte-identical source copies of all eight
approved first and second images. Their original metadata and SHA256 hashes
are in source/approved-first-two-manifest.json. The main build script verifies
those bytes before and after rendering. It does not run the historical color
compositor or recreate those approved images.

Review and QA
review/final-set-{locale}.jpg: clean three-image sheets with 18 px gutters.
review/progress-heading-baseline-en-US.png: close view of the corrected title.
review/final-set-qa.json: 12 decoded RGB PNGs, dimensions and SHA256 checksums,
with confirmation that all eight approved first and second images are intact.
final/manifest.json: active order, localized titles, source paths and geometry.

Rebuild
/Users/berken/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 \
  Marketing/2026-10-app-store-1.6.0/screenshots-v2/source/build_final_set.py

Stash
The prior Progress image and capture, fourth screenshots, old review sheets
and manifests, design studies, and both complete App Preview production trees
are retained under ../stash/2026-10-20-before-theme-02-progress-and-preview-removal/.
The stash manifest lists original paths and hashes. There are no active local
App Preview exports. Earlier source materials in other Marketing collections
remain unchanged. The historical Affinity inspection copy remains in source/;
no further Affinity interactions occurred during this revision.
