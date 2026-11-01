Count.kcal 1.6.0 App Store screenshots, revised final set
20 October 2026

Use final/{locale}/ for production. The older en-US/ and alternatives/ files
are design studies and comparisons. Do not upload those as the final set.

Final sequence
01-calorie-balance.png: current Theme 1 dashboard in the original current
silver iPhone frame. One centered heading and a 1160px-wide device.
02-custom-colors.png: the exact original three-dimensional hardware from
Marketing/archive/legacy-app-store/iphone-65/exports/iphone-65-02-customize.png,
with only visible screen interiors and the heading replaced. Themes 1, 2, 4
run left to right. The original metal rails, lighting, sidewalls, black glass,
layer overlap, and relative physical positions are preserved. The hardware is the
older original model. All displayed app UI is current.
03-progress.png: the fresh 20 October dark Marketing Mode capture, including
its full current weight chart and 7-day deficit/weight statistics, in the same
silver frame and at the same size as the hero. Its native scrolled top blur
has not been retouched.
04-your-week.png: current Theme 2 dashboard in the same large silver frame.

Every final PNG is 1206 x 2622, RGB, without alpha. Four locales each contain
four images. Headings are localized for en-US, de-DE, fr-FR, es-ES; app UI stays
English. These are sample-data screens, not personal HealthKit data.

Original perspective preservation
The original hardware was not approximated with rotated frontal phones.
The source composite remains the base image. Connected screen-background
regions define masks clipped to each original aperture and foreground-phone
occlusion. The current original screenshots are projected into those planes.
Old clocks, old numbers, old macro colors, old weight values, and the previous
home indicators are covered. Native-resolution seam crops were inspected.
A pixel assertion verifies that every pixel outside the display masks stays
identical to the original before replacing the heading. The complete device
composition uses a uniform 1.03x scale from the 1284x2778 source, centered
horizontally and placed at y=-154 on the 1206x2622 output. This makes the phones
about 9% taller than the initial final export and matches the neighboring
slides' visible device height. The 96px heading starts at y=104, as on the
other slides. Source originals remain unchanged.

Review and provenance
review/final-set-{locale}.jpg: clean four-image contact sheets, 18 px gutters.
review/final-colors-four-locales.jpg: localized original-hardware colors slide.
review/original-hardware-comparison.jpg: original left, updated app UI right.
review/legacy-aperture-overlay.png: visible screen replacement masks in pink.
review/final-set-qa.json: 16 decoded RGB PNGs, dimensions and SHA256 checksums.
review/colors-scale-qa.json: corrected device-height bounds and confirmation
that the other 12 screenshot exports are byte-identical.
final/manifest.json: headings, locale, ordering, source paths, and geometry.
source/restore_original_perspective.py: original hardware screen replacement.
source/build_final_set.py: complete final production and QA.

Rebuild
/Users/berken/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 \
  Marketing/2026-10-app-store-1.6.0/screenshots-v2/source/build_final_set.py

Earlier Affinity inspection
The archived custom-colors master was copied into source/ and opened only
for inspection. Affinity stopped responding after its legacy-document notice.
No source layers were extracted, no original documents were edited, and the
app was not force-quit. The copied document window may remain open.
