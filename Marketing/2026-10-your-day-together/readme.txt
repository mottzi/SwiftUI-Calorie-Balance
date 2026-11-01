Count.kcal: Your day, brought together
Created 23 October 2026

A ten-second film showing activity, nutrition and weight connecting through
Apple Health to Count.kcal. Uses the real Theme 02 dark dashboard, a silver
3D iPhone 17 Pro model and the existing Apple Health artwork.

PREVIEW

index.html
  Review the encoded website and portrait films and download the exports.
  Browser playback starts paused when reduced motion is enabled.

source/your-day-together.html
  Editable motion preview with playback controls and a timeline scrubber.
  Layout, colors, asset paths, readings and timing are in motion-config.json.

DELIVERABLES

videos/count-kcal-your-day-together-loop-transparent.webm
  1800 x 1100, 30 fps, 10 seconds. Silent VP9 with alpha.
  Intended for placement over a dark website background.

videos/count-kcal-your-day-together-loop-dark-bg.mp4
  1800 x 1100, 30 fps, 10 seconds. Silent H.264 over #060709.

videos/count-kcal-your-day-together-portrait-dark-bg.mp4
  1080 x 1920, 30 fps, 10 seconds. Silent H.264 over #060709.
  Uses a separate portrait layout with a larger phone during the final hold.

stills/count-kcal-your-day-together-poster-transparent.png
stills/count-kcal-your-day-together-poster-dark.png
  Wide poster showing the readings, Apple Health connection and dashboard.
  Captured at 3.6 seconds, with 3600 x 2200 master resolution.

stills/count-kcal-your-day-together-poster-portrait.png
  Portrait poster for social placements.

Additional final-hold posters and storyboard frames are included alongside
the main exports. See the export manifest and QA report for exact sizes,
encoding properties, source hashes and review frames.

STORY

0.0 to 2.0 s  Activity, nutrition and weight readings appear in sequence.
2.0 to 5.0 s  Colored pulses pass through Apple Health toward the dashboard.
5.0 to 6.0 s  Supporting readings fade; the 3D phone turns from 22 to 6 degrees.
6.0 to 9.2 s  The clear dashboard holds with "Your day. One clear picture."
9.2 to 10.0 s Return to the opening pose for the loop.

The wide phone is approximately 1020 px tall. The portrait phone grows from
approximately 1050 px to 1450 px. The native dashboard is mapped onto the
model's display while the 3D phone turns under studio lighting. Screen
content is not reconstructed or generated.

VERIFIED SOURCE READINGS

Burned energy  2,600 kcal
Eaten energy   2,000 kcal
Daily balance  600 kcal deficit
Weight today   79.7 kg

The original capture also shows Carbs 207/210 g, Fats 72/82 g and Protein
131/131 g. The visible lower edge of the progress chart is the original app
viewport. The film preserves the source data, clock and interface.

WEBSITE USE

Use the MP4 when the page background is #060709. The transparent WebM allows
the composition to sit over another dark background; check alpha playback
in the browsers supported by the website. A static PNG is also supplied.

Set video playback to muted, playsinline and loop. Keep a pause control
available. For reduced-motion users, display the poster with playback paused.
index.html demonstrates this behavior using the encoded videos.

The data routes, pulses and perspective movement are marketing graphics.
They explain the product connection and do not depict actual sync duration.
This collection is for the website, social posts and launch material.
It has not been uploaded to App Store Connect or published to the website.

SOURCE AND REBUILD

source/motion-config.json is the shared composition specification.
source/render-film.swift renders CoreGraphics frames from that specification.
source/3d/prepare_mesh.py imports the preserved GLB model's geometry.
source/3d/render-mesh.swift renders the phone poses with SceneKit and Metal.
source/build.py prepares the source assets, posters and video exports.

Rebuild from this repository's root with:
  /Users/berken/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 Marketing/2026-10-your-day-together/source/build.py

Requirements: macOS, Swift, Metal, Pillow, NumPy and Homebrew FFmpeg.
The build script also accepts --storyboards-only, --posters-only and
--videos-only. Existing phone renders are reused when their sources match.
Keep the repository's original Today captures and Health artwork available
when regenerating the collection. The included prepared assets support the
editable browser preview.

Original assets:
  source/3d/model/iphone_17_pro.glb
  ../2026-10-today/captures/
    iphone-18-pro-theme-02-dark-midnight-bg-dark-steps-off-sheen-mid-capture.png
  ../../Assets.xcassets/Health.imageset/Icon - Apple Health.png

Model attribution and the upstream code license are in THIRD-PARTY-NOTICES.txt.
Include the supplied model credit when publishing these exports.
The earlier flat-frame storyboard is preserved in stash/2d-draft/.

Other marketing collections and app source files are outside this asset's
production scope and remain unchanged by this work.
