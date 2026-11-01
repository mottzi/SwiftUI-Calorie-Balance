# 07 - Keep published cards current and bounded

**What to build:** Connect successful health/appearance refreshes and foreground/background opportunities to immutable publication; fetch received updates, republish historical corrections, and clean expired local/cloud copies with durable retries. Demo failed reads/uploads retaining prior values and timestamps, valid zeroes, sender midnight/travel, and eventual-cleanup disclosure.

**Blocked by:** 03 - Exchange mutually accepted Today cards; 05 - Share the previous seven completed days

**Status:** completed

- [x] The described end-to-end behavior works with explicit pending and error states.
- [x] Meaningful deterministic tests cover permissions, failures and relevant dates.
- [x] Relevant UI supports localization, Dynamic Type, VoiceOver and Reduce Motion.
- [x] Required review is complete and any requested correction is verified.

Canonical requirements are in the calorie-card sharing specification and research in Docs.

Verification and review scope: /private/tmp/count-kcal-sharing-planning/ticket-7/review.md. External delivery/cloud release checks remain unexecuted.

Parent review completed. Both issues in the one correction batch are fixed and verified. Evidence: /private/tmp/count-kcal-sharing-planning/ticket-7/correction/evidence.md.
