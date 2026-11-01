Count.kcal: Make it yours, iPhone

Version 3, revised 23 October 2026. An iPhone-only portrait composition
using four dark themes and a small Count.kcal header.
The original 12-second film and the compact iPhone-and-Watch version remain
unchanged in their respective collections.

DELIVERABLES

videos/count-kcal-make-it-yours-iphone-loop-transparent.webm
  886 x 1920, 30 fps, 216 frames, 7.2 seconds. VP9 with alpha, silent.

videos/count-kcal-make-it-yours-iphone-loop-dark-bg.mp4
  Same artwork and timing, H.264, fixed #0c1016 background, silent.

stills/count-kcal-make-it-yours-iphone-poster-transparent.png
  1772 x 3840 transparent master matching the opening frame.

stills/count-kcal-make-it-yours-iphone-app-store-screenshot.png
  1290 x 2796 RGB PNG with an opaque #0c1016 background.
  Uses an accepted large-display iPhone screenshot size.

source/make-it-yours-iphone.html
  Editable Canvas artwork with palette selection, scrubbing, playback controls
  and 320 px / 390 px preview widths. The Count.kcal header is included in
  the image and video exports. References the four original
  framed shots in the neighboring 2026-10-today collection.
  The inline configuration contains image references, layout and timing.
  Use ?t=0.95&paused=1&width=390 to inspect the first wave at mobile width.

COMPOSITION

The 886 x 1920 canvas has one centered, upright silver iPhone 18 Pro.
The phone never rotates, including during the bounce. Its 1400-pixel layout
height fills about 73 percent of the canvas. The 690-pixel palette row has
almost the same width as the phone and begins 90 pixels below its bottom edge.
The Count.kcal header uses 64-pixel semibold type, centered above the phone.
It stays visible throughout the loop. There is no separate opening title card.

The bounce lasts 0.9 seconds, with a 28-pixel lift and 1.6 percent scale pulse.
A smoother acceleration curve and small settling movement replace the earlier
sharper bounce. The ribbon reaches 92 percent opacity, with a 0.52-second
travel time and a gradual fade. The inset highlight stripe has been removed.
The ribbon curves below the header and around the phone. No Watch is rendered.

Themes run in order 01, 02, 08, 09, then back to 01.
Waves begin at 0.4, 2.2, 4.0 and 5.8 seconds. The first screen change finishes
at 0.86 seconds. Each wave lasts one second. Each bounce begins 0.15 seconds
after its wave and finishes before the next switch.
The final hold matches the opening state. Native-resolution screenshots are
joined before placement, so the wipe has no gap between its two images.

CAPTURES

The existing silver iPhone 18 Pro assets remain the source of the app imagery.
Marketing Mode, Midnight, dark appearance, dark background setting, Steps off.
The original clocks, app data and streak highlights are preserved.
Only existing captures were composed. No app or simulator changes were needed.

USE

Use the transparent WebM over a webpage background or the MP4 over #0c1016.
Set videos to muted, playsinline and loop. Provide a pause control and use the
poster instead of autoplay for reduced motion. Check transparent WebM playback
in the target browsers. The HTML preview respects reduced motion and pauses
rendering while hidden, offscreen or manually paused.

The opaque PNG is sized for an App Store screenshot. The portrait video is a
marketing composition, not a submission-ready App Preview. Apple requires
App Previews to show in-app content and last 15 to 30 seconds. This 7.2-second
framed loop includes external palette graphics. A submission preview needs
a separate in-app recording and edit; changing duration alone is insufficient.

Apple references checked 23 October 2026:
https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/
https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications/
https://developer.apple.com/app-store/app-previews/

VERIFICATION

Both video exports contain 216 frames at 30 fps and run 7.2 seconds.
The opening and final hold render identically. All transparent-video frames
retain clear outer edges, with no clipping of the phone or ribbon.
The screenshot PNG is RGB without alpha; the poster is RGBA.
All ten files in the two earlier motion collections match their saved hashes.
