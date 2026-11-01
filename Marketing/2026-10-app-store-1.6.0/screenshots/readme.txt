Count.kcal 1.6.0 iPhone App Store screenshots
Created 20 October 2026

Output
Each locale folder contains six ordered PNG images at 1206 x 2622 pixels, RGB,
with no alpha channel. Headings are localized for en-US, de-DE, fr-FR and
es-ES. App UI remains English in all versions. This is deliberate and must
not be mistaken for fully localized app captures.
iphone-large/ contains the same 24 images at 1320 x 2868 pixels. These use
the same composition with a centered aspect-fill resize, cropping less than
one source pixel in height. Both output sets have no alpha channel.

Design
Near-black #080A0F, off-white #F5F5F7, SF Pro Display system font at weight
650, short two-line headings. Device renders and calorie-card details fill
most of the available width. The continuous macro/detail crop uses the
native #111216 app background so its edges blend into the canvas. Hero and Progress use complete silver iPhone
frames; other device compositions may continue below the canvas.

Sources
Only current Marketing Mode UI is used. Existing source captures and Apple
frames stay unchanged. Themes 1, 2 and 4 appear throughout. There is no
synthesized UI, generated UI, personal HealthKit data, or archived app screen.
The fresh Progress source was captured on 20 October 2026 from the installed
app by the parent workflow, in dark appearance with Marketing Mode data. Its
original path is ../captures/progress-en-US.png. A byte-identical local copy
is retained in source/progress-capture.png.

manifest.json records each image's exact source paths and heading.

The calorie-card comparison uses the current transparent card exports from
Marketing/2026-10-calorie-card/stills. The themes image crops the complete
calorie cards directly from current full-size dashboard captures, including
their original raised lower edges.

Review
review/marketing-inventory.csv inventories all 193 pre-existing Marketing
files, including editable masters and videos, with raster dimensions when
available. The inventory contact sheets cover every static raster source
and archive export. The preview production workflow reviews the videos.
Read every collection's readme before choosing sources. Historical widgets,
settings, branding and earlier pre-Marketing Mode captures were excluded.

Rebuild
Use the bundled workspace Python, which includes Pillow:
/Users/berken/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 \
  Marketing/2026-10-app-store-1.6.0/screenshots/source/build_screenshots.py

This script regenerates locale folders, the source-copy JSON, manifest and
contact sheets. Original assets remain in their existing dated collections.

Dimensions
Apple's current medium Dynamic Island screenshot well accepts 1206 x 2622
portrait. Other accepted sizes are listed in the official documentation:
https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/
