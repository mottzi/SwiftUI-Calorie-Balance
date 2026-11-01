# Calorie-card sharing with CloudKit

Research date: 2026-10-23. Scope: private, ongoing sharing of Count.kcal's HealthKit-derived calorie card between known people. This report supplies the evidence behind the [agreed product specification](../calorie-card-sharing-spec.md) and investigates the remaining CloudKit validation questions. No production implementation changed.

## Answer

**CloudKit is technically capable of carrying this feature. Whether Apple permits the exact payload under its current published rules remains unresolved. A custom backend has not been selected or shown to be necessary.**

| Question | Finding | Evidence strength |
| --- | --- | --- |
| Can CloudKit persist a small daily card, grant access to another iCloud user, and synchronize changes? | Yes. Private records, `CKShare`, shared databases, and `CKSyncEngine` provide these mechanisms. | Direct API documentation. |
| Does the existing SQLiteData version support the relevant foundations? | Yes. Version 1.12.0 includes CloudKit sharing and encrypts scalar values through `CKRecord.encryptedValues`. | Pinned library source. |
| Does Apple support consented health and fitness sharing between people in principle? | Yes. Current developer guidance explicitly discusses such sharing and recommends end-to-end encryption. | Direct guidance, supported by Apple's HealthKit overview and developer case study. |
| Is this exact named, HealthKit-derived calorie card expressly permitted in third-party CloudKit storage? | Uncertain. The iCloud restriction is explicit, but the reviewed sources do not classify this exact nonclinical payload or explain the boundary consistently enough to resolve it. | Direct restriction, affirmative technical guidance, unresolved application to this payload. |
| Is this exact implementation proven prohibited? | No. No reviewed Apple answer directly decides this payload. That does not establish permission either. | Research limit. |

The technical findings follow from [Shared Records](https://developer.apple.com/documentation/cloudkit/shared-records), [CKSyncEngine](https://developer.apple.com/documentation/cloudkit/cksyncengine-4b4w9), and [SQLiteData's pinned CloudKit value encoding](https://github.com/pointfreeco/sqlite-data/blob/164bb5f223738af3d5da7a1b8de14e67e4d9cd5d/Sources/SQLiteData/CloudKit/CloudKit%2BStructuredQueries.swift). The permission question follows from the evidence examined below, especially [App Review 5.1.3](https://developer.apple.com/app-store/review/guidelines/#health-and-health-research) and Apple's [health and fitness guidance](https://developer.apple.com/health-fitness/).

The earlier suggestion to treat CloudKit as unavailable was too strong. Keep it as the preferred candidate while resolving the precise policy question. Do not present either encryption or a different server vendor as an automatic policy exemption.

## Agreed product context

These are decisions supplied by the user during the session, not claims about Apple APIs:

- Sharing is between mutually connected people, with multiple independent connections.
- Each pair has a symmetric scope. Today and the previous seven completed days are independent choices, including history without today.
- Day boundaries follow the sender's local day. After travel, successful recalculation republishes dates and values using the sender's current time zone. Recipients do not regroup values using their own calendars. Show the sender's date and identify the time zone when it differs.
- Either person can reduce that pair's scope. Expanding it requires the other person's acceptance.
- The recipient sees the sender's last successfully published card and its timestamp. Continuous live equality is not required.
- Sharing covers the calorie card, including Now and Midnight for today. The recipient sees the sender's values, units, colors, and goal-status visibility independently of the recipient's app preferences. A native card adapts its layout, text size, VoiceOver, and reduced motion to the recipient's device.
- Historical cards show recorded totals without a Midnight projection or mode switch. They update when the sender recalculates and publishes corrections.
- Accepting historical sharing makes the previous seven completed days available, including dates before the connection.
- Apple's standard CloudKit protection is sufficient for the product requirement. Unconditional end-to-end encryption and mandatory Advanced Data Protection are not product requirements. This choice does not resolve Apple's classification of the payload under its published rules.
- New invitations propose Today only by default; the inviter can also propose history. The recipient explicitly accepts mutual sharing. Invitation previews show identity and scope, with calorie data available only after mutual agreement.
- Turning both scopes off pauses the connection. Resuming a scope requires the other person's acceptance. Remove connection ends the relationship for both people; reconnecting requires a fresh invitation.
- Recipients do not accumulate a permanent archive in Count.kcal. The app displays and caches cards only within the currently permitted date window and removes affected cards when they expire or when it learns of a scope reduction or disconnection. The user accepts eventual cloud cleanup rather than an exact server-access deadline. Expired cloud copies may remain retrievable until cleanup, and the sharing disclosure must explain this.
- Cached cards remain available offline within the permitted date window and show their last update time. Offline reductions stop local publication immediately and remain visibly pending until the server confirms the change. The app does not claim that remote access has already been revoked.
- The card is substantially HealthKit-derived, including dietary energy and the usual burn inputs. A custom energy source can supply part of the existing card. Raw samples, sample-source identifiers, detailed meals, and full HealthKit history are unnecessary for reproducing its numbers.
- CloudKit and the existing SQLiteData library are strongly preferred. A custom backend is only a candidate if the Apple-based approach cannot satisfy the requirements.
- The dashboard toolbar stays unchanged. A Sharing button below the Progress card opens a dedicated screen. It uses Apple's overview-to-detail pattern, with alphabetically sorted compact person summaries, a full card on the person's detail screen, and permitted date browsing. Today uses the Now summary; history-only connections show a dated historical summary. Bob may switch Alice's published Now and Midnight values independently of her selected mode. Highlights, messaging, rankings, and competitions are outside v1.
- Invitations address a specific known person through Apple's sharing flow, using Messages or Mail. There is no public user directory.
- On first use, the sender confirms an app display name. The app uses an initials avatar and does not require Contacts access. A display name is not verified identity; the invitation must identify the intended account.
- Publication happens automatically after successful relevant data refreshes and appearance changes, with background work when iOS permits it. A recipient's refresh fetches the latest published card and cannot force a fresh HealthKit reading on the sender's phone. Failed reads retain the previous card rather than publishing zeroes.
- Optional notifications cover invitations and requests to expand sharing. Other connection changes appear inside Sharing. Calorie updates stay quiet, and notifications contain no calorie values.
- If the sender's day changes before a new card is published, show "Waiting for today's update." Yesterday is accessible only when history sharing permits it, and is never relabeled as today.
- Invitations and expansion requests expire after seven days. The sender can cancel, and the recipient can decline without an explanation. There are no automatic reminders. Existing sharing continues during an expansion request. A reduction invalidates pending expansion requests.
- One designated iPhone per Apple Account publishes cards. A replacement phone requires explicit takeover, after which the old phone must stop publishing. Sharing is iPhone-only in v1, with no simultaneous publishers, iPad, or Watch sharing.
- A confirmed iCloud sign-out or account switch stops publication and clears received cards and connection credentials for that account from the device. Connections never transfer to a different account. Returning to the same account restores only server-verified relationships and publishing authority. Ordinary Count.kcal data stays independent. Temporary account or network failures preserve the permitted offline cache. Sign-out itself does not revoke existing cloud shares.

The specification defines the disclosure limits, eventual cleanup guarantee, and pending-connection behavior. Exact field encoding and protocol implementation still need technical validation. Resolved per-mode components and status can reproduce today's card without uploading weight, macros, steps, goal thresholds, full Settings, or the resting-energy history used in its calculation. The report uses "card" to mean the data needed to reproduce the sender's captured display, not a copy of their HealthKit database.

## What supports the proposed use

Apple's current health and fitness developer page specifically recommends on-device processing and end-to-end encryption where possible. Its example is a person sharing health data with other people. The same page directs developers to comply with App Review 5.1.3. This supports the feature's purpose, while leaving the storage restriction relevant. [Health and fitness apps](https://developer.apple.com/health-fitness/)

The HealthKit framework overview includes social interactions among the tasks a health and fitness app may provide. It describes apps focusing on different parts of an experience, including health challenges. Consequently, interpreting HealthKit's third-party-disclosure rules as a categorical ban on all friend sharing would conflict with Apple's own public guidance. This is an interpretation across those sources, not approval of Count.kcal's transport. [HealthKit overview](https://developer.apple.com/documentation/healthkit)

Apple's CloudKit encryption guide names "Photos, Notes, Health, Home" as examples when explaining encrypted fields in CloudKit-based apps. It expressly supports encrypted values in private and shared databases. This is substantial evidence against claiming that CloudKit cannot technically carry health-related information. However, the examples are Apple app names. The guide does not say which third-party health payloads qualify under 5.1.3 or explicitly waive that rule. [Encrypting User Data](https://developer.apple.com/documentation/cloudkit/encrypting-user-data)

Apple's developer story about Any Distance describes HealthKit integration, a social network for a small circle of friends, and storage when people post data to friends. This is affirmative evidence for a third-party HealthKit social feature. The article does not identify CloudKit as its social backend or grant other apps an exception. [Behind the Design: Any Distance](https://developer.apple.com/news/?id=uiiopcl8)

WWDC20 also demonstrates sending daily cumulative step statistics to an external server for a physical therapist, then updating only affected days. This directly supports synchronizing derived HealthKit summaries outside the store for an appropriate purpose. The example names local SQLite/Core Data and a remote server, not CloudKit. [Synchronize health data with HealthKit](https://developer.apple.com/videos/play/wwdc2020/10184/)

These sources mean the proposed social purpose is supported. They do not settle the exact storage question by themselves.

### Third-party implementation claims

Other developers publicly describe related uses. These deserve attention, but their own descriptions are evidence of claimed implementation rather than Apple policy rulings:

- Health Auto Export's privacy policy, updated 2026-02-08, says it reads Apple Health and uses iCloud Drive for user-selected exports, automatic backups, and Auto Sync. This is a concrete example of a developer describing health-data storage in iCloud. It is not evidence about `CKShare`, and its security claims were not independently audited. [Developer's privacy policy](https://www.healthyapps.dev/health-auto-export/privacy-policy/)
- LiftLogic's policy, updated 2026-09-24, identifies a private CloudKit database for training data in section 7.1. Section 15.3 says HealthKit data sent to the person's other devices travels through their own iCloud account. Together these are a closer CloudKit precedent, although the policy does not map each HealthKit value to a CloudKit record or describe friend sharing. [Developer's privacy policy](https://liftlogic.fit/privacy/)

These examples make an assertion that third-party health-related iCloud use never occurs indefensible. They do not reveal App Review's correspondence, any special permission, or whether the shipped binaries exactly match the policies. They therefore cannot grant permission for Count.kcal.

## What the restrictions actually say

### App Review and the developer agreement

App Review 5.1.3(ii) says apps "may not store personal health information in iCloud." The surrounding section covers health, fitness, and medical data. The sentence does not define personal health information, distinguish raw samples from calculated daily values, or state an exception for private databases, user consent, or encrypted fields. [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/#health-and-health-research)

The Developer Program License uses a different formulation in 3.3.3(D). It restricts sensitive, individually identifiable health information through Apple software or services, expressly including iCloud and CloudKit, unless Apple permits it in writing. HIPAA protected health information is an included category, not the only category stated. Section 3.3.3(H) separately requires a health or fitness purpose, express consent to third-party disclosure, and disclosure only for the stated permitted services. The inspected agreement does not classify named calorie aggregates or provide an encryption exception for them. [Apple Developer Program License Agreement, 3.3.3(D) and 3.3.3(H)](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/)

HealthKit's privacy guide repeats the express-consent and health-or-fitness-service conditions and directs developers to the review rules and agreement. Therefore, HealthKit read permission is not sufficient evidence that the person consented to ongoing publication to a friend. The specific sharing scope needs its own clear consent. [Protecting user privacy](https://developer.apple.com/documentation/healthkit/protecting-user-privacy)

The unresolved point is how Apple applies those terms to this consumer fitness payload. The documents support neither a confident statement that every HealthKit-derived number is prohibited in CloudKit nor a confident statement that nonclinical daily aggregates are exempt.

### Personal health information is not automatically HIPAA PHI

HHS explains that HIPAA PHI concerns individually identifiable health information held or transmitted by covered entities or their business associates. It also explains that information in consumer apps offered independently of those regulated entities generally falls outside HIPAA's protections. Count.kcal's ordinary consumer context therefore should not be described as automatically handling HIPAA PHI merely because it reads HealthKit. This is a distinction between terms, not a determination of the app's legal status. [HHS: Consumer health information](https://www.hhs.gov/hipaa/for-professionals/special-topics/hipaa-ftc-act/index.html), [HHS: Mobile apps and regulated entities](https://www.hhs.gov/hipaa/for-professionals/privacy/guidance/hipaa-online-tracking/index.html)

Apple's review rule uses personal health information, while its agreement says sensitive individually identifiable information and includes the separate HIPAA category. It would be unsupported to substitute "HIPAA PHI only" for either Apple phrase. Conversely, the general term does not give us an official classification of a nonclinical calorie card. That classification is the question to put to Apple.

Apple's privacy-label taxonomy includes HealthKit information under Health and also has a Fitness category. It says information derived on device and transmitted off device must be considered separately. These are disclosure categories, not exceptions to the iCloud restriction. They do not establish that calling the card fitness data makes it exempt. [App privacy details](https://developer.apple.com/app-store/app-privacy-details/)

### Why the exact payload matters

The proposed data is minimized, but intentionally attributable to a known sender. A total over one person's day is an aggregate over time, not an anonymous population statistic. Removing raw samples reduces detail without removing the recipient's ability to associate the values with that person. This is a property of the agreed product design.

The Now/Midnight values and goal status may also communicate inferred information. They should be included in the description to Apple rather than described only as anonymous statistics or harmless progress. No reviewed source explicitly exempts these transformations.

Independently entered nutrition data would have different provenance from information obtained through HealthKit. However, the review restriction is expressed in terms of the information, not solely its source. Switching the source of an otherwise identical card would not by itself settle the question. The current design is HealthKit-derived, so a hypothetical manually entered alternative is not a reason to skip the relevant HealthKit conditions.

### The closest Apple response leaves the question open

An Apple Developer Forums question asks whether encrypted, per-user private CloudKit storage of health information is allowed under 5.1.3(ii), including whether encryption changes the rule. The verified App Review response directs the developer to a one-on-one App Review consultation. It neither grants an exception nor confirms a blanket ban. The page was checked during this research; its relative dates are not used as a precise publication date. [Apple App Review response, thread 838493](https://developer.apple.com/forums/thread/838493)

This is useful evidence about the available clarification route. It is not a substantive policy ruling.

## Encryption changes protection, not the documented permission by itself

Current `CKRecord.encryptedValues` documentation says CloudKit encrypts the selected fields on device and decrypts them after fetching. It now conditions exclusive availability of the keys to the owner and share participants on Advanced Data Protection. Encrypted fields cannot be queried through server indexes. References remain visible to the server, and assets have their own encryption handling. [encryptedValues](https://developer.apple.com/documentation/cloudkit/ckrecord/encryptedvalues)

Apple's security overview distinguishes standard iCloud protection from Advanced Data Protection. Third-party CloudKit encrypted fields and assets gain end-to-end protection with Advanced Data Protection. Its sharing discussion also describes participant and sharing-mode conditions, including limitations for anyone-with-the-link sharing. An app should not claim that any private `CKShare` is unconditionally end-to-end encrypted for every account. [iCloud data security overview](https://support.apple.com/en-us/102651)

The platform security guide explains why the distinction exists. CloudKit service keys can be either end-to-end protected or available after authentication. The latter can be accessed by Apple services. The presence of encryption before upload therefore does not, by itself, establish that Apple can never access the content. [iCloud encryption](https://support.apple.com/guide/security/icloud-encryption-sec3cac31735/web)

Apple's WWDC25 privacy session also explicitly ties CloudKit end-to-end encryption to the person's Advanced Data Protection setting and use of encrypted schema fields. The current documentation's qualifier is therefore corroborated by separate developer guidance. [Integrate privacy into your development process, 13:07](https://developer.apple.com/videos/play/wwdc2025/246/?time=787)

SQLiteData 1.12.0 already supplies relevant field encryption. At pinned revision `164bb5f223738af3d5da7a1b8de14e67e4d9cd5d`, `setValue` writes scalar fields and associated timestamps into `CKRecord.encryptedValues`. The row encoder routes Boolean, numeric, date, text, and UUID values through it; binary values use `CKAsset`. The proposed numeric card does not require inventing a separate field-encryption layer just to use that mechanism. This finding concerns the library's CloudKit encoding, not encryption of every local SQLite file or a guarantee of end-to-end protection under every account setting. [Pinned CloudKit encoding source](https://github.com/pointfreeco/sqlite-data/blob/164bb5f223738af3d5da7a1b8de14e67e4d9cd5d/Sources/SQLiteData/CloudKit/CloudKit%2BStructuredQueries.swift)

None of the policy sources reviewed says encryption creates an exception to the health-information restriction. Application-controlled encryption could offer a different protection model, but would introduce key distribution, recovery, device enrollment, and revocation design. It still places ciphertext representing the card in CloudKit, and no reviewed Apple ruling says that makes the storage permitted. This remains a question for Apple rather than an assumed workaround.

## What Apple's own sharing proves

Apple's Health app shares health information between people through end-to-end encrypted iCloud transport. Its security documentation also identifies CloudKit as the synchronization mechanism for Medical ID. This establishes that Apple's infrastructure can support protected health sharing. It does not identify a public entitlement allowing any third-party container to inherit the Health app's service configuration or policy treatment. [Protecting access to health data](https://support.apple.com/guide/security/protecting-access-to-users-health-data-sec88be9900f/web)

Apple's Activity Sharing privacy notice says the service sends selected workout and activity information to Apple for sharing and retains it for a short time. It describes end-to-end encryption when both sides use the specified newer operating systems, and exposure of Apple Account email addresses between invitees. The same notice does not document Activity Sharing as a general third-party storage API. [Activity Sharing & Privacy](https://www.apple.com/legal/privacy/data/en/activity-sharing/)

The public HealthKit reading APIs operate on the user's HealthKit store. No public API for reusing a Fitness friend connection to exchange Count.kcal's custom card, or for querying an arbitrary friend's store, was found in the reviewed documentation. This is a bounded search finding, not a claim about Apple's internal implementation. [Reading data from HealthKit](https://developer.apple.com/documentation/healthkit/reading-data-from-healthkit), [HealthKit API overview](https://developer.apple.com/documentation/healthkit)

### Fitness interface reference

Apple's current iPhone guide and official screenshot show a dedicated Sharing tab. A Highlights carousel sits above compact Activity Rings cards. Each person's card shows an avatar, name, Move percentage, current and goal energy, and small rings. The overview has a person-plus button and a sort control labeled Name. Tapping someone opens their last seven days of rings and recent workouts or meditations. The guide does not show the exact detail-screen layout or date-selection gesture. The inspected iOS 26 screenshot has the same broad overview structure. [Current iPhone guide](https://support.apple.com/guide/iphone/share-your-activity-iph0b826155d/ios), [official screenshot](https://ipcdn-web.apple.com/assets/v2/web/4a3c9962-c4f6-49b0-92e7-fa482b825340), [iOS 26 guide](https://support.apple.com/en-euro/guide/iphone/iph0b826155d/26/ios/26)

The iPhone guide supports invitations by contact, phone number, or email. Pending outgoing invitations can be sent again or deleted. A person's More menu includes notification controls, hiding activity, and removing the friend. These are facts about Fitness, not decisions to copy its relationship semantics. The reviewed current sources do not establish a Fitness-specific Block command or all consequences of hiding activity. Competitions require a separate invitation and acceptance. [iPhone sharing guide](https://support.apple.com/guide/iphone/share-your-activity-iph0b826155d/ios), [Apple Watch sharing guide](https://support.apple.com/guide/watch/share-your-activity-apd68a69f5c7/watchos)

The accepted Count.kcal adaptation is an overview of compact person summaries followed by a detail screen with that person's full calorie card and permitted history. The dashboard entry remains the user's chosen Sharing button below Progress. Fitness's Highlights, messaging, competitions, and broader disclosure scope are outside this adaptation.

## Technical design implications if CloudKit is permitted

CloudKit stores shared records in the owner's private database and exposes the permitted records through the participant's shared database. A hierarchy shares a root and its descendants; a zone share includes the zone's records. One record can belong to only one share. SQLiteData's documented sharing support can build on this instead of replacing local persistence. [Shared Records](https://developer.apple.com/documentation/cloudkit/shared-records), [SQLiteData sharing documentation at the pinned revision](https://github.com/pointfreeco/sqlite-data/blob/164bb5f223738af3d5da7a1b8de14e67e4d9cd5d/Sources/SQLiteData/Documentation.docc/Articles/CloudKitSharing.md)

The following are proposed architecture consequences, not finalized schema decisions:

1. Keep raw HealthKit data and unrelated app tables outside the shared data set. Publish a bounded card representation.
2. Give each pair its own outgoing data set under each sender's ownership. Independent pair scopes cannot safely be implemented by giving everyone access to one broad history and filtering the UI.
3. Give recipients read-only access to the other person's published card. A read-write participant can modify or delete shared records, so one writable table containing both people's authoritative cards would not enforce sender ownership.
4. Model mutual consent separately from CloudKit participation. The pair has one agreed scope, but the two directions have different owners. A pending or confirmed protocol must reconcile reductions and accepted expansions without publishing outside the currently accepted scope.
5. Keep published values, calculation-version information if needed, source day, and capture timestamp together. The recipient must not recompute the sender's card using their own goals or current clock.

The ownership and permissions reasoning is based on [CKShare](https://developer.apple.com/documentation/cloudkit/ckshare). CloudKit record modification atomicity is limited to a single zone; it does not give two users' private databases one atomic bidirectional consent transaction. The protocol must represent incomplete propagation rather than promising simultaneous server changes. [isAtomic](https://developer.apple.com/documentation/cloudkit/ckmodifyrecordsoperation/isatomic)

A stale offline write must not restore consent that either person reduced. Ordinary last-writer-wins Boolean synchronization is not sufficient proof of that behavior. A candidate design would associate an expansion proposal with its exact scope and consent revision, and invalidate older proposals after a reduction. This is a design constraint to prove, not a decision to build a particular protocol now. Published Now/Midnight values likewise need to remain one consistent captured version.

Scope reduction must affect what remains published or accessible, not only what the app draws. A historical record already granted to a recipient remains a disclosure even when hidden by a date filter. No automatic record-expiration mechanism was established by the reviewed APIs. Expiration, deletion, and retry behavior need validation before promising a strict seven-day server-retention boundary. Client-provided expiration metadata alone is not an authorization boundary.

`CKSyncEngine` can synchronize private and shared databases through separate engines. Its automatic schedule depends on system conditions, and explicit fetch and send operations support foreground refresh. Background notifications are not guaranteed. These facts match the accepted last-published-card semantics, but require a visible timestamp and a stale state. [CKSyncEngine](https://developer.apple.com/documentation/cloudkit/cksyncengine-4b4w9), [Background notifications](https://developer.apple.com/documentation/usernotifications/pushing-background-updates-to-your-app)

HealthKit read failures and unavailable data must not silently become newly published zeroes. An ordinary read can fail while the device is locked, and denied read access can look like missing data. A failed refresh should preserve the previous successfully published card or publish a deliberately defined unavailable state. [HealthKit privacy](https://developer.apple.com/documentation/healthkit/protecting-user-privacy), [HealthKit read authorization](https://developer.apple.com/documentation/healthkit/hkhealthstore/authorizationstatus(for:))

The owner can remove a participant or stop a share, and a recipient can leave. The app must handle local cache removal when it learns of the change. Server revocation cannot retroactively erase a screenshot or information already downloaded, and an offline device cannot learn of a new revocation immediately. These are delivery and disclosure limits, not reasons to promise weaker controls over future publication. [Share participants](https://developer.apple.com/documentation/cloudkit/ckshare/participant)

### Independent reductions while the other phone is offline

Apple documents leaving a share by deleting its `CKShare` record from the participant's shared database. This removes that participant without deleting the owner's original data. A read-only participant must delete the share record, not the root or calorie records. The owner can revoke their outgoing hierarchy share by deleting its `CKShare` from the private database. Neither operation requires the counterpart's app to run. [Shared records](https://developer.apple.com/documentation/cloudkit/shared-records), [CKShare](https://developer.apple.com/documentation/cloudkit/ckshare), [deleteRecord](https://developer.apple.com/documentation/cloudkit/ckdatabase/deleterecord(withid:))

Because permissions cover a hierarchy, Today and History should use separate shares in each direction. If Alice turns off History, her phone deletes her outgoing History share and leaves Bob's incoming History share. Their Today shares remain intact. This requires up to four calorie shares per pair, plus setup or control sharing. It is a design inference from the documented permission model, and needs a two-account test with the pinned library.

The two deletions cannot form one atomic cross-account transaction. Record each success, retry the remaining operation, and show the reduction as pending until both server operations succeed. Server confirmation does not prove every offline device has erased its cache. CloudKit share saves require an unchanged change tag; conflict recovery must not recreate revoked shares from obsolete consent. [Atomicity](https://developer.apple.com/documentation/cloudkit/ckmodifyrecordsoperation/isatomic), [share save policy](https://developer.apple.com/documentation/cloudkit/ckmodifyrecordsoperation/recordsavepolicy/ifserverrecordunchanged)

SQLiteData 1.12.0 exposes share metadata but has no public general-purpose participant-departure convenience in the inspected source. Its SQL delete triggers enforce record write permission, so deleting a read-only local row is not the departure operation. A narrow CloudKit coordinator should perform share deletions and reconcile the local mirror. Cleanup when another accepted hierarchy remains in the same owner's zone needs verification. [Sharing implementation](https://github.com/pointfreeco/sqlite-data/blob/164bb5f223738af3d5da7a1b8de14e67e4d9cd5d/Sources/SQLiteData/CloudKit/CloudKitSharing.swift), [delete triggers](https://github.com/pointfreeco/sqlite-data/blob/164bb5f223738af3d5da7a1b8de14e67e4d9cd5d/Sources/SQLiteData/CloudKit/Internal/Triggers.swift)

The rolling date window has a different limit. No scheduled share expiration or record TTL was found in the reviewed public APIs. Date filters and an `expiresAt` field affect app behavior, not permission to fetch a known record ID. If no capable device performs cleanup, an old cloud record can remain accessible beyond seven days, or beyond midnight for Today-only sharing. The user accepts an app display/cache window with eventual cloud cleanup and disclosure of that limit. A strict server-access deadline is not part of the agreed requirement. [Queries](https://developer.apple.com/documentation/cloudkit/ckquery), [direct fetching](https://developer.apple.com/documentation/cloudkit/ckdatabase/record(for:))

### One visible invitation with reciprocal feeds

The public APIs support resolving a share participant from a CloudKit user record ID, fetching share metadata, and accepting a share programmatically. These pieces make a single user-visible mutual invitation plausible. They do not yet prove the complete two-account experience, including system prompts and recovery. [shareParticipant](https://developer.apple.com/documentation/cloudkit/ckcontainer/shareparticipant(foruserrecordid:)), [shareMetadata](https://developer.apple.com/documentation/cloudkit/ckcontainer/sharemetadata(for:)), [accept](https://developer.apple.com/documentation/cloudkit/ckcontainer/accept(_:completionhandler:)-949ea)

A candidate protocol starts with a metadata-only shared hierarchy for exchanging setup information. After explicit mutual consent, each person creates separate outgoing card hierarchies for each permitted scope, with read-only access for the other account. The apps exchange and validate those share references, then accept them programmatically. The writable setup hierarchy cannot serve as authoritative evidence that the other person consented, because either participant can edit it. Authoritative consent needs owner-controlled records and verified CloudKit identity. This remains a candidate to validate.

The two-account experiment must verify identity lookup without Contacts access, the availability of account identifiers in share metadata, system prompts, read-only enforcement, interruption recovery, and stale consent writes. It must also verify that no card appears before both directions are ready and the scope is accepted. SQLiteData's pinned sharing implementation supports root-record hierarchies and programmatic acceptance, but does not itself prove this application protocol. [Pinned sharing documentation](https://raw.githubusercontent.com/pointfreeco/sqlite-data/1.12.0/Sources/SQLiteData/Documentation.docc/Articles/CloudKitSharing.md)

## Testing on simulators and devices

Apple's CloudKit setup guide supports signing into iCloud separately on each simulator and accessing private and shared databases. Apple's sharing sample also supports creating a share in Simulator. Two simulator instances signed into different accounts are a suitable first integration setup. The exact invitation-link routing, cold launch, and reciprocal acceptance flow still need an experiment on the selected runtime. A simulator and a physical iPhone can also participate in the same integration test. [CloudKit setup](https://developer.apple.com/documentation/cloudkit/enabling-cloudkit-in-your-app), [Apple sharing sample](https://github.com/apple/sample-cloudkit-sharing)

Live sharing requires ordinary Apple Accounts with iCloud enabled. Apple DTS explicitly confirmed in February 2026 that App Store Connect Sandbox Apple Accounts do not work for `CKShare`. Dedicated test accounts may use entirely synthetic calorie snapshots; testing does not require real personal health data. The accounts representing Alice and Bob are separate from the project's Apple Developer membership and code-signing setup. [Apple DTS account guidance](https://developer.apple.com/forums/thread/815455)

| Test layer | Environment | Purpose |
| --- | --- | --- |
| Deterministic protocol tests | Isolated SQLite stores, fake clock, injected health data and transport; no iCloud account | Consent generations, midnight and DST, exact snapshots, failure handling, retries, and reordered messages. |
| UI and local integration | Simulator with fixtures; no iCloud account | Navigation, mirrored cards, permission controls, pending/error states, and accessibility. |
| Live cloud integration | Two simulators with different ordinary Apple Accounts, or a simulator and an iPhone | Real private/shared databases, invitation acceptance, server identity, read-only enforcement, and revocation. |
| Hardware checks | Preferably two iPhones with different accounts | Background HealthKit, protected-data behavior, actual invitation handoff, suspension, and automatic synchronization. |
| Release smoke test | TestFlight on devices with controlled test accounts | Deployed production schema, release entitlements, and production CloudKit access. |

The test layers are the proposed verification strategy. Simulator support does not make a fake service evidence of Apple's access controls, and a successful foreground sync does not establish background delivery.

The pinned SQLiteData guidance says simulators do not support push notifications. Apple's Xcode 14 release notes introduced actual APNs sandbox support for iOS 16 simulators on compatible Macs, so that blanket restriction is outdated. This does not establish identical CloudKit background behavior on every runtime. Use explicit fetch and send operations to verify foreground integration first, then test automatic delivery separately. `CKSyncEngine` describes its automatic schedule as indeterminate and supports separate engines for private and shared databases. [Xcode 14 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-14-release-notes), [pinned simulator guidance](https://github.com/pointfreeco/sqlite-data/blob/164bb5f223738af3d5da7a1b8de14e67e4d9cd5d/Sources/SQLiteData/Documentation.docc/Articles/CloudKitSync.md#developing-in-the-simulator), [CKSyncEngine](https://developer.apple.com/documentation/cloudkit/cksyncengine-5sie5)

HealthKit background observer queries explicitly require physical devices. Its protected database can also be inaccessible while the device is locked. Test that an unsuccessful read leaves the old published card intact rather than sending zeroes. Synthetic samples can exercise foreground HealthKit queries on supported simulators, but do not reproduce those hardware conditions. [Observer queries](https://developer.apple.com/documentation/healthkit/executing-observer-queries), [database inaccessible error](https://developer.apple.com/documentation/healthkit/hkerror/errordatabaseinaccessible), [saving samples](https://developer.apple.com/documentation/healthkit/saving-data-to-healthkit)

Count.kcal already has a [HealthDataSource interface](../../Count.kcal/Abstract/System/HealthDataSource.swift), a [synthetic source](../../Count.kcal/Development/SampleHealthDataSource.swift) with controlled time and simulated failures, a [simulator-only HealthKit seeder](../../Count.kcal/Development/SimulatorHealthSeeder.swift), and [tests with controlled sources](../../Count.kcalTests/HealthLoadingTests.swift). [AppDatabase](../../Count.kcal/Persistence/AppDatabase.swift) can create an in-memory SQLite database. These are existing test facilities, not newly implemented sharing tests.

SQLiteData 1.12.0 also selects mock cloud databases and engines in its non-live dependency context. Tests and previews can therefore avoid iCloud accounts. The real integration app must use live dependencies, and its tests must verify actual server permissions separately. [Pinned SyncEngine source](https://github.com/pointfreeco/sqlite-data/blob/164bb5f223738af3d5da7a1b8de14e67e4d9cd5d/Sources/SQLiteData/CloudKit/SyncEngine.swift), [testing and preview guidance](https://github.com/pointfreeco/sqlite-data/blob/164bb5f223738af3d5da7a1b8de14e67e4d9cd5d/Sources/SQLiteData/Documentation.docc/Articles/CloudKitSync.md#unit-testing-and-xcode-previews)

Early cloud tests use the development environment. Schema deployment copies types, fields, and indexes rather than test records. TestFlight uses production CloudKit and therefore needs a separate smoke test after schema deployment. The development environment still talks to Apple's servers; it is not a local emulator. [Schema deployment](https://developer.apple.com/documentation/cloudkit/deploying-an-icloud-container-s-schema), [Apple DTS distribution guidance](https://developer.apple.com/forums/thread/842909)

## Whether a metadata-only CloudKit split helps

Using CloudKit only for connection identifiers and consent state would avoid storing the calorie payload there. That is a meaningful separation of data categories, but it does not deliver the feature by itself. The exact card must still reach the recipient through another transport, and asynchronous retrieval while the sender is unavailable requires somewhere to retain it. These are architecture consequences of the requested behavior.

Putting an encrypted card, image of the card, goal-result label, or a reconstructable substitute in a supposedly metadata-only record would still move the substance of the card into CloudKit. Calling it metadata does not answer the permission question. A friend graph and sharing preferences can themselves disclose relationships, so even a true metadata-only design needs a stated scope and retention policy.

If Apple rejects the exact CloudKit payload, possible next investigations are a separately permitted hosted service, a materially different device-to-device experience, or explicit one-time exports. None is selected. A separate host changes infrastructure and responsibilities; it does not remove HealthKit consent and purpose requirements. A one-time export also does not satisfy the current ongoing, mutually controlled feature without changing the product scope.

## The clarification that would settle the decision

The useful request is about this exact design, including the fact that it uses the shared database, not only private synchronization. The following is a draft for an App Review consultation or written clarification. It has not been sent.

> Count.kcal is a consumer fitness app. With explicit, revocable consent, two known users want to exchange a daily calorie card. The usual card is calculated on device from authorized HealthKit active energy, resting energy, and dietary energy; a user-selected custom energy source can replace part of the burn calculation. The proposed payload contains daily totals, their active/resting components, calorie deficit or surplus, and the app's Now/Midnight goal-status display, plus the day and publication timestamp. It does not contain raw samples, clinical records, detailed food logs, body measurements, routes, or advertising identifiers.
>
> Each pair accepts a shared scope of today, the previous seven completed days, or both. Either person can reduce the scope. Expansion needs renewed acceptance. Each sender would own a separate private CloudKit record hierarchy and grant only the other person read-only access with CKShare. The app would use encryptedValues through SQLiteData and would not create public shares or use the data for advertising, profiling, or resale.
>
> Does App Review 5.1.3(ii) permit this exact nonclinical, HealthKit-derived payload in private and shared CloudKit databases? Does Apple classify these named daily fitness/nutrition aggregates as personal health information for that rule, and does 3.3.3(D) require written permission for them? If there are permitted conditions, please identify whether ordinary CloudKit encrypted fields suffice, Advanced Data Protection must be enabled for both users, or another protection mechanism is required. Please also confirm that this mutually consented fitness-accountability purpose satisfies 3.3.3(H), and distinguish any different treatment of independently entered nutrition data.

If the response permits the design, record the exact conditions and confirm the technical implementation can enforce them. If it rejects it, ask which specific field, source, relationship, storage mechanism, or protection condition makes it unacceptable before replacing the architecture. A general answer about secure storage, an unrelated approved app, or successful API calls would not resolve the classification question.

## Evidence limits and remaining work

The research prioritizes current Apple documentation, agreement text, App Review guidance, verified Apple staff responses, HHS definitions, and the exact pinned library source. Apple developer stories establish their described use cases, not backend details they omit. Search results and unanswered forum questions were not treated as permission. Current documentation takes precedence over older descriptions of encryption behavior.

| Source category | What it establishes | What it does not establish |
| --- | --- | --- |
| [App Review rules](https://developer.apple.com/app-store/review/guidelines/#health-and-health-research) and [developer agreement](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/) | Published conditions. | A ruling on this exact card's classification. |
| [Health developer guidance](https://developer.apple.com/health-fitness/) and [CloudKit encryption guide](https://developer.apple.com/documentation/cloudkit/encrypting-user-data) | Supported purposes and protection mechanisms. | A stated exemption from every other condition. |
| [Current encryptedValues contract](https://developer.apple.com/documentation/cloudkit/ckrecord/encryptedvalues) and [WWDC25 privacy session](https://developer.apple.com/videos/play/wwdc2025/246/?time=787) | Current encryption behavior and ADP qualification. | Unconditional end-to-end encryption for all participants. |
| [Apple App Review forum response](https://developer.apple.com/forums/thread/838493) | Official route for clarification of this ambiguity. | Permission or rejection. |
| [HHS guidance](https://www.hhs.gov/hipaa/for-professionals/special-topics/hipaa-ftc-act/index.html) | Meaning and scope of HIPAA PHI. | The intended scope of Apple's different wording. |
| [Pinned SQLiteData implementation](https://github.com/pointfreeco/sqlite-data/blob/164bb5f223738af3d5da7a1b8de14e67e4d9cd5d/Sources/SQLiteData/CloudKit/CloudKit%2BStructuredQueries.swift) | What version 1.12.0 actually encodes. | App Review permission or proof of the future consent protocol. |
| Other developers' privacy policies | Their stated practices. | Verified binaries, Apple review reasoning, or reusable approval. |

The product decisions are recorded in the [specification](../calorie-card-sharing-spec.md). Before committing to a CloudKit implementation, resolve the exact policy classification and validate the two-account flow with the selected scope model. The remaining technical questions include invitation and reciprocal acceptance behavior, mid-flight reductions, publisher takeover, account changes, recipient cache removal, and cleanup retries. These are validation tasks for the preferred architecture, not unanswered product choices.

No production data was uploaded, no invitation was sent, and no Apple consultation was requested during this research.


## Live email-identity finding on 2026-10-24

A real iOS 27 Simulator lookup for the other signed-in account returned a valid `CKShare.Participant`, `hasiCloudAccount == true`, and no `userIdentity.userRecordID`. Requiring that optional ID before creating a share made the normal Invite UI fail, although tests using already-known record IDs had passed. The source breakpoint and service result are retained in `output/sharing-qa/completion/cloud/solo/email-ui-20261024-1637/identity-diagnosis.json`.

Apple's [email participant lookup](https://developer.apple.com/documentation/cloudkit/ckcontainer/shareparticipant(foremailaddress:)) permits email-bound pending participants. Its [participant contract](https://developer.apple.com/documentation/cloudkit/ckshare/participant) supplies a stable participant identifier. The installed iOS 27 SDK also declares the user record ID nullable. Identity discovery methods are deprecated and are not a replacement for the sharing handshake.

The adapter now persists the original invitation choices and participant ID only in the inviter's encrypted private directory. It creates a private metadata share for the email participant. After actual acceptance, the inviter reads its private CKShare and requires exactly the originally invited, accepted private participant before binding the real account ID and creating the owner-controlled consent proposal. Calorie sharing still needs separate explicit consent and reciprocal setup. Writable discovery fields never provide this authority.

Live v13 testing confirmed native email invitation creation, metadata-only server records, metadata acceptance without calorie grants, exact account binding, explicit consent, reciprocal Today readiness, and normal sample-source app publication to the other real account. Current v14 repeats cancellation safely and retains the data-delivery result. See `cloud/solo/email-v13/` and `email-v14/`. These tests use Development and synthetic inputs. They do not resolve App Review classification or production deployment.

Final v16 validation also passed isolated pending-invitation actions, retained native Send access, metadata-only expiry and native removal followed by direct server access denial. The v14 interruption test terminated the process after acknowledged share deletion and proved fresh-fetch orphan cleanup without replaying the canceled request. All recorded synthetic data has been removed from both accounts, with empty zones retained. See the final [verification report](../calorie-card-sharing-verification.md) for artifact versions, evidence and remaining physical-device checks.
