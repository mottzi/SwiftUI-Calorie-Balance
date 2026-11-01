# 08 - Recover safely across accounts and publishing phones

**What to build:** Persist account isolation and publisher generations, add explicit takeover, handle sign-out/switch/temporary uncertainty, and reject obsolete work or unknown snapshot versions. Demo recovery after restart and account change without affecting ordinary Count.kcal settings or data.

**Blocked by:** 03 - Exchange mutually accepted Today cards; 04 - Reduce, pause, and remove a connection

**Status:** completed

- [x] The described end-to-end behavior works with explicit pending and error states.
- [x] Meaningful deterministic tests cover permissions, failures and relevant dates.
- [x] Relevant UI supports localization, Dynamic Type, VoiceOver and Reduce Motion.
- [x] Required review is complete and any requested correction is verified.

Canonical requirements are in the calorie-card sharing specification and research in Docs.

Verification and review scope: /private/tmp/count-kcal-sharing-planning/ticket-8/review.md. External account/backup/production checks remain unexecuted.

Parent single review approved ticket 08 without corrections. Physical backup and live CloudKit takeover checks remain external release verification.
