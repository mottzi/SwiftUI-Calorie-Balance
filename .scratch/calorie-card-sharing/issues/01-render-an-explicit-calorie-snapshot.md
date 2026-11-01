# 01 - Render an explicit calorie snapshot

**What to build:** Prefactor the local card to build and render a captured presentation. Demo matching local and received cards with different recipient settings, both today modes, historical totals, sender colors, units, and hidden goal status.

**Blocked by:** None. Can start immediately.

**Status:** completed

- [x] The described end-to-end behavior works with explicit pending and error states.
- [x] Meaningful deterministic tests cover permissions, failures and relevant dates.
- [x] Relevant UI supports localization, Dynamic Type, VoiceOver and Reduce Motion.
- [x] Required review is complete and any requested correction is verified.

Canonical requirements are in the calorie-card sharing specification and research in Docs.

Verification: seven SharingSnapshotTests passed on iPhone 18 Pro iOS 27 simulator, including raster parity across both modes, light/dark and accessibility text. Review packet: /private/tmp/count-kcal-sharing-planning/ticket-1/review.md.

Parent review approved ticket 01 without corrections.
