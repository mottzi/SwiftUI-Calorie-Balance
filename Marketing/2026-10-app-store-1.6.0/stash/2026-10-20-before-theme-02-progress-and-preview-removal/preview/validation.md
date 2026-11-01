# Superseded App Preview validation

Use the [v2 validation report](../preview-v2/validation.md) for the current delivery. The earlier Rec.709 claim below has been corrected. These historical files retained Display P3 primaries and an sRGB transfer function, with a BT.709 matrix. V2 explicitly converts all three colour properties to Rec.709. The first-pass exports have not been changed.

Verified 20 October 2026. All four final MP4 files decode completely without errors.

| File | Duration | Frames | Size | Video rate | Audio rate |
| --- | --- | --- | --- | --- | --- |
| count-kcal-iphone-app-preview-de-de-886x1920.mp4 | 24.000 s | 720 | 30.55 MB | 9.917 Mbps | 256.2 kbps |
| count-kcal-iphone-app-preview-en-us-886x1920.mp4 | 24.000 s | 720 | 30.55 MB | 9.917 Mbps | 256.2 kbps |
| count-kcal-iphone-app-preview-es-es-886x1920.mp4 | 24.000 s | 720 | 30.55 MB | 9.917 Mbps | 256.2 kbps |
| count-kcal-iphone-app-preview-fr-fr-886x1920.mp4 | 24.000 s | 720 | 30.55 MB | 9.917 Mbps | 256.2 kbps |

Each file is 886 × 1920 pixels, square pixels, 30 fps progressive H.264 High Profile Level 4.0, yuv420p, Display P3 primaries, sRGB transfer, and a BT.709 matrix. Each has 720 video frames. All have an enabled stereo AAC LC audio track at 48 kHz. The silent audio was encoded with Apple's AudioToolbox AAC encoder in constant bitrate mode at 256 kbps. The video uses a 10 Mbps constant bitrate target, with fast-start MP4 metadata.

The 24-second duration falls within Apple's 15–30 second range. Files are about 30.55 MB, below the 500 MB limit. The 886 × 1920 portrait preset matches the current App Store Connect iPhone App Preview slot.

Visual review covered all scenes in English, German, French, and Spanish contact sheets; native-size opening, settled Progress, and poster frames; and the real Now-to-Midnight transition. Captions fit without clipping. The Now-to-Midnight footage changes the real app's 280 kcal current deficit to its 600 kcal Midnight estimate. The real scroll reveals the full Progress chart and summary. Theme 2 and Theme 4 use actual still screenshots. Scene changes use 250 ms dissolves. No device bezel or fabricated UI appears.

Posters are exact exported frames at 5.000 seconds. English US, German, French, and Spanish for Spain have localized captions. Their demonstration UI remains English.
