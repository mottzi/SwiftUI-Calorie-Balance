# Passive sharing verification

31 October 2026. Devices: Sharing Cloud B, the paired iPhone 16 Pro, and the iPhone 18 Pro simulator for the handoff.

## Result

Implemented one incremental CloudKit reader per database, with an atomic record/token cache and existing push subscriptions. Sharing overview and person detail remain passive. Foreground checks, network recovery, and silent backoff provide recovery without refresh controls or error banners. Incoming card updates do not trigger outgoing health uploads; newly ready consent grants do trigger an initial upload.

The live test changed the implementation decision. CKSyncEngine's manual fetch returned without a database request on Simulator B after state restoration. This left its cache stale despite a new phone publication. Direct database/zone change fetching recovered the missing card. See [ADR 0003](adr/0003-passive-sharing-incoming-sync.md).

## Automated checks

All 104 tests in six focused sharing suites passed on the final source, including cache persistence of encrypted fields, account isolation, failed checkpoint writes, refresh timing, server backoff, consent generation, revocation, publisher fencing, and incoming/outgoing separation. The final timing check ensures navigating to another sharing screen waits only the remaining interval since the last success.

The tests run with an isolated host view. The production dashboard previously ran alongside tests that replace its database, causing an AttributeGraph crash during test execution. The isolated host prevents the dashboard and production sharing runtime from participating in unit tests.

Both simulator and physical-device builds succeeded. The final build was installed and launched on the phone and both simulators. `git diff --check` passed.

## Live checks

- Phone to B: B initially restored the phone's Today card with 50 kcal deficit and six historical cards. Keeping B's detail page untouched from 06:48:22 to 06:48:58 advanced the displayed capture age from seven minutes to 52 seconds, while retaining the correct values.
- B to phone overview: switching the simulator's sample profile from Active to Low activity at 06:49:41 changed the untouched phone overview from 94 kcal deficit to 55 kcal surplus by 06:50:25.
- B to phone detail: restoring Active at 06:50:54 changed the untouched phone detail to 698 burned, 603 eaten, 95 deficit by 06:51:13. Today arrived before the remaining historical cards. By 06:51:45 the historical values also matched the restored Active profile.
- Neither receiving screen needed a refresh gesture, retry button, or navigation to receive these changes. The simulator's original sample profile was restored. The phone's health data and account settings were not changed.
- Incremental fetch logs show a 13-record shared baseline followed by eight changed records, rather than downloading that baseline again. After reinstall and relaunch of the final build at 06:52:15, saved checkpoints produced ten changed private records and zero changed shared records. The shared cache was retained.

Observation times bound the visible delay; they are not exact push latency measurements. The source changes used the simulator's sample-data controls. This verifies CloudKit transfer and UI updates between distinct accounts, not physical HealthKit sample delivery.

Evidence is retained under `.scratch/calorie-card-sharing/verification/2026-10-31-passive-refresh/`.

## Limits

Long-duration background execution, Low Power Mode, and locked-device HealthKit delivery were not established by this foreground test. iOS still controls those opportunities. The app keeps its last verified cards during transient failures and retries when execution and connectivity permit.
