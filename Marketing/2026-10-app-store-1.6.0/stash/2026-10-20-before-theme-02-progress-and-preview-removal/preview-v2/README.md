# Localized App Preview v2

This 22-second edit uses actual native app capture, one-line centred captions, and no device bezel. The caption sits in the top 100 px. A further 16 px of matching background clears the lower edge of the recorded system island; the app navigation remains visible. The UI fills the frame. The title font is 50 px semibold system type, with a restrained blue accent.

## Review files

- `exports/count-kcal-iphone-app-preview-v2-en-us-886x1920.mp4`
- `exports/count-kcal-iphone-app-preview-v2-en-us-poster-05s.png`
- `exports/count-kcal-iphone-app-preview-v2-en-us-ffprobe.json`
- `review/count-kcal-iphone-app-preview-v2-en-us-contact-sheet.png`
- `review/frame-00s.png`, `frame-05s.png`, `frame-11s.png`, `frame-16s.png`, and `frame-21s.png`

The delivery locales are English US, German, French, and Spanish for Spain. Captions are localized; the demonstration UI remains English. No terminal periods appear in these short captions. This pipeline creates local exports; uploading is handled separately. The original `preview/` exports remain unchanged. The earlier single-frame concept remains in `review/` for comparison.

The same filenames use `de-de`, `fr-fr`, or `es-es` for the other locales. `exports/manifest.json` lists the exact filenames, byte sizes, and SHA-256 values. Contact sheets live in `review/`; native-size inspection frames for German, French, and Spanish live in the corresponding locale subfolders.

| Locale | Balance caption | Progress caption | Colors caption |
| --- | --- | --- | --- |
| en-US | Calorie balance | Your progress | Custom colors |
| de-DE | Kalorienbilanz | Dein Fortschritt | Eigene Farben |
| fr-FR | Bilan calorique | Vos progrès | Vos couleurs |
| es-ES | Balance calórico | Tu progreso | Tus colores |

## Exact edit and source ranges

| Preview time | Source and range | Caption |
| --- | --- | --- |
| 0.00–8.25 s | `Marketing/2026-10-calorie-card/source/iphone-18-pro-theme-01-dark-now-midnight-native-slow.mov`, source 3.00–11.25 s | Calorie balance |
| 8.00–14.25 s | `Marketing/2026-10-app-store-1.6.0/captures/dashboard-scroll-en-US.mp4`, source 2.80–9.05 s | Your progress |
| 14.00–18.25 s | Actual Theme 2 dark Midnight screenshot, held 4.25 s | Custom colors |
| 18.00–22.00 s | Actual Theme 4 dark Midnight screenshot, held 4.00 s | Custom colors |

The still sources are `Marketing/2026-10-today/captures/iphone-18-pro-theme-02-dark-midnight-bg-dark-steps-off-sheen-mid-capture.png` and `iphone-18-pro-theme-04-dark-midnight-bg-dark-steps-off-sheen-mid-capture.png`.

Three 250 ms dissolves begin at 8, 14, and 18 seconds. The first two scenes use continuous native footage at its recorded speed. The opening footage actually changes from Now to Midnight. Preview time 5.000 seconds maps to source time 8.000 seconds, after the animation has settled at a 600 kcal deficit with a check mark. The exact exported 5-second frame is the poster. Theme 4 supplies the final yellow-and-blue UI. No app animation was invented.

The source captures are native 1206 × 2622. The edit scales to 886 × 1926, then removes six pixels at the lower edge to meet Apple's 886 × 1920 delivery size. Native controls, calorie card, and nutrient card are preserved. The recorded Display P3/sRGB footage and sRGB stills are converted to Rec.709 for a consistent video colour space. All data shown is demonstration data.

The contact sheet contains frames at 0.5, 2.5, 5, 7.5, 8.5, 10.5, 12.5, 14.5, 16.5, 18.5, 20.5, and 21.5 seconds, in row order.

## Rebuild

```sh
python3 Marketing/2026-10-app-store-1.6.0/preview-v2/source/build-preview.py
```

The build uses Python 3, Swift/AppKit, ffmpeg, ffprobe, and macOS AudioToolbox. Editable caption generation for all four locales is in `source/make-video-captions.swift`. To rebuild one locale, pass `--locale en-US` or its locale code. No third-party Python packages are needed.

## Delivery preset

886 × 1920, square pixels, progressive 30 fps H.264 High Profile Level 4.0, yuv420p, Rec.709, 10 Mbps constant bitrate target, fast-start MP4. The enabled audio track is silent stereo AAC LC encoded with AudioToolbox at a constant 256 kbps and 48 kHz. Full-decode checks and the measured results are in `validation.md`.

The preset follows Apple's [App Preview specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications/), [creative guidance](https://developer.apple.com/app-store/app-previews/), and [review guideline 2.3.4](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata), checked on 20 October 2026.
