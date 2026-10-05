# Watch HealthKit history and iPhone parity

Research date: 2026-10-04. Scope: whether local watch HealthKit queries can replace the current phone weight snapshot while preserving the iPhone's weekly and monthly metrics. No code changes.

## Claim audit

Claim checked: Apple recommends querying calories locally on watch while delivering weight from iPhone. No explicit recommendation for that split was found in the primary Apple sources reviewed. The split is an app-specific compromise between independent recent data and exact longer-history parity. HealthKit's automatic synchronization and watch retention constraints apply to the store, not a documented calories-versus-weight delivery policy. [About the HealthKit framework](https://developer.apple.com/documentation/healthkit/about-the-healthkit-framework)

Apple's current independent-app guidance adds a material qualification to the recommendation below. Independent watch apps must access their own information and cannot use Watch Connectivity as their main data source. A companion can supply opportunistic updates when available. [Creating independent watchOS apps](https://developer.apple.com/documentation/watchos-apps/creating-independent-watchos-apps)

The broader content-update guide also says that even dependent apps should remain useful while away from the phone. It recommends Watch Connectivity as an opportunistic optimization rather than the primary supply of fresh data. Retaining a snapshot preserves an offline display, but does not provide independent refresh. [Keeping your watchOS content up to date](https://developer.apple.com/documentation/watchos-apps/keeping-your-watchos-app-s-content-up-to-date)

Shared calculations establish the same meaning for calories and weight. They do not establish identical inputs or freshness. A local watch calorie total can differ from the iPhone until HealthKit synchronization completes. A weight snapshot can exactly reproduce the phone's captured inputs and still lag its current values. Calling both simply "mirrored" hides that difference.

For strict phone mirroring, the phone snapshot approach should apply to every metric covered by that promise, with its capture date retained. For an independently useful watch app, local HealthKit reads should provide recent metrics and phone snapshots can supplement history unavailable locally. That hybrid needs a clear distinction between current local results and phone history. It should not silently treat a partial local month as the complete iPhone month.

The minimum architecture recommendation below is therefore scoped to reproducing the phone's latest received weight snapshot. It is not a general Apple recommendation, does not guarantee current phone values, and should not be presented as the ideal refresh design for an independent app. No implementation changes were requested by this audit.

## What Apple documents

iPhone and Apple Watch have separate HealthKit stores. HealthKit automatically synchronizes data between devices, but periodically purges old watch data to save space. A watch query runs against the watch's store. The documented model is synchronization of local stores, not a query that automatically falls back to the phone's complete history. [About the HealthKit framework](https://developer.apple.com/documentation/healthkit/about-the-healthkit-framework)

`earliestPermittedSampleDate()` reports the platform boundary for saving or reading samples. A query that asks for earlier samples returns samples after that boundary. Apple does not promise a fixed number of retained days here, so do not claim a universal seven-day or two-week limit. This platform constraint is separate from the person's read authorization. [earliestPermittedSampleDate](https://developer.apple.com/documentation/healthkit/hkhealthstore/earliestpermittedsampledate())

`HKStatisticsCollectionQuery` calculates statistics over quantity samples in fixed intervals and can update as the store changes. Apple recommends it for quantity statistics and charts. Its descriptor is the Swift concurrency form used in this app. Body mass uses discrete arithmetic aggregation; calories use cumulative aggregation. Daily body-mass averages and calorie sums are therefore appropriate HealthKit queries. [HKStatisticsCollectionQuery](https://developer.apple.com/documentation/healthkit/hkstatisticscollectionquery), [Exploring New Data Representations in HealthKit, WWDC19](https://developer.apple.com/videos/play/wwdc2019/218/)

The statistics API aggregates stored quantity data, including quantities represented in series samples. That is different from retrieving every raw measurement. The cited Apple sources do not promise that arbitrary historical body-mass statistics survive watch purging, that a complete thirty-day window is always present, or that statistics queries retrieve missing history from iPhone. The absence of a guarantee is enough to reject local-only queries as a guarantee of exact month parity. It does not prove that every device will fail a month query.

Apple recommends Watch Connectivity for sharing data available on only one device and for starting the counterpart app with the same recent content. Application context communicates the latest state in a replaceable background dictionary. Background delivery is not immediate. Interactive messages require reachability, so requesting the phone to run a query is a separate app-to-app operation with different availability constraints. [There and back again: Data transfer on Apple Watch, WWDC21](https://developer.apple.com/videos/play/wwdc2021/10003/)

## What that means for this app

The iPhone already queries HealthKit through [`HealthKitDataSource`](../../Count.kcal/Abstract/System/HealthKitDataSource.swift). It does not need another raw health database. `HealthRepository` produces rounded daily body-mass averages beginning at the Monday boundary at or before thirty days ago. `WeightHistory` uses the last seven daily buckets for the weekly mean and the last thirty for the monthly mean. The chart includes the Monday lead-in, and latest weight comes from a separate raw-sample query. Missing days remain missing. [Repository](../../Count.kcal/Abstract/System/HealthRepository.swift), [shared calculations](../../Count.kcal/Abstract/WeightHistory.swift)

A local watch query can give the same result when its authorized, synchronized store contains all the required inputs. It cannot establish that the entire phone month is present merely because the query succeeds. A retained daily statistic is also not a replacement for the latest raw weight and its timestamp, which may be older than the displayed chart period.

Recent kcal queries have a smaller historical requirement and benefit from reading watch-local activity immediately. They can still differ temporarily from the phone during synchronization. If exact simultaneous iPhone parity became a requirement for kcal too, local queries alone would not guarantee that either. The distinction is the product requirement and required history, not a special HealthKit rule that calories are mirrored but weight is not.

## Minimum architecture recommendation

For this user's exact-mirror requirement, keep HealthKit responsible for raw sample synchronization. Let the iPhone send only the bounded daily weight aggregates already used by its chart, the latest raw weight and timestamp, the unit, and the snapshot date through the existing application context. On watch, retain the latest received snapshot and use the shared calculations. Preserve the source period rather than silently treating an old snapshot as today's complete month. Send settings and weight together because a new application context replaces the previous dictionary.

This is our recommendation based on Count.kcal's required semantics and Apple's documented constraints. Apple does not prescribe this exact weight architecture. It avoids a second database, raw-sample replication, and a reconciliation layer while making the watch match the phone's latest received snapshot.

The tradeoff is freshness. The phone must query or recompute weight before publishing a newer snapshot, and delivery may wait. A retained snapshot remains useful without the phone, but cannot promise current HealthKit results. A reachable-phone refresh request can improve freshness if needed later; it should not become a prerequisite for opening the tab. Local watch fallback would add partial-history and mixed-source states, so it is unnecessary for the current scope.

The current phone refresh occurs in `Pager`, and there is no weight observer. The next improvement should be to observe body-mass additions and deletions on the phone and refresh the compact snapshot when HealthKit permits background execution. Apple provides observer queries and background delivery for that purpose. This improves freshness without adding another history source or requiring the person to open the phone app for every change. Background delivery and Watch Connectivity still have system-controlled timing. [HKObserverQuery](https://developer.apple.com/documentation/healthkit/hkobserverquery), [enableBackgroundDelivery](https://developer.apple.com/documentation/healthkit/hkhealthstore/enablebackgrounddelivery(for:frequency:withcompletion:))

Primary documentation content was read from Apple's official Markdown endpoints where the HTML pages only returned JavaScript placeholders.
