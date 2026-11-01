# 04 - Reduce, pause, and remove a connection

**What to build:** Stop local viewing/publication immediately, durably revoke each outgoing/incoming scope operation, clear received caches, retry partial failures, and reject stale consent. Demo an offline pause or removal that stays visibly pending until server confirmation.

**Blocked by:** 03 - Exchange mutually accepted Today cards

**Status:** completed

- [x] The described end-to-end behavior works with explicit pending and error states.
- [x] Meaningful deterministic tests cover permissions, failures and relevant dates.
- [x] Relevant UI supports localization, Dynamic Type, VoiceOver and Reduce Motion.
- [x] Required review is complete and any requested correction is verified.

Canonical requirements are in the calorie-card sharing specification and research in Docs.

Verification and review scope: /private/tmp/count-kcal-sharing-planning/ticket-4/review.md.

Parent single review approved ticket 04 without corrections. Server known-record denial remains an external release check.
