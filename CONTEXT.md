# Count.kcal

Count.kcal reads energy data through HealthRepository and presents calorie cards in SwiftUI. Existing app settings and day choices retain their current storage. Calorie-card sharing has a separate SQLiteData store and an explicit CloudKit adapter.

A snapshot is an immutable sender presentation, including coherent Now/Midnight values, sender calendar date, unit and appearance, including card and page backgrounds. A metadata invitation establishes a CloudKit relationship and grants no calorie permission. A proposal requests one or more mutual scopes: Today, Previous 6 Days, and Streak. A grant records accepted scope and consent generation. Reciprocal readiness verifies both sender-owned read-only hierarchies. Publisher authority selects one publishing device per account. A reduction removes permissions and retains durable work until server removal is confirmed.

A streak summary is the sender's full count of consecutive completed goal days, ending yesterday, with the sender's flame color. It can extend beyond the shared History window and has its own consent.

SharingCoordinator owns consent and local permitted data. CloudKitSharingTransport verifies identities, owner-controlled consent, private/shared permissions and atomic publisher authority. SharingRuntime connects these modules to SwiftUI and HealthRepository. The writable discovery hierarchy carries URLs only.

See `Docs/calorie-card-sharing-spec.md`, `Docs/calorie-card-sharing-verification.md`, and `Docs/adr/0001-bind-email-invitations-after-cloudkit-acceptance.md`. Local implementation issues live in `.scratch/calorie-card-sharing/issues/`.
