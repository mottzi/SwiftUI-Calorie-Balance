Count.kcal: Make it yours, compact

A separate 7.2-second version for brief viewing and smaller placements.
The original 12-second film remains in ../2026-10-make-it-yours/ unchanged.

The 4:3 artwork contains the devices and four palette swatches. The headline
and subtitle sit above it as webpage text in the interactive preview, so they
can stay readable independently of video size. No text is baked into the video.

DELIVERABLES

videos/count-kcal-make-it-yours-compact-loop-transparent.webm
  1600 x 1200, 30 fps, 216 frames, 7.2 seconds. VP9 with alpha, silent.

videos/count-kcal-make-it-yours-compact-loop-dark-bg.mp4
  Same artwork and timing, H.264, fixed #0c1016 background, silent.

stills/count-kcal-make-it-yours-compact-poster-transparent.png
  3200 x 2400 transparent poster matching the opening frame.

source/make-it-yours-compact.html
  Editable Canvas animation, real webpage headline and playback controls.
  Includes 320 px and 390 px preview widths, palette selection and scrubbing.
  Relative references use the existing Today and Watch collections.
  Keep those neighboring collections in place when opening this source.
  The inline configuration contains layout, image references and timing.
  Use ?t=0.84&paused=1&width=390 to inspect the first switch at mobile width.

WHAT CHANGED

Four dark themes remain in order 01, 02, 08, 09, then back to 01.
The first wave begins at 0.4 seconds. Both screen changes finish by 0.95 seconds.
Each following switch begins 1.8 seconds after the previous one.
The wave is broader and brighter, with a bright moving section and fading tail.
The selected swatch presses and rebounds as it sends the wave toward the devices.
The iPhone and Watch lift 36 and 44 layout pixels, with a 3 percent scale pulse.
Both devices settle between switches. There is no continuous floating motion.
At the same displayed asset width, the iPhone is about 32 percent larger and
Watch about 80 percent larger than in the original wide film.

TIMING

0.00 to 0.40 s    Hold theme 01, blue and orange.
0.40 to 1.00 s    Reveal theme 02, indigo and green.
2.20 to 2.80 s    Reveal theme 08, purple and gold.
4.00 to 4.60 s    Reveal theme 09, teal and coral.
5.80 to 6.40 s    Return to theme 01.
7.20 s           Loop to the identical opening state.

Each wave lasts 0.9 seconds. The device bounces last 0.55 seconds, beginning
0.15 seconds after the wave for iPhone and 0.24 seconds after it for Watch.
The screen wipes take 0.34 seconds. Matching source images are joined before
device rotation, so the wipe has no antialiased gap through the screenshot.

CAPTURES

Existing silver iPhone 18 Pro and black Apple Watch Series 11 frames.
Marketing Mode, Midnight, dark appearance and dark background setting, Steps off.
Original screenshot data, clocks and captured streak highlights are preserved.
These are marketing transitions between captures, not recordings of an app
settings interaction. No production app files were needed for this variant.

WEBSITE USE

Place the headline in the webpage above the asset, as shown in the HTML preview.
Set video playback to muted, playsinline and loop, and provide a pause control.
Use the poster instead of autoplay when reduced motion is requested.
The HTML preview respects reduced motion and stops drawing while paused,
offscreen or in a hidden tab. Playback begins when the artwork is visible.
Check transparent WebM playback in the target browsers. The MP4 has a fixed
background; the editable Canvas source offers another way to render the motion.
This is a website asset, not an App Store submission export.

VERIFICATION

Reviewed at 320 px and 390 px widths. Opening and loop-boundary renders match.
The original collection was checked against SHA-256 hashes before and after.
