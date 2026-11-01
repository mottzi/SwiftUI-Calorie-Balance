# Superseded iPhone App Preview

This is the historical first-pass edit. Use the [v2 previews](../preview-v2/README.md) and [v2 validation](../preview-v2/validation.md) for the current delivery. The original Rec.709 claim was incorrect: these files retained Display P3 primaries and an sRGB transfer function from the recording, with a BT.709 matrix. V2 explicitly converts the footage to Rec.709. The first-pass exports remain unchanged.

The first-pass edit used a 24-second portrait preview. Real app capture fills the frame. Short captions replace the system status and navigation area. The edit has no device frame, cursor, filmed interaction, stock footage, music, or invented app behavior.

## Deliverables

`exports/` contains one MP4, exact 5-second poster frame, contact sheet, and ffprobe report per locale. English US, German, French, and Spanish for Spain use localized captions over the app's English demonstration UI.

The poster is an actual frame of the final video at `00:00:05.000`, so it can be selected directly in App Store Connect. The opening image communicates the same calorie dashboard immediately, before autoplay starts.

## Edit

| Time | Actual app content | Caption |
| --- | --- | --- |
| 0–4 s | Theme 1 dark dashboard in Now mode | Your day. In balance. |
| 4–10 s | Recorded transition from Now to Midnight | See where today is heading. |
| 10–16 s | Recorded scroll past macros to the weight graph | Macros and weight trends. |
| 16–20 s | Theme 2 dark dashboard | Your theme. Your choice. |
| 20–24 s | Theme 4 dark dashboard | Know your balance. |

Four 250 ms dissolves connect the five scenes. Every number, graph, card, colour treatment, and animated change belongs to the actual app. The Theme 2 and Theme 4 cuts use native simulator screenshots. Those two scenes are still app captures, not simulated theme interactions. The source demonstration profile contains sample data.

## Build

`make-overlays.swift` draws the editable caption artwork with native system typography. `build-preview.py` performs the edit, encodes the four locales, extracts posters and contact sheets, and asserts the main delivery requirements. It needs the system Swift runtime, Python 3, ffmpeg, and ffprobe. The AAC encoder uses macOS AudioToolbox. No third-party Python libraries are required.

```sh
python3 Marketing/2026-10-app-store-1.6.0/preview/build-preview.py \
  --scroll Marketing/2026-10-app-store-1.6.0/captures/dashboard-scroll-en-US.mp4 \
  --scroll-start 2.8
```

The source dashboard recording is `Marketing/2026-10-calorie-card/source/iphone-18-pro-theme-01-dark-now-midnight-native-slow.mov`. Themes 2 and 4 come from the matching native PNGs in `Marketing/2026-10-today/captures/`. The Progress scroll comes from `Marketing/2026-10-app-store-1.6.0/captures/dashboard-scroll-en-US.mp4`, using seconds 2.8–9.05. The native screenshots and Now/Midnight recording were captured on 18 October; the Progress demonstration was captured on 20 October. Each uses sample data. Source recordings remain unchanged.

## Export requirements

The delivery preset is 886 × 1920 pixels, square pixels, 30 fps progressive H.264 High Profile Level 4.0 in an MP4 container, Display P3 primaries with sRGB transfer and a BT.709 matrix, 10 Mbps constant target and maximum video rate. The enabled audio track is silent stereo AAC, configured at 256 kbps and 48 kHz. Each preview lasts 24 seconds and is below Apple's 500 MB limit.

Apple's current rules were checked on 20 October 2026 against its [App Preview specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications/), [creative guidance](https://developer.apple.com/app-store/app-previews/), and [review guideline 2.3.4](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata). The accepted portrait size, 15–30 second duration, maximum 30 fps, and 500 MB cap determine this preset. Apple's creative guidance supports actual app footage, readable text, and simple transitions. It excludes filmed devices and fingers. Text makes the preview understandable while muted.

`work/` holds reproducible intermediate clips, caption PNGs, and inspection frames. `exports/` holds the superseded first-pass files. Current upload candidates are in `../preview-v2/exports/`. See `validation.md` for the measured final files and visual review.
