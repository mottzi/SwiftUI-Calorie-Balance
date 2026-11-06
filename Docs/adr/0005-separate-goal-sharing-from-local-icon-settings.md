# Separate goal sharing from local icon settings

This supersedes ADR 0004’s hidden-icon publication rule and extends its separate-consent design.

Today and Previous 6 Days authorize calorie values. A new Goal status & streak scope authorizes reached/not-reached results for those permitted dates, plus the full streak count ending yesterday. The count may reveal goal achievement beyond the six-day history window. With both calorie options off, this scope shares only the count. Numeric goal targets never leave the sender.

Goal records use their own read-only CloudKit hierarchy. Each daily result references its calorie scope and consent generation. Receiving and cleanup reject results after that calorie grant is revoked or replaced. Rendering joins results only to the matching snapshot identity and capture time. Calorie records omit goal results, exclusions and streaks, and old received calorie caches are sanitized.

There is no supported count-only permission or upgrade UI. Existing development Streak grants are revoked through the ordinary reduction path, preserving the connection and its calorie grants. Their old raw scope value is decoded only so stored control history can be replayed and its old hierarchies removed. It cannot be selected, accepted, published or displayed. The sole goal option is Goal status & streak, initially off for these connections until fresh mutual consent is accepted.

Hide goal status icons controls checkmark and cross rendering on the viewer’s device, consistently in overview and detail. It has no effect on goal publication. There is no persisted legacy icon-preference migration. Both phones need the updated app to use the new scope.

Names retain the sender’s goal accent under every scope, including calorie-only sharing and pauses. This appearance choice is deliberately independent of goal-result consent.
