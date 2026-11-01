# Localized App Preview v2 validation

Verified 20 October 2026. All four final MP4s completed a full ffmpeg decode with no errors. Delivery assertions passed for codec, dimensions, frame count, progressive scan, colour metadata, audio, duration, and file size. All four have fast-start MP4 metadata, with moov before mdat.

| Locale | Container duration | Video frames | Size | Video rate | Audio rate |
| --- | --- | --- | --- | --- | --- |
| de-de | 22.000000 s | 660 | 27.98 MB | 9.910 Mbps | 256.2 kbps |
| en-us | 22.000000 s | 660 | 27.98 MB | 9.910 Mbps | 256.2 kbps |
| es-es | 22.000000 s | 660 | 27.98 MB | 9.910 Mbps | 256.2 kbps |
| fr-fr | 22.000000 s | 660 | 27.98 MB | 9.910 Mbps | 256.2 kbps |

Every file is 886 × 1920 with square pixels, 30 fps constant, H.264 High Profile Level 4.0, progressive, yuv420p. Rec.709 primaries, transfer, and matrix are confirmed by ffprobe. The enabled audio track is silent stereo AAC LC at 48 kHz and a 256 kbps constant bitrate target. The video target is 10 Mbps. Each file contains 660 video frames and lasts exactly 22 seconds.

These exports meet Apple's 15–30 second duration, 30 fps maximum, and 500 MB cap. The portrait resolution is the current supported iPhone App Preview size. SHA-256 values and exact byte sizes are in `exports/manifest.json`; full stream data is in each locale's `ffprobe.json`.

Visual review covered all four 12-frame contact sheets and all four native-size 5-second posters. The captions are centred, fit without clipping, and have no terminal periods. The translations are recorded in `README.md`. Each 5-second poster shows the same actual settled Midnight state, 2,600 burned, 2,000 eaten, a 600 kcal deficit, and the check mark. Native-size inspection frames show the same app UI at the corresponding source times in every locale.

The app navigation remains intact. Caption text sits in the top 100 px; a further 16 px of matching background clears the recorded system-island edge without covering app controls. The Progress scene reveals the full chart and summary. The last scene uses the actual yellow-and-blue Theme 4 capture. The first two scenes use continuous native recordings at their captured speed. Theme 2 and Theme 4 use native screenshots. All three scene changes are 250 ms dissolves. No app interaction or animation was fabricated.

The videos explicitly convert Display P3/sRGB recordings and sRGB stills to Rec.709. PNG review frames and posters are converted from the exported video frames to sRGB for normal image viewing. Their content corresponds to their stated video times.

The source ranges, exact edit, translations, and rebuild command are in `README.md`. The demonstration UI remains English in every locale. These files supersede the first-pass `preview/` exports. That older edit retained Display P3 primaries and sRGB transfer despite requesting Rec.709 output flags; its historical README and validation report now correct that claim and point to v2. Its media files remain unchanged.

No browser upload was performed by the video production agent.
