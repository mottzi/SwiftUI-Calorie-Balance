# Count.kcal

Count.kcal reads energy data through HealthRepository and presents calorie cards in SwiftUI. Existing app settings and day choices retain their current storage. Calorie-card sharing has a separate SQLiteData store and an explicit CloudKit adapter.

A snapshot is an immutable sender presentation, including coherent Now/Midnight values, sender calendar date, unit and appearance, including card and page backgrounds. A metadata invitation establishes a CloudKit relationship and grants no calorie permission. A proposal requests one or more mutual scopes: Today, Previous 6 Days, and Goal status & streak. A grant records accepted scope and consent generation. Reciprocal readiness verifies both sender-owned read-only hierarchies. Publisher authority selects one publishing device per account. A reduction removes permissions and retains durable work until server removal is confirmed.

A streak summary is the sender's full count of consecutive completed goal days, ending yesterday, with the sender's flame color. It can extend beyond the shared History window. Goal status & streak shares this count together with reached/not-reached results for permitted calorie dates. Numeric goal targets are never shared. Goal status and streak are one permission. Obsolete development streak grants are stopped; the combined permission needs fresh consent.

Goal results travel separately from calorie records and carry the matching calorie consent generation. Revoking a calorie date grant also invalidates its goal records. Calorie payloads and received legacy calorie caches omit embedded goal results and exclusions. The viewer’s Hide goal status icons preference affects only rendering on their device. Name colors always use the sender’s goal accent, independently of goal-sharing consent.

SharingCoordinator owns consent and local permitted data. CloudKitSharingTransport verifies identities, owner-controlled consent, private/shared permissions and atomic publisher authority. SharingRuntime connects these modules to SwiftUI and HealthRepository. The writable discovery hierarchy carries URLs only.

Permission sheets complete after saving the decision to the existing durable mutation queue. Network refresh does not hold a sheet open. Acceptance performs first-use publisher setup while draining that queue, so setup and consent can retry after relaunch without replacing another publishing iPhone.

Invitation preparation and publisher selection disable only their related actions. Sheets remain dismissible, and an abandoned invitation cannot present a late result. Display names save locally with one pending profile value; writes are serialized, the latest name wins, and ordinary refresh or reconnect retries failures after relaunch.

See `Docs/calorie-card-sharing-spec.md`, `Docs/calorie-card-sharing-verification.md`, and `Docs/adr/0001-bind-email-invitations-after-cloudkit-acceptance.md`. Local implementation issues live in `.scratch/calorie-card-sharing/issues/`.
