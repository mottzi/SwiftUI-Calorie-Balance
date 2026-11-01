Count.kcal: See where today is heading

An eight-second explainer for the Now to Midnight calorie-card switch.
Theme 01, dark Marketing Mode imagery. The card shows a 280 kcal deficit now
and a 600 kcal projected deficit at midnight, then returns to Now.

DELIVERABLES

videos/count-kcal-now-midnight-explainer-wide-dark-bg.mp4
videos/count-kcal-now-midnight-explainer-wide-transparent.webm
  Wide website layout, 1800 x 1000, 30 fps, 240 frames, 8 seconds.

videos/count-kcal-now-midnight-explainer-mobile-dark-bg.mp4
videos/count-kcal-now-midnight-explainer-mobile-transparent.webm
  Stacked mobile layout, 1080 x 1440, 30 fps, 240 frames, 8 seconds.

stills/count-kcal-now-midnight-explainer-wide-poster-transparent.png
stills/count-kcal-now-midnight-explainer-mobile-poster-transparent.png
  Transparent opening-frame posters at the matching export dimensions.
  The original 1166 x 690 card is placed below its source pixel dimensions
  in both layouts. These are not enlarged screenshot masters.

source/now-midnight-explainer.html
  Editable Canvas composition with inline layout, type, colors and timing.
  Responsive layout, Now/Midnight selection, scrubbing and pause controls.
  Select Mobile to review at 390 px. Use ?paused=1&t=3.5&layout=mobile to
  open the midnight state. Preview respects reduced motion and pauses when
  offscreen or hidden. Safari uses the finished MP4 because it does not
  preserve this VP9 video's alpha when drawing the source card to Canvas.
  Other browsers use the editable Canvas and the retimed transparent card.

source/calorie-card-now-midnight-source.webm
  Retimed transparent source card for the HTML composition, 1166 x 690.
  Eight seconds, 30 fps. The original cutout and native transitions are kept.
  Extra hold time makes the states easier to read; no values were redrawn.

STORY AND TIMING

0.00 to 0.80 s   Hold the current balance.
0.80 to 2.90 s   Play the native press and transition to Midnight.
2.90 to 5.30 s   Hold the midnight projection.
5.30 to 6.93 s   Play the native return to Now.
6.93 to 8.00 s   Hold Now, then loop to the identical opening state.

The timeline advances during the screen change and returns with it.
Captions briefly crossfade between "Your balance right now." and
"Your projected balance tonight." The blue label names the active state.
The app card supplies its original number animation and button press effect.
It is not floated, rotated or reconstructed from separate text layers.

SOURCE AND PRESERVATION

The source is ../2026-10-calorie-card/animation/
calorie-card-theme-01-dark-now-midnight-loop.apng.
The original source has 169 frames. This piece uses frames 0, 18 through 80,
81, 102 through 150, and 168, with longer holds on the endpoint states.
The native card retains its complete rounded corners and raised lower edge.
The neighboring calorie-card collection and all three Make it yours
collections remain unchanged. No app code or simulator changes were needed.

WEBSITE USE

Use the wide version beside or within a desktop feature section, and the
stacked version on mobile. The headline and supporting copy are included in
the exports. All videos are silent. Set playback to muted, playsinline and
loop, and provide a pause control. Use the poster for reduced motion.

The MP4 files use #0c1016. The WebM files contain VP9 alpha and work over other
dark backgrounds in compatible browsers. Safari did not preserve their alpha
in the Canvas preview, so use MP4 there rather than assuming transparency.
The transparent PNG posters can sit directly over the website background.

The timeline and explanatory copy are marketing graphics around recorded app
imagery. This website explainer is not an App Store submission preview.

VERIFICATION

Both layouts were inspected at small display widths. Exports have 240 frames
at 30 fps and last exactly eight seconds. The opening and final hold renders
match. Transparent exports retain alpha and have clear outer borders.
Safari layout and state selection were checked using the finished MP4 fallback.
All 32 files in the source card and previous motion collections match their
original hashes. Production app code was not touched.
