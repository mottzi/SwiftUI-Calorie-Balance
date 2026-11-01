# CKSyncEngine validation on simulator and iPhone

31 October 2026. Sharing Cloud B ran iOS 27.0, build 24A434. The physical iPhone 16 Pro ran iOS 27.0.1, build 24A446.

## Findings

The initial failure was not limited to the simulator. A restored CKSyncEngine created after the app became active failed to discover a newer snapshot on both devices. The direct CloudKit read returned the newer snapshot. Repeated engine fetches returned without database-change or record-change events.

The initial integration started the engine too late. Creating it in `application(_:willFinishLaunchingWithOptions:)`, before the real foreground notification, fixed the saved-state launch test on the physical phone twice. Both tests received nine changed records and no push. This is evidence for a startup-order defect in our first integration, not a general failure of CKSyncEngine.

A separate recovery case remains. On Simulator B, an engine created early and already active did not discover a later phone snapshot through repeated `fetchChanges()` calls while no push arrived. A real Home-to-app transition made that same engine fetch the changes. The corresponding already-active, no-push case was not isolated on the physical phone because pushes arrived there. Do not report that case as physically verified.

## Test method

A temporary Debug-only probe replaced the normal UI for an explicit `--sync-engine-probe` launch. It uses one shared-database engine, the existing subscription, automatic syncing, and the default fetch-options delegate. Its outgoing batch delegate always returns nil. It has no outgoing queue.

The probe stores its own engine state and snapshot fingerprints, separate from the production cache. The normal sharing runtime is inactive in this mode. A direct CloudKit record read before and after each engine fetch establishes the server snapshot. A result is stale only if those server reads match each other and differ from the engine's cached snapshot.

The sender publishes through the normal app. B's sample profile was changed temporarily and restored to Active. Phone HealthKit data, consent, grants, and publisher authority were not changed.

## Results

| Case | Device | Result |
| --- | --- | --- |
| Fresh state | B and phone | Engine cache matched the server after initial download. |
| Restored state, engine created after activation | B | Stale after manual fetch. No database or record events. |
| Restored state, engine created after activation | Phone | Stale on repeated manual fetches, about 4 ms each. No database or record events. |
| Delayed push after that stale phone state | Phone | Push at 07:07:28 started a fetch and recovered the snapshot before the later foreground transition. |
| Restored state, engine created in will-finish-launching | Phone | Passed twice. Foreground notification followed configuration. Nine changed records, no pushes. |
| New snapshot while the early-start engine stayed open | Phone | Push-driven update passed. |
| New snapshot while the early-start engine stayed open, no push observed | B | Repeated manual fetches remained stale. Direct reads proved that the newer server snapshot was available. |
| Real foreground transition after that stale active state | B | Same process fetched nine changed records and matched the server. No pushes. |

No lifecycle notifications were fabricated. No checkpoint was deleted to recover the failing restored-state cases. A fresh checkpoint was used only for the explicitly named initial baseline tests.

## Interpretation and implementation decision

CKSyncEngine is usable for this sharing feature with correct startup ordering. The earlier statement that it simply failed was too broad. The decision to replace it was made before the startup issue was isolated.

The current direct incremental reader remains a supported, separate design. It can make an explicit server change check without waiting for a notification. This is useful for the visible-screen recovery policy. It has one owner for incoming records and change tokens, and SharingCoordinator still checks consent before it displays snapshots.

This validation did not replace the current reader. A future engine integration must start before the foreground event and must address the already-active missed-push case. It must not add a second independent cache or simulate UIKit notifications. These tests do not establish behavior on every OS version or guarantee background delivery timing.

## Reproduction and evidence

After validation, the read-only probe and its app lifecycle hooks were removed at the user's request. The app uses the direct CloudKit reader in both Debug and Release. The following launch options and command describe the historical test setup and no longer run against the current app. `--probe-fresh` creates a baseline; the default restores the checkpoint after activation; `--probe-early` creates the engine in will-finish-launching.

The command below asserts exact snapshot freshness and produced a failing result for the restored-late phone case:

```sh
python3 .scratch/calorie-card-sharing/verification/2026-10-31-sync-engine/probe.py phone fetch --label phone-restored-late
```

Its saved result contains `matchesServer: false`, `serverStable: true`, zero database/record events, and a 0.0043-second fetch. The script targets the specific relationship and date used in this test; adjust those inputs for a later test date.

JSON results and event journals are under `.scratch/calorie-card-sharing/verification/2026-10-31-sync-engine/`. The final code build passed all 104 focused sharing tests. The normal app was restored after the probe runs.
