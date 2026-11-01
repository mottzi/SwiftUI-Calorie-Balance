# Passive sharing with incremental incoming sync

Status: accepted and implemented, 31 October 2026.

Sharing screens render the last verified local state. They do not expose refresh controls, transient synchronization errors, or retry buttons.

## Decision

Use one incremental reader for each of the private and shared databases. Reuse the existing CloudKit database subscriptions. Fetch database changes with a saved token, then fetch only changed zones with their saved tokens. Persist raw records and all download tokens together in one atomic, account-scoped file. Advance the database token only after every changed zone has been applied. A token-expiration response resets the affected checkpoint and downloads a new baseline. Preserve encrypted CloudKit fields through secure record archiving. This cache is an input to the existing consent checks, never permission to show a card.

Retain direct CloudKit transactions for consent, share creation, publisher fencing, publication, and retention. Successful direct writes and deletions update the same raw cache. There is no second reader or outgoing engine queue.

CloudKit pushes request coalesced reconciliation through the app delegate. Incoming reconciliation does not republish health data. Newly ready consent grants schedule their first publication. Launch, foreground activity, HealthKit changes, settings changes, calendar changes, and network recovery remain publication triggers. HealthKit observers register at launch and complete after processing.

While a sharing screen is active, reconcile at most once per 60 seconds after a successful refresh. This is a recovery policy, not an Apple-prescribed interval or a freshness guarantee. Known changes bypass the freshness interval. Failures back off from five seconds to five minutes and respect longer CloudKit retry-after values. Network recovery requests reconciliation without bypassing an existing server backoff. No visibility timer runs in the background.

## Why the implementation changed after live verification

The first implementation used CKSyncEngine. On Sharing Cloud B after restoring its checkpoint, repeated explicit `fetchChanges()` calls emitted will-fetch and did-fetch events without any database-change request. The physical phone had published a new Today record, but B continued showing its older cache. This was observed in CloudKit's own logs. Push-driven updates to the phone worked.

A timer around an API that performs no server check cannot recover missed pushes. Rather than fake UIKit lifecycle notifications, discard checkpoints repeatedly, or maintain two competing sets of download tokens, this version uses the documented direct CloudKit change APIs for the single incoming reader. CKSyncEngine adoption is deferred until its explicit-fetch behavior can meet the recovery requirement in the supported environments.

## Consequences

Repeat discovery reads download deltas instead of scanning every shared zone from a nil token. Cached verified cards remain available during transient failure. Account changes invalidate readers and their raw cache. Consent, publisher generation, date-window checks, and locally queued revocations continue to govern displayed cards.

CloudKit delivery, background execution, and HealthKit availability still depend on iOS. An offline or suspended sender cannot guarantee immediate publication. Locked-device and long-duration background behavior require physical-device observation beyond foreground tests.

A disk write failure stops checkpoint advancement. The app retains its previously durable record/checkpoint pair. A persistent disk or decoding failure requires recovery before that reader can resume; the UI remains passive.

## References

See [the research and evaluation](../sharing-refresh-research.md) for Apple documentation and the reasons for retaining direct atomic writes. The live findings above supersede its initial CKSyncEngine recommendation.


## Follow-up validation, 31 October 2026

A read-only comparison reproduced the restored-state failure on the physical iPhone. Starting CKSyncEngine in will-finish-launching fixed that launch case twice without a push. The original integration started too late; it was incorrect to treat the initial observation as a general CKSyncEngine failure.

The correctly started engine still missed a later snapshot on Simulator B while the app stayed active and no push arrived. Repeated manual fetches did not discover it; a real foreground transition did. That active no-push case was not isolated on the physical phone. The current direct reader remains unchanged because it provides an explicit server check for the recovery policy. See [the controlled validation report](../cksyncengine-validation.md) for the results and limits.
