# HealthKit history on Apple Watch

Canonical research report, checked 2026-10-04. This replaces the architectural conclusions in the earlier watch-history research notes. Scope is Count.kcal's weekly and monthly weight and later browsing dates for calories and steps. No production code changed during this research.

## Conclusion

Direct HealthKit queries are the appropriate default for displaying the authorized health data currently available on Apple Watch, including historical charts. HealthKit handles its own device synchronization and provides statistical aggregation. A second raw-data synchronization pipeline is unnecessary.

A different requirement is to display the exact results captured by the iPhone for a particular historical window, including data outside watch availability. The reviewed APIs do not guarantee that an ordinary watch query will return that identical dataset at that time. A small phone-derived response or snapshot can satisfy captured-result parity when available. That is a conditional application design, not Apple's prescribed architecture for weight.

Neither conclusion establishes that a month of weight is unavailable on every watch. Query the requested interval using the shared semantics. Respect documented boundaries and query errors. Add delivery only if the product needs more than the currently available watch result, rather than treating every missing measurement as a reason to build transport.

## Corrections to earlier claims

| Earlier claim or implication | Correct statement |
| --- | --- |
| Apple recommends calories locally and weight from the phone. | No reviewed Apple source prescribes this metric-specific split. |
| A watch cannot query a whole month of weight. | A watch can issue that query. Its current readable results depend on availability and permission. There is no universal retained-day count in the inspected contract. |
| Future historical browsing requires phone requests and a cache. | Browsing available local history requires neither. Phone delivery is conditional on access beyond watch coverage or captured iPhone parity. |
| Loss of original raw objects proves loss of historical statistics. | Workout condensation deletes originals while preserving data and statistical results. Condensation and watch purging are different operations. |
| Direct querying is guaranteed to backfill any missing phone history. | Automatic sync is documented. Query-triggered historical backfill and a remote-history completion guarantee were not found. This absence is not proof that the system never transfers older data. |
| The same formula guarantees the same number on both devices. | The formula, input window, units, missing-data rules, and input data all need to agree. Synchronization and capture time can change the inputs. |
| Empty samples or thirty returned day buckets establish completeness. | Neither establishes it. Empty data has privacy and availability ambiguity; calendar buckets can exist without measurements. |

The prior phone-first recommendation assumed the stronger parity requirement without making that assumption clear. The direct-query default and the conditional parity option should have been distinguished from the start.

## Documented facts

### 1. Queries read a current store snapshot; HealthKit owns synchronization

Apple's current reading guide states: "Queries return the current snapshot of the requested data from the HealthKit store." Long-running queries react to store changes. Statistics collection queries can recalculate when matching samples are added or removed; observer queries can request background delivery. A completed query is a snapshot, rather than a promise that another device has the same inputs. [Reading data from HealthKit, current documentation checked 2026-10-04](https://developer.apple.com/documentation/healthkit/reading-data-from-healthkit)

Apple separately documents a HealthKit store on each device, automatic synchronization, and periodic purging of old watch data. The precise statement is: "HealthKit automatically syncs data between these devices." Its next sentence explains watch purging. These facts must be read together. Automatic sync does not imply that every store is a complete permanent replica. [About the HealthKit framework, current documentation checked 2026-10-04](https://developer.apple.com/documentation/healthkit/about-the-healthkit-framework)

WWDC20 explains that developers need not handle HealthKit's device synchronization. Its second HealthKit session gives a concrete example: a newly saved iPhone sample is synchronized to the watch, with identifier/version metadata preventing duplicate writes and supporting updates. That is evidence of framework-owned synchronization, rather than an instruction to replicate the raw store through Watch Connectivity. [Getting started with HealthKit, WWDC20](https://developer.apple.com/videos/play/wwdc2020/10664/), [Synchronize health data with HealthKit, WWDC20](https://developer.apple.com/videos/play/wwdc2020/10184/)

Apple DTS Engineer Ziqiao Chen's accepted December 2024 reply explains that watch-generated data reaches the paired phone after the stores synchronize, so the phone query can lag. Its exact qualification is: "the HealthKit stores don't synchronize in real time." This supplies explicit first-party evidence against instantaneous cross-device query equality. It does not say that synchronization never includes historical data. [Apple DTS, HealthKit synchronization delay, December 2024](https://developer.apple.com/forums/thread/770968)

No reviewed source defines a query as a remote iPhone request, says it blocks until both stores converge, or exposes a general flag certifying that an arbitrary date interval has finished synchronizing. That is an unresolved public guarantee, not evidence that any particular month query will fail.

### 2. Watch history has a documented boundary, without a universal day count

`earliestPermittedSampleDate()` returns the platform boundary for reading and writing samples. Apple states: "Attempts to query samples before this date return samples after this date." It is systemwide and separate from the person's authorization choices. The framework overview directs developers to this API when determining the earliest samples available on watch. [earliestPermittedSampleDate, current documentation checked 2026-10-04](https://developer.apple.com/documentation/healthkit/hkhealthstore/earliestpermittedsampledate()), [HealthKit device stores](https://developer.apple.com/documentation/healthkit/about-the-healthkit-framework)

The independently inspected watchOS 27 Simulator SDK header confirms that samples before this date cannot be saved or queried, and that samples with newer end dates may be retrieved. This corroborates the sample constraint; it does not specify a separate historical-statistics retention policy. [Installed Apple SDK, HKHealthStore.h](/Applications/Xcode.app/Contents/Developer/Platforms/WatchSimulator.platform/Developer/SDKs/WatchSimulator27.0.sdk/System/Library/Frameworks/HealthKit.framework/Headers/HKHealthStore.h:130)

Compare the entire metric input window against this boundary. For Count.kcal, that includes the monthly chart's leading days and any preceding basal-energy days used by its calculations. A date within the boundary is eligible under this constraint; it is not proof that all expected sources have arrived or permission is unrestricted. The inspected documentation does not support a fixed seven-day, thirty-day, or other universal watch-retention promise.

Apple Developer Technical Support supplied more practical guidance in June 2024: "In general, Apple Watch keeps HealthKit data for about a week." The recommended reply identifies its author as Apple Staff and DTS Engineer Ziqiao Chen. It says some types remain longer, Apple has no complete retention list to share, and developers should test the types they need. This is dated first-party staff guidance about typical retention. It makes assuming a complete month unsafe, without proving every type has exactly seven days of availability. The reply does not distinguish raw-sample purging from statistics retention. A later June 2026 observation in the thread is from another developer, rather than Apple staff. [Apple DTS, HealthKit data history on watch, June 2024](https://developer.apple.com/forums/thread/732468)

Apple's original watch introduction described limited historical access. Current documentation and the runtime boundary provide the more useful implementation contract. The old statement supplies historical context, without establishing today's number of available days. [Apple-hosted WWDC15 HealthKit slides, page 71](https://devstreaming-cdn.apple.com/videos/wwdc/2015/203bxvbtrom9t1t/203/203_whats_new_in_healthkit.pdf)

### 3. Statistics are preferable to enumerating and adding raw quantities

`HKStatisticsQuery` calculates over matching quantity samples. `HKStatisticsCollectionQuery` groups those calculations into fixed intervals and supports updates. Apple describes daily steps and hourly averages as normal chart uses. `separateBySource` explicitly requests separate statistics per source. [HKStatisticsQuery](https://developer.apple.com/documentation/healthkit/hkstatisticsquery), [HKStatisticsCollectionQuery](https://developer.apple.com/documentation/healthkit/hkstatisticscollectionquery), [separateBySource](https://developer.apple.com/documentation/healthkit/hkstatisticsoptions/separatebysource)

WWDC20 demonstrates a step-count query ignoring overlapping iPhone steps and including iPhone steps recorded when the watch was absent. It is direct evidence that the statistics API handles that overlapping-source example. It does not establish a universal quality ranking or identical source rules for every quantity type. Calling the result "best available" should mean the authorized result for the chosen query, predicate, and options, rather than a promise that HealthKit always picks one best measurement. [Getting started with HealthKit, WWDC20, statistics demonstration](https://developer.apple.com/videos/play/wwdc2020/10664/)

Body mass is a discrete quantity. `averageQuantity()` returns the average of matching samples when `.discreteAverage` is requested. WWDC19 explains the discrete arithmetic mean and distinguishes it from temporally weighted heart-rate aggregation. A most-recent weight reading and a daily average answer different questions. Count.kcal's later mean of daily means is another application calculation, not an automatic HealthKit weekly-summary rule. [bodyMass](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/bodymass), [averageQuantity](https://developer.apple.com/documentation/healthkit/hkstatistics/averagequantity()), [Exploring new data representations in HealthKit, WWDC19](https://developer.apple.com/videos/play/wwdc2019/218/)

### 4. Condensed samples, watch purging, and activity summaries differ

HealthKit can condense older first-party workout samples into quantity series, then delete the original objects. Apple says condensation preserves workout data and statistical results. It recommends statistics queries to read the underlying values transparently. Listed types include active and basal energy. WWDC19 also explains that statistics collection queries automatically include backing quantity-series data. [Accessing condensed workout samples](https://developer.apple.com/documentation/healthkit/accessing-condensed-workout-samples), [Quantity series and statistics, WWDC19](https://developer.apple.com/videos/play/wwdc2019/218/)

This means the absence of the original objects is insufficient to diagnose missing totals. Conversely, the condensation documentation does not promise an unlimited historical statistics archive on watch, or a bypass of platform sample availability. No such general exemption was established by the reviewed sources. Actual availability of a specific older total must not be guessed from raw-object counts.

`HKActivitySummaryQuery` can read daily Move, exercise, and stand summaries over a date range. These are separate mutable summary objects, not `HKSample` subclasses. Their documented fields include active energy but not body mass, steps, dietary energy, or basal energy. They therefore cannot replace the queries for all Count.kcal metrics. A different summary data source also needs semantic comparison before replacing an existing active-energy query. The inspected sources do not guarantee unlimited historical watch retention for summaries. [HKActivitySummary](https://developer.apple.com/documentation/healthkit/hkactivitysummary), [Activity summary range queries](https://developer.apple.com/documentation/healthkit/executing-activity-summary-queries)

### 5. Completeness cannot be inferred from empty data

Read authorization is deliberately private. If the person denies read access, queries return only samples the app itself saved. An empty result therefore does not establish that the person recorded no data. Current authorization guidance also supports access limited to a recent window. [Authorizing access to health data](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data)

On iOS and watchOS 27, `earliestAuthorizedSampleDate(for:)` can identify a limited-access boundary per type. It evaluates sample end dates. The documentation says absent dictionary entries can mean full or denied access, and even limited access without a specific returned date. Availability checks are required on older app deployment targets. This method is separate from `earliestPermittedSampleDate()`. Neither boundary alone certifies synchronization completeness. [earliestAuthorizedSampleDate, current API availability and discussion checked 2026-10-04](https://developer.apple.com/documentation/healthkit/hkhealthstore/earliestauthorizedsampledate(for:))

Preserve query errors separately from successful empty results. Distinguish known unavailable history from an eligible interval with no readable samples. Do not label all gaps as purged or assume zero means a verified physiological total. How the UI displays a successful empty eligible day is an application policy that should match the iPhone.

### 6. Phone queries require app communication if the app needs a phone result

The reviewed HealthKit query APIs take a store, sample type, predicates, and statistics options. No companion-store selector or general remote historical query API was identified. HealthKit's automatic internal synchronization is distinct from an application asking its iPhone counterpart to execute a query. The absence of a documented selector does not exclude undocumented internal backfill behavior; it means that behavior is not an application-controlled completion contract.

Watch Connectivity supports the latter application request. An activated, active watch app can use `sendMessage` with reply and error handlers; Apple documents that it wakes the companion iOS app in the background. The method returns before asynchronous delivery. Reachability changes and missing replies can cause errors, so requesting a value is not a guarantee of receiving it. [sendMessage](https://developer.apple.com/documentation/watchconnectivity/wcsession/sendmessage(_:replyhandler:errorhandler:)), [messageReplyTimedOut](https://developer.apple.com/documentation/watchconnectivity/wcerror/code/messagereplytimedout)

Background activation does not unlock HealthKit. Ordinary reads on a locked phone can fail with `errorDatabaseInaccessible`. A previously captured result or an unavailable state is then appropriate. A fresh on-demand phone query cannot be promised for every watch request. [Locked HealthKit database](https://developer.apple.com/documentation/healthkit/hkerror/code/errordatabaseinaccessible)

`updateApplicationContext` transfers the latest property-list state opportunistically and replaces its previous dictionary. It can be submitted while the counterpart is unreachable. It suits a compact latest snapshot, but does not guarantee immediate delivery or retain an ordered archive of every historical request. [updateApplicationContext](https://developer.apple.com/documentation/watchconnectivity/wcsession/updateapplicationcontext(_:))

## Apple's guidance and the application decision

Apple recommends statistics collection queries for most quantity graphs and minimizing unnecessary raw-data queries. It recommends watch apps remain useful without the phone. Independent apps must obtain their own information; Watch Connectivity may optimize the experience when a companion is available, but cannot be their main data source. Current freshness guidance extends the practical concern to dependent apps away from their phone. [Synchronize health data with HealthKit, WWDC20](https://developer.apple.com/videos/play/wwdc2020/10184/), [Creating independent watchOS apps](https://developer.apple.com/documentation/watchos-apps/creating-independent-watchos-apps), [Keeping watchOS content up to date](https://developer.apple.com/documentation/watchos-apps/keeping-your-watchos-app-s-content-up-to-date)

Apple also explicitly supports Watch Connectivity for content available on one device. WWDC21 explains sharing a phone's latest content with its watch counterpart and recommends small request/reply messages. This makes a bounded historical supplement a supported communication use case. It does not turn it into a recommendation to make every health metric phone-dependent. [Data transfer on Apple Watch, WWDC21](https://developer.apple.com/videos/play/wwdc2021/10003/)

| Product promise | Minimum approach | What it can honestly guarantee |
| --- | --- | --- |
| Same metric meaning, using the watch's currently accessible data | Shared calculations plus direct sample/statistics queries on watch | Same formulas and windows; current readable local result. No immediate iPhone equality promise. |
| Weekly/monthly weight from the currently available watch store | Daily discrete-average collection and latest-weight query, with the iPhone's shared calculations | Requested chart and averages over accessible inputs. Respect known boundaries and missing samples. |
| Browse historical days currently readable on watch | Reuse selected-date HealthKit queries locally | Available local history, without new transport or a history database. |
| Show the exact iPhone result captured for a day/window | Transfer that small derived response with date, unit, calendar context, and capture time | Equality to that captured result, once delivered. It can become stale. |
| Include phone history outside watch coverage | Optional bounded request/reply, plus cache only if offline reuse is required | Phone-derived data when query and delivery succeed, or a previously captured result. Uncached offline history remains unavailable. |
| Always match the iPhone's current display instantly | No inspected API provides this unconditional promise | Must account for different capture times, synchronization, permissions, locking, and reachability. |

The recommended design for Count.kcal is shared direct HealthKit queries for every metric, with phone-derived summaries supplementing requested history outside known watch availability or providing a deliberately captured phone result. Current readings should remain useful without the phone. For the existing weekly/monthly weight feature, the already bounded phone payload can supply the longer window when local availability is restricted, rather than being the only way to read weight. Later date browsing can reuse the same selected-date calculations. Cache fetched summaries only to support offline reuse; do not replicate raw samples or add a custom source-merging engine. This is our application recommendation based on the requested behavior and the documented constraints. Apple does not prescribe this exact arrangement.

## First-party app behavior as a cross-check

Heart Analyzer's current developer press kit describes a standalone watch app, direct HealthKit reading, on-device processing, and no transmission of health data. Its version 11 announcement documents watch charts covering the past week. This is evidence that useful independent historical watch charts do not inherently require phone delivery. It does not establish universal month retention for all health types. [Heart Analyzer press kit, current version 12.7, September 2026](https://www.helixapps.co.uk/heart-analyzer-press), [Version 11 announcement, September 2024](https://www.helixapps.co.uk/blog/introducing-heart-analyzer-version-11)

AutoSleep documents a different pattern. Its watch calculates using locally captured health data until the unlocked iPhone finishes processing, then receives the phone's sleep result. It also displays its most recent phone synchronization time. This supports a mixed approach for that product's calculations, without proving that Count.kcal needs the same architecture. Public descriptions do not establish either app's exact historical cache or query implementation. [AutoSleep watch guide, checked 2026-10-04](https://autosleepapp.tantsissa.com/watch-use)

## Count.kcal audit and implementation

At the time of the research audit, calories used local watch statistics, while weight received only a phone-derived snapshot through application context. The shared weight semantics are daily averages, then rolling means over seven or thirty days, excluding missing days and using the existing rounding rules. The monthly chart starts on the Monday at or before the thirty-day lookback, resulting in a longer chart window. Latest weight remains a separate sample value. Formula sharing validates these meanings; it does not validate equality of independent device inputs. [Production HealthKit queries](/Users/berken/Development/Swift/Count.kcal/Count.kcal/Abstract/System/HealthKitDataSource.swift:10), [shared weight model](/Users/berken/Development/Swift/Count.kcal/Count.kcal/Abstract/WeightHistory.swift:69), [weight query windows](/Users/berken/Development/Swift/Count.kcal/Count.kcal/Abstract/System/HealthRepository.swift:125), [watch refresh and snapshot handling](/Users/berken/Development/Swift/Count.kcal/Count.kcal.watch/ContentView.swift:77)

The initial audit also found no watch coverage check or continuous HealthKit observer handling. Some query errors become empty dictionaries and subsequently zero values, and a count of calendar buckets is treated as loading evidence. Those facts make a "complete month" or "successfully updated" claim too strong. Error preservation and clear availability states should be addressed before using either local data or a phone supplement to make those claims. The implementation that followed this research now reads weight directly through the shared repository, refreshes while the watch is active through a body-mass observer, and preserves weight query errors. The existing phone snapshot supplies only calendar days before the reported local sample boundary, plus a latest measurement older than that boundary if no local measurement is available. It cannot replace successful recent local reads. Periods with restricted days lacking a supplement show "Limited history". A failed first local query can display the cached phone snapshot with a refresh error; later failures keep the previous result. These changes apply to weight; calorie error handling remains outside this change.

Meaningful parity tests need matching date boundaries, units, missing-data rules, and sample fixtures. Physical-device tests then establish actual behavior for the app's supported OS versions: compare the requested week/month with the returned platform boundary; query the same windows on both devices; test after new samples, historical edits, and delayed sync; test known restricted intervals and query failures. If phone delivery is selected, also test locked and disconnected phones and captured-result age. Simulator fixtures prove calculation semantics, not real-world retention or delivery timing.

Implementation validation on 2026-10-04 passed the shared-model semantics runner, iPhone Debug build, and watch Debug and Release builds. The signed watchOS 27 simulator successfully executed native body-mass statistics and latest-sample queries, displaying 79.7 kg weekly and 79.8 kg monthly. Its shorter month showed "Begrenzter Verlauf". Local fixtures displayed 79.8 kg weekly and 80.1 kg monthly, with Crown scrolling to the monthly chart and footer. Tests covered kg/lbs calculation parity, local precedence, deleted recent measurements, older phone supplementation, and query errors. The native observer's initial callback succeeded. Delivery after a newly saved measurement, physical-device retention, and synchronization timing were not exercised.

## Remaining unknowns

The reviewed public contract does not establish a fixed watch-retention duration, general unlimited historical statistics retention, a query-triggered remote backfill guarantee, or an all-sources synchronization-complete flag. Particular devices may return more historical data than a conservative assumption predicts. That should be measured, and never described as impossible merely because a guarantee was not found.

This report distinguishes documented behavior above from application recommendations and these unresolved guarantees. The current Apple articles were read through their official `.md` endpoints where HTML returned JavaScript placeholders. WWDC statements were read in Apple's own transcripts. Existing apps are corroborating product examples; they do not override Apple's API contract.

## Evidence confidence

| Finding | Evidence and confidence |
| --- | --- |
| Queries return a current store snapshot; HealthKit synchronizes separate device stores | High. Explicit current Apple documentation and WWDC descriptions. |
| Direct statistics queries suit watch charts and local historical browsing | High for API capability. Actual available input history remains device- and permission-dependent. |
| A sample boundary and old watch-data purging exist | High. Explicit current documentation. Apple DTS described typical retention of about a week in June 2024, with some types retained longer. This is not a universal day-count guarantee. |
| Quantity-series condensation preserves statistics | High for the documented condensation operation. It does not establish a watch-purging exemption. |
| Every health type selects sources identically | Unsupported. The step example and discrete-average API establish narrower behaviors. |
| A query guarantees immediate phone parity | Unsupported. December 2024 Apple DTS explicitly states that store synchronization is not real time. |
| A query guarantees remote historical backfill | Not established by the inspected public contract. Do not turn this into a categorical impossibility claim. |
| A compact phone response can preserve captured-result parity | Application inference supported by Watch Connectivity's documented communication mechanisms. Availability and freshness still require handling. |
| Calories must be local and weight must be phone-delivered | Unsupported as an Apple recommendation. This is one application choice, not an API rule. |
