# Sharing freshness research

Research date: 30 October 2026. Scope: Apple’s documented CloudKit, background-execution, and HealthKit behavior, compared with the current Count.kcal implementation. This is research, not an implementation change. Apple Fitness is a useful UX reference; its internal synchronization behavior is not established by these sources.

## Conclusion

The quiet, cache-backed sharing UI is appropriate. Removing error messages does not itself improve freshness. The next work should strengthen the synchronization service behind the screens: efficient incremental reads, independent incoming and outgoing work, durable retries, and foreground recovery. Aggressive polling is not Apple’s prescribed solution. No implementation can guarantee that a recipient instantly sees new health data when the sender’s phone is locked, offline, or unable to run.

Freshness has several stages: health samples reach the sender’s HealthKit store, Count.kcal reads them, the sender uploads a card, the recipient learns about the cloud change, then the recipient downloads and displays it. Optimizing only the last fetch leaves the earlier delays untouched. This is an inference from the APIs below.

## What Apple documents

### Notifications are hints, not a complete change log

CloudKit database notifications can be coalesced and omit details. Apple says to use the database scope to fetch changes, rather than treating each notification as a specific record event. A shared database needs database-level discovery because sharing adds and removes zones. [CKDatabaseNotification](https://developer.apple.com/documentation/cloudkit/ckdatabasenotification)

Background notifications have no delivery guarantee and may be delayed or throttled. Apple advises against sending more than two or three background notifications per hour; this is background-push guidance, not a foreground fetch interval. The delivered notification gives the app up to 30 seconds to work and call its completion handler. [Pushing background updates to your app](https://developer.apple.com/documentation/usernotifications/pushing-background-updates-to-your-app)

### Fetch changes incrementally

Apple’s zone-change API supports creations, modifications, and deletions in private and shared databases. It describes caching the initial result, subscribing to changes, and fetching changes after notifications. It explicitly says regular-interval fetches and fetches on every launch are not necessary with this model. That does not prohibit a targeted foreground recovery fetch, but does not justify claiming Apple recommends polling every 30 or 60 seconds. [CKFetchRecordZoneChangesOperation](https://developer.apple.com/documentation/cloudkit/ckfetchrecordzonechangesoperation)

Persist each zone’s change token, and provide it on later requests to receive only changes since the previous fetch. Tokens can be stored safely on disk. Apply a batch and its corresponding checkpoint together so a crash does not skip changes; that durability rule is our implementation recommendation. Handle pagination and token-expiry recovery. [previousServerChangeToken](https://developer.apple.com/documentation/cloudkit/ckfetchrecordzonechangesoperation/zoneconfiguration/previousserverchangetoken), [recordZoneFetchResultBlock](https://developer.apple.com/documentation/cloudkit/ckfetchrecordzonechangesoperation/recordzonefetchresultblock)

### CKSyncEngine is worth evaluating

CKSyncEngine supports separate engines for private and shared databases. Its automatic schedule depends on system conditions and is indeterminate. It discovers or creates a subscription, schedules fetches when notified, and retries specified transient errors, including throttling with retry-after. Apps persist its serialized state and still handle conflicts and application-specific failures. A caller can explicitly request a fetch when current information is needed. It does not replace our consent, publisher-authority, or retention rules. [CKSyncEngine](https://developer.apple.com/documentation/cloudkit/cksyncengine-4b4w9)

Apple prefers leaving automatic synchronization enabled unless there is a specific reason to take over scheduling. Migration is an architectural option, not a requirement to fix today’s gaps. [automaticallySync](https://developer.apple.com/documentation/cloudkit/cksyncengineconfiguration/automaticallysync)

### More requests can reduce freshness

CloudKit throttles bursts and unsuitable recurring request patterns. Apple recommends minimizing operations and honoring server retry-after values. Low battery can also delay work. Adding a fast timer around an expensive full refresh could increase delays rather than reduce them. [TN3162: Understanding CloudKit throttles](https://developer.apple.com/documentation/technotes/tn3162-understanding-cloudkit-throttles)

### Background refresh is opportunistic

BGAppRefreshTask can provide another chance to refresh content, but the system chooses when it runs and grants a short execution window. It is a supplementary recovery mechanism, not an exact schedule or real-time guarantee. Work must finish or be deferred within its budget. [Choosing background strategies for your app](https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app)

### The sender’s HealthKit delivery matters

HealthKit background delivery runs at most once per requested period; some types enforce a maximum of hourly delivery. Apple documents an hourly limit for iOS step counts, but this source does not establish the limits for every calorie type. Observer queries should be installed at app launch so they are ready for background deliveries. Complete observer processing and call its completion handler. Test on a physical device because background queries are not supported on Simulator. Requesting `.immediate` is worth evaluating per relevant type, but it is not a promise of instant delivery. [enableBackgroundDelivery](https://developer.apple.com/documentation/healthkit/hkhealthstore/enablebackgrounddelivery(for:frequency:withcompletion:))

A locked device can make HealthKit data unreadable. Do not replace previously valid cards with zero values when a query is unavailable. [Protecting user privacy](https://developer.apple.com/documentation/healthkit/protecting-user-privacy), [errorDatabaseInaccessible](https://developer.apple.com/documentation/healthkit/hkerror/errordatabaseinaccessible)

## Current implementation compared with that guidance

These findings come from the local code audit, not Apple documentation:

| Area | Current behavior | Implication |
| --- | --- | --- |
| Foreground | Overview starts refresh; active app lifecycle refreshes once sharing is used. Detail observes shared state without its own entry check. | Good basic recovery, but long visible detail sessions rely on notifications. The coordinator already coalesces ordinary refreshes and queues a follow-up for changed notifications; retain this. |
| Notifications | Private/shared database subscriptions request content-available pushes. Handler calls a refresh that also publishes this phone’s cards. | Correct notification foundation; reads and uploads are unnecessarily coupled. Completion always reports newData without tracking outcome, and waits for full incoming plus outgoing work, risking the 30-second budget. |
| Incoming changes | `allRecords` starts with a nil zone token each invocation; tokens only paginate that invocation. | Repeated full scans rather than durable incremental synchronization. |
| Recovery | No retry-after scheduler, backoff, network-recovery trigger, or BGAppRefreshTask found. | A transient failure may wait for an unrelated later trigger. |
| Outgoing changes | Each publication pass reads/uploads all permitted days and writes lastPublication even when content is unchanged. | Extra work, contention, and potential notification feedback. A live feedback loop has not been proven. |
| HealthKit | Hourly delivery requested for active, basal, and dietary energy. Registration result ignored; observers start after publisher verification. Completion waits for the publication pass. | There is no didFinishLaunching observer setup. Audit cold background launch, registration failures, and long observer work on real phones. |
| UI freshness | Snapshot capturedAt uses lastDataSync, which HealthRepository sets to the successful query time. | This is the sender’s read time, not proof of the latest Watch sample or source-ingestion completeness. Keep it distinct from receiver fetch time. |

Relevant code: `SharingOverviewView.swift`, `SharingPersonDetail.swift`, `SharingLifecycleModifier.swift`, `SharingRuntime.swift`, `SharingAppDelegate.swift`, `SharingHealthObserver.swift`, `SharingCoordinator.swift`, and `CloudKitSharingTransport.swift` under `Count.kcal/Sharing/`.

## Recommended order of work

1. Make incoming reads incremental with durable database/zone checkpoints and deletions, or evaluate CKSyncEngine. Preserve all existing authorization and consent validation.
2. Separate receipt of remote changes from publication of this phone’s health data. Publish on actual source changes, skip identical card payloads, and prioritize Today over historical maintenance. Keep old historical days available while new records arrive.
3. Add a shared freshness coordinator. A screen becoming visible or the app becoming active should request reconciliation when stale or previously failed; multiple callers should join one request. Screens remain passive observers and show cached data immediately.
4. Add durable transient-failure recovery, bounded exponential backoff with jitter, and strict retry-after handling. Network/account recovery should create another opportunity. Do not retry terminal access loss as a network failure.
5. If measurements show missed pushes leave an actively viewed feed stale, trial a modest foreground-only adaptive reconciliation check. Run only while a sharing screen is visible, back off when nothing changes, and stop when hidden or backgrounded. Any interval is a product experiment, not an Apple recommendation. Implement cheap deltas before introducing such a fallback.
6. Strengthen sender delivery: initialize eligible HealthKit observers at launch, inspect registration errors, assess `.immediate` for the calorie types, and defer safely when protected data is unavailable. Separate durable pending work from lengthy network completion where appropriate.
7. Consider BGAppRefreshTask as an additional recovery opportunity after the core paths are efficient. Do not present it as a scheduled guarantee.

Keep a neutral card-age label such as “Updated 12 minutes ago,” including an accessible overview treatment when useful. Distinguish the sender’s successful read time, any known latest source sample time, cloud publication time, and recipient fetch time. A successful empty fetch must not make an old card look newly measured; a recent sender read does not prove all Watch samples have arrived. Retain permitted cached content through temporary failures, but respect revocation and the allowed date window. These are UX recommendations derived from the documented delivery limits, not quoted HIG requirements.

Measure sender sample-to-publication and recipient publication-to-display separately. Record metadata-only timestamps and operation counts. Test both real iPhones with foreground/background transitions, locked sender, offline recovery, low power, delayed/missed notifications, cold launch, and consent changes. Simulator tests alone cannot establish HealthKit background freshness.

## CKSyncEngine decision for this sharing protocol

Follow-up evaluation, 30 October 2026.

**Recommendation: adopt CKSyncEngine for incoming incremental replication, while retaining the current direct CloudKit commands for consent, publisher authority, share creation, publication, and retention.** Treat this as a staged architecture change with a narrow interface, rather than replacing the whole transport at once. This recommendation is our engineering judgment, not an Apple-prescribed combination.

The incoming path is where the engine offers the clearest maintenance benefit: it owns change checkpoints, automatic fetching, notification scheduling, and recovery from supported transient failures. The current full scans and custom recovery gaps match that responsibility. Use one engine per database, private and shared, under one app-level service. Apple specifically warns against multiple production engines targeting the same database. The engine can reuse a chosen existing subscription ID during migration. [Database configuration](https://developer.apple.com/documentation/cloudkit/cksyncengineconfiguration/database), [Subscription migration](https://developer.apple.com/documentation/cloudkit/cksyncengine-5sie5/configuration/subscriptionid)

### Atomic publication is possible with the engine

CKSyncEngine does support atomic writes. `RecordZoneChangeBatch.atomicByZone` defaults to false; setting it true makes a failing change fail the other changes in the same zone. Its explicit batch initializer accepts the complete records-to-save and IDs-to-delete arrays. Therefore, the publisher record, scope root, and card could in principle remain one atomic same-zone transaction. It would be incorrect to reject the engine because it cannot express atomicity. [Atomic batches](https://developer.apple.com/documentation/cloudkit/cksyncengine-5sie5/recordzonechangebatch/atomicbyzone), [Explicit batch initializer](https://developer.apple.com/documentation/cloudkit/cksyncengine-5sie5/recordzonechangebatch/init(recordsToSave:recordIDsToDelete:atomicByZone:))

Apple’s WWDC example demonstrates engine sends failing with `serverRecordChanged`, requiring application conflict resolution and rescheduling. Direct CloudKit’s `ifServerRecordUnchanged` policy explicitly compares record change tags. Those facts support optimistic concurrency, but do not make generic conflict merging correct for this app’s publisher lease. A changed authority record must trigger revalidation of the whole publication transaction, and possibly cancellation, rather than merging an old card into a new publisher generation. [WWDC23: Sync to iCloud with CKSyncEngine](https://developer.apple.com/videos/play/wwdc2023/10188/), [Compare-and-save policy](https://developer.apple.com/documentation/cloudkit/ckmodifyrecordsoperation/recordsavepolicy/ifserverrecordunchanged)

Moving outgoing writes into the engine now would require a durable transaction-aware queue that preserves the entire authority group across batching, conflicts, cancellation, account changes, and retries. Automatic batching by independent record IDs must never split the authority guard from its protected write. That is feasible, but adds migration risk without being necessary to gain efficient incoming updates. Retaining direct writes is a scope and correctness decision, not a claim of an engine limitation.

### Consent and shared scopes remain application responsibilities

The engine synchronizes accessible records; it does not decide whether a card is authorized under our current consent generation, accepted scopes, publisher generation, or retention window. Its fetched data must enter a raw local cache first and pass the existing verification before entering the UI’s trusted snapshot state. A record arrival must not automatically mean permission to display it. Process known revocation promptly and never reintroduce locally hidden data from a delayed fetch.

Keep root-based CKShare creation, participant permissions, acceptance, and share removal in the existing explicit command path. Apple describes these as separate sharing operations; accepted shared zones expose only the shared hierarchy. The per-owner read-only control model remains useful and compatible with fetching from the shared database. Do not queue writes to a peer’s read-only records. [Shared records and participation](https://developer.apple.com/documentation/cloudkit/shared-records)

### Hybrid integration contract

There is no separate “read-only mode” required to fetch: the delegate supplies no outbound changes and returns nil when there is nothing to send. The engine should have no pending record or database writes in this first stage. This is an architectural inference from the delegate contract, not a separately documented hybrid mode. [Outbound delegate contract](https://developer.apple.com/documentation/cloudkit/cksyncenginedelegate-1q7g8/nextrecordzonechangebatch(_:syncengine:))

All direct command results and engine events must converge through one account-scoped cache/reconciliation service with idempotent event application and one notification owner. Never enqueue the same direct-written records for engine sends. Keep raw CKRecord metadata and engine state durable, apply direct write results locally, and invalidate/reconcile affected records after share operations. Never assume this device will receive a push for its own direct write. Engine events are serial; do not await fetchChanges or sendChanges from within its event handler. Schedule subsequent work outside the callback. [Delegate ordering](https://developer.apple.com/documentation/cloudkit/cksyncenginedelegate-1q7g8)

The reviewed Apple material establishes engine fetch/send contracts but does not provide an explicit end-to-end guarantee for our exact combination of direct CKShare changes and an otherwise fetch-only engine. Validate same-device share creation/removal visibility, direct-write reconciliation, cold restart, and account changes before replacing the old reader. Keep direct metadata verification where permission decisions need it. This uncertainty is a validation requirement, not evidence that coexistence is unsupported.

The first migration should not leave two competing full-database readers active indefinitely. Retire the old full-scan read path once the engine-backed cache passes the same consent and deletion checks. Preserve targeted server reads used to authorize commands. If the hybrid prototype cannot meet those checks on supported OS versions, durable custom database/zone deltas are the fallback. Full outgoing-engine adoption can be reconsidered later if its transaction queue reduces, rather than duplicates, our current protocol machinery.


## Implementation decision after live testing, 31 October 2026

The initial CKSyncEngine implementation passed model/cache tests but failed missed-push recovery on Sharing Cloud B. After restoring saved state, its explicit fetch emitted will/did-fetch events without a database-change operation. The phone's persisted private cache confirmed a new Today card had been published, while B retained the old shared cache. Push-driven simulator-to-phone updates did work.

The implementation therefore uses one direct incremental reader per database with database and zone change tokens persisted atomically alongside raw records. Existing subscriptions drive incoming refresh; the visible-screen recovery check now makes a real database-change request. This avoids a second reader and avoids synthetic UIKit lifecycle notifications. See [ADR 0003](adr/0003-passive-sharing-incoming-sync.md). This supersedes the earlier CKSyncEngine recommendation for this release.

Apple documents the direct APIs at [databaseChanges](https://developer.apple.com/documentation/cloudkit/ckdatabase/databasechanges(since:resultsLimit:)) and [recordZoneChanges](https://developer.apple.com/documentation/cloudkit/ckdatabase/recordzonechanges(inzonewith:since:desiredkeys:resultslimit:)). The decision is based on the observed device behavior, not an assertion that CKSyncEngine fails in all configurations.


## Follow-up validation, 31 October 2026

A read-only comparison reproduced the restored-state failure on the physical iPhone. Starting CKSyncEngine in will-finish-launching fixed that launch case twice without a push. The original integration started too late; it was incorrect to treat the initial observation as a general CKSyncEngine failure.

The correctly started engine still missed a later snapshot on Simulator B while the app stayed active and no push arrived. Repeated manual fetches did not discover it; a real foreground transition did. That active no-push case was not isolated on the physical phone. The current direct reader remains unchanged because it provides an explicit server check for the recovery policy. See [the controlled validation report](cksyncengine-validation.md) for the results and limits.
