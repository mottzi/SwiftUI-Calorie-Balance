Sharing App Store screenshot, 7 November 2026

Upload file: exports/en-US/04-sharing-overview.png
1206 x 2622, RGB PNG, English. Intended as screenshot 4 after the existing
Calorie balance, Custom colors, and Your progress posters. Not uploaded.

The heading reads "Share with friends". The silver device frame, 60px hardware
margins, 2239px device height, and SF Pro Display heading match the approved
three-image set. review/four-screenshot-set.jpg shows the sequence together.

This is a composition of native Simulator B UI captures. The synthetic Alice
profile and native Sharing header/Invite button come from the isolated Debug
fixture on 7 November. Lea, Jonas, Maya, and Noah come from the prepared
6 November sample-person crop. Emma is a fifth composed marketing row, using
standard theme 4, blue and gold, a 320 kcal deficit and a 6-day streak. Her row
reuses native row geometry with theme mapping and SF Pro Text labels.
No real account or connection is included. The existing four rows retain
their original text, calorie values, rings, and streaks.
The top corners of the sample list were rounded to form its first visible row.
See source/composition-provenance.json for exact crops and source hashes.

Sources are retained in captures/. source/sharing-overview-framed.png is the
transparent framed composition for reuse. manifest.json records export details.

Rebuild with a Python environment containing Pillow:
  python source/compose_overview.py
  python source/build_screenshot.py captures/sharing-overview-composed.png

Verified the export dimensions, RGB mode, frame alignment, headline spacing,
sample identities, and the visual sequence with the first three screenshots.
