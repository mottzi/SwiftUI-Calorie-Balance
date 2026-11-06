import Foundation

/// Synthetic sharing identities and snapshots with no account or HealthKit data.
enum SharingFixtures {

    /// Builds a deterministic card snapshot for a sender-local day.
    static func snapshot(day: Date, capturedAt: Date, timeZone: TimeZone = TimeZone(identifier: "Europe/Zurich")!,
                         consumed: Int = 1700, includeProjection: Bool = true,
                         goalReached: Bool? = nil, isExcluded: Bool? = nil,
                         nameColor: CalorieCardSnapshot.AdaptiveColor? = nil) -> CalorieCardSnapshot {

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let start = calendar.startOfDay(for: day)
        let color = CalorieCardSnapshot.AdaptiveColor(
            light: .init(red: 0.2, green: 0.5, blue: 0.8),
            dark: .init(red: 0.4, green: 0.7, blue: 1)
        )
        let background = CalorieCardSnapshot.AdaptiveColor(
            light: .init(red: 1, green: 1, blue: 1),
            dark: .init(red: 0.1, green: 0.1, blue: 0.1)
        )
        return CalorieCardSnapshot(
            senderLocalDate: CalorieCardSnapshot.localDate(for: start, calendar: calendar),
            timeZoneIdentifier: timeZone.identifier,
            dayStart: start,
            dayEnd: calendar.date(byAdding: .day, value: 1, to: start)!,
            capturedAt: capturedAt,
            now: .init(
                energy: EnergyBalance(
                    active: 400,
                    resting: 1400,
                    restingRemaining: 0,
                    consumed: consumed
                ),
                visibleGoalReached: goalReached
            ),
            midnight: includeProjection ? .init(
                energy: EnergyBalance(
                    active: 400,
                    resting: 1400,
                    restingRemaining: 200,
                    consumed: consumed
                ),
                visibleGoalReached: goalReached
            ) : nil,
            energyUnit: .kcal,
            appearance: .init(
                burned: color,
                consumed: color,
                cardBackground: background,
                graphEmpty: background,
                nameColor: nameColor
            ),
            isExcluded: isExcluded
        )
    }

    /// First identity used by two-person fixtures.
    static let alice = SharingIdentity(id: "fixture-alice", displayName: "Alice")

    /// Second identity used by two-person fixtures.
    static let bob = SharingIdentity(id: "fixture-bob", displayName: "Bob")

    /// CloudKit container identifier expected by the sharing model.
    static let containerIdentifier = "iCloud.com.count.kcal.app"

}

#if DEBUG
extension SharingFixtures {

    @MainActor
    /// Runs reciprocal fixture refreshes and publishes the peer's permitted snapshots.
    static func synchronize(peer: SharingCoordinator, recipient: SharingCoordinator,
                            now: Date, timeZone: TimeZone = .current) async throws {

        await peer.refresh()
        await recipient.refresh()
        await peer.refresh()
        await recipient.refresh()
        guard peer.isPublisher else { return }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let cards = (-SharingDateWindow.historyDayCount...0).compactMap { offset -> CalorieCardSnapshot? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { return nil }
            return snapshot(
                day: day,
                capturedAt: now,
                timeZone: timeZone,
                consumed: 1750 + offset * 55,
                includeProjection: offset == 0
            )
        }
        try await peer.publish(snapshots: cards)
        await recipient.refresh()
    }

}

@MainActor
/// In-memory sharing authority for protocol tests, not CloudKit access control.
final class SharingFakeServer {

    /// Latest accepted connection state keyed by connection ID.
    var connections: [UUID: SharingConnection] = [:]

    /// Published envelopes keyed by their sender-local record identity.
    var snapshots: [String: SharedSnapshotEnvelope] = [:]

    /// Current publisher lease keyed by account ID.
    var leases: [String: SharingPublisherLease] = [:]

    /// Results keyed by consent mutation ID for idempotent replay.
    var committed: [UUID: SharingConnection] = [:]

    /// Revocation operations already applied by the fake service.
    var revoked: Set<SharingRevocation> = []

    /// Revocation attempts recorded for assertions.
    var revocationAttempts: [SharingRevocation] = []

    /// Directions that fail during revocation.
    var failRevocationDirections: Set<SharingDirection> = []

    /// Whether all consent writes fail.
    var failCommits = false

    /// Whether all publication writes fail.
    var failPublication = false

    /// Connections whose publication writes fail.
    var failPublicationConnections: Set<UUID> = []

    /// Sender-local dates whose publication writes fail.
    var failPublicationDates: Set<String> = []

    /// Snapshot envelopes submitted for publication.
    var publicationAttempts: [SharedSnapshotEnvelope] = []

    /// Whether the next publication waits for the test to resume it.
    var pauseNextPublication = false

    /// Gate used to suspend the next publication.
    let publicationGate = SharingFakeGate()

    /// Publisher record revisions used to reject stale cleanup.
    var publisherRevisions: [String: Int] = [:]

    /// Publisher leases submitted for cleanup.
    var cleanupAttempts: [SharingPublisherLease] = []

    /// Current publisher time zone keyed by account ID.
    var publisherTimeZones: [String: String] = [:]

    /// Whether the next cleanup waits for the test to resume it.
    var pauseNextCleanup = false

    /// Gate used to suspend the next cleanup.
    let cleanupGate = SharingFakeGate()

    /// Scopes whose provisioning writes fail.
    var failProvisionScopes: Set<SharingScope> = []

    /// Scopes that wait for the other account's setup URL.
    var pendingPeerSetupScopes: Set<SharingScope> = []

    /// Whether connection and snapshot reads fail.
    var failFetch = false

    /// Connections whose snapshot reads fail.
    var failSnapshotConnections: Set<UUID> = []

    /// Scope reads that fail for each connection.
    var scopeFetchFailures: [UUID: Set<SharingScope>] = [:]

    /// Whether all cleanup writes fail.
    var failCleanup = false

    /// Whether the next connection fetch waits for the test to resume it.
    var pauseNextFetch = false

    /// Number of connection discovery reads made by test clients.
    var connectionFetchCount = 0

    /// One-shot remote change or failure applied before a snapshot read.
    var beforeSnapshotFetch: (() throws -> Void)?

    /// Scopes that fail after recording their provisioning receipt.
    var failProvisionAfterWriteScopes: Set<SharingScope> = []

    /// Gate used to suspend the next connection fetch.
    let fetchGate = SharingFakeGate()

    /// Clock used to apply consent and sender-date policies.
    var clock: () -> Date

    init(clock: @escaping () -> Date = { .now }) { self.clock = clock }

    /// Creates an account-scoped transport over this fake service.
    func transport(for account: SharingIdentity) -> FakeSharingTransport {
        FakeSharingTransport(server: self, account: account)
    }

    /// Checks whether this service removed the envelope's grant generation.
    func isRevoked(_ envelope: SharedSnapshotEnvelope) -> Bool {
        revoked.contains {
            $0.connectionID == envelope.connectionID
                && $0.scope == envelope.scope
                && $0.generation == envelope.consentGeneration
        }
    }

}

@MainActor
/// In-memory transport used by sharing protocol tests.
final class FakeSharingTransport: SharingTransport {

    /// Shared service state used by this account's transport.
    let server: SharingFakeServer

    /// Account authenticated by this transport.
    var account: SharingIdentity

    /// Sender time zone attached to publications.
    var publisherTimeZone: TimeZone = .current

    /// Account status returned to the coordinator.
    var status: SharingAccountStatus

    /// Whether the next account check waits for the test to resume it.
    var pauseNextAccountCheck = false

    /// Gate used to suspend the next account check.
    let accountGate = SharingFakeGate()

    init(server: SharingFakeServer, account: SharingIdentity) {
        self.server = server
        self.account = account
        self.status = .available(account)
    }

    /// Returns the configured account status, with an optional test delay.
    func accountStatus() async throws -> SharingAccountStatus {

        let captured = status
        if pauseNextAccountCheck {
            pauseNextAccountCheck = false
            await accountGate.suspend()
        }
        return captured
    }

    /// Loads the connections where the account is a participant.
    func fetchConnections(for account: SharingIdentity) async throws -> [SharingConnection] {

        server.connectionFetchCount += 1
        try authenticate(account.id)
        if server.failFetch { throw SharingError.unavailable }
        let captured = server.connections.values.filter { $0.peer(of: account.id) != nil }
        if server.pauseNextFetch {
            server.pauseNextFetch = false
            await server.fetchGate.suspend()
            try Task.checkCancellation()
        }
        return captured
    }

    /// Applies one account-authorized event and reuses its result on replay.
    func commit(_ mutation: SharingConsentMutation, as account: SharingIdentity) async throws -> SharingConnection {

        try authenticate(account.id)
        guard mutation.actorID == account.id else { throw SharingError.wrongAccount }
        if server.failCommits { throw SharingError.unavailable }
        if let result = server.committed[mutation.id] { return result }
        var result = try SharingConsent.applying(
            mutation,
            to: server.connections[mutation.connection.id],
            now: server.clock()
        )
        for identity in [result.inviter, result.invitee] {
            result.publisherGenerations[identity.id] = server.leases[identity.id]?.generation
        }
        server.connections[result.id] = result
        server.committed[mutation.id] = result
        return result
    }

    /// Records this account's readiness for the requested scope generation.
    func provision(_ request: SharingProvisionRequest) async throws -> SharingProvisionReceipt {

        try authenticate(request.accountID)
        if server.failProvisionScopes.contains(request.scope) { throw SharingError.unavailable }
        if server.pendingPeerSetupScopes.contains(request.scope) { throw SharingError.peerSetupPending }
        guard var connection = server.connections[request.connection.id],
              !connection.removed,
              connection.containerIdentifier == request.connection.containerIdentifier,
              let requestGrantIndex = connection.grants.firstIndex(where: { grant in
                  guard grant.scope == request.scope else { return false }
                  return grant.generation == request.generation
              })
        else { throw SharingError.staleGeneration }
        connection.grants[requestGrantIndex].readyAccountIDs.insert(request.accountID)
        server.connections[connection.id] = connection
        if server.failProvisionAfterWriteScopes.contains(request.scope) { throw SharingError.unavailable }
        return SharingProvisionReceipt(
            connectionID: connection.id,
            accountID: request.accountID,
            scope: request.scope,
            generation: request.generation
        )
    }

    /// Records the revocation and removes snapshots for its grant generation.
    func revoke(_ operation: SharingRevocation) async throws {

        try authenticate(operation.accountID)
        server.revocationAttempts.append(operation)
        if server.failRevocationDirections.contains(operation.direction) { throw SharingError.unavailable }
        guard let connection = server.connections[operation.connectionID],
              connection.peer(of: operation.accountID)?.id == operation.peerID
        else { throw SharingError.invalidConnection }
        server.revoked.insert(operation)
        server.snapshots = server.snapshots.filter { _, envelope in !server.isRevoked(envelope) }
    }

    /// Returns this device's current publisher lease, if any.
    func publisherLease(account: SharingIdentity, deviceID: UUID) async throws -> SharingPublisherLease? {
        try authenticate(account.id)
        guard let lease = server.leases[account.id], lease.deviceID == deviceID else { return nil }
        return lease
    }

    /// Replaces the account's fake publisher lease with a new generation.
    func claimPublisher(account: SharingIdentity, deviceID: UUID,
                        policy: SharingPublisherClaim = .replaceExisting) async throws -> SharingPublisherLease {

        try authenticate(account.id)
        let old = server.leases[account.id]
        if policy == .ifUnclaimed, let old, old.deviceID != deviceID { throw SharingError.publisherNotOwned }
        let lease = old.flatMap { $0.deviceID == deviceID ? $0 : nil }
            ?? SharingPublisherLease(accountID: account.id, deviceID: deviceID, generation: UUID())
        server.leases[account.id] = lease
        server.publisherRevisions[account.id, default: 0] += 1
        server.publisherTimeZones[account.id] = publisherTimeZone.identifier
        for id in Array(server.connections.keys) where server.connections[id]?.peer(of: account.id) != nil {
            server.connections[id]?.publisherGenerations[account.id] = lease.generation
        }
        return lease
    }

    /// Stores a supported snapshot while its grant and publisher authority remain current.
    func publish(_ envelope: SharedSnapshotEnvelope) async throws {

        try authenticate(envelope.senderID)
        server.publicationAttempts.append(envelope)
        if server.pauseNextPublication {
            server.pauseNextPublication = false
            await server.publicationGate.suspend()
        }
        try authenticate(envelope.senderID)
        guard server.leases[envelope.senderID]?.generation == envelope.publisherGeneration
        else { throw SharingError.publisherNotOwned }
        if server.failPublication || server.failPublicationConnections.contains(envelope.connectionID)
            || server.failPublicationDates.contains(envelope.snapshot.senderLocalDate)
        { throw SharingError.unavailable }
        guard let connection = server.connections[envelope.connectionID], connection.isReady(envelope.scope),
              connection.grants.contains(where: { grant in
                  grant.scope == envelope.scope && grant.generation == envelope.consentGeneration
              }),
              !server.isRevoked(envelope)
        else { throw SharingError.staleGeneration }
        guard server.leases[envelope.senderID]?.generation == envelope.publisherGeneration
        else { throw SharingError.publisherNotOwned }
        guard envelope.snapshot.isSupported,
              SharingDateWindow.permits(
                  envelope.snapshot,
                  scope: envelope.scope,
                  now: server.clock(),
                  latestSenderTimeZone: publisherTimeZone
              )
        else { throw SharingError.unsupportedSchema }
        if let previous = server.snapshots[envelope.id],
           previous.snapshot.capturedAt > envelope.snapshot.capturedAt { return }
        server.publisherTimeZones[envelope.senderID] = publisherTimeZone.identifier
        server.publisherRevisions[envelope.senderID, default: 0] += 1
        server.snapshots[envelope.id] = envelope
    }

    /// Returns unrevoked snapshots that the account may read for this connection.
    func fetchSnapshots(
        connection: SharingConnection,
        as account: SharingIdentity
    ) async throws -> (connection: SharingConnection?, snapshots: [SharedSnapshotEnvelope]) {

        let change = server.beforeSnapshotFetch
        server.beforeSnapshotFetch = nil
        try change?()
        try authenticate(account.id)
        if server.failSnapshotConnections.contains(connection.id) { throw SharingError.unavailable }
        if server.failFetch { throw SharingError.unavailable }
        guard let current = server.connections[connection.id],
              let peer = current.peer(of: account.id)
        else { throw SharingError.invalidConnection }
        guard !current.removed else { return (current, []) }
        for scope in SharingScope.allCases
        where connection.scopes.contains(scope)
            && server.scopeFetchFailures[connection.id]?.contains(scope) == true {
            throw SharingError.scopeRevoked(connectionID: connection.id, scope: scope)
        }
        let snapshots = server.snapshots.values.filter { envelope in
            envelope.connectionID == connection.id && envelope.senderID == peer.id && current.isReady(envelope.scope)
                && current.grants.contains(where: { grant in
                    grant.scope == envelope.scope && grant.generation == envelope.consentGeneration
                })
                && current.publisherGenerations[peer.id] == envelope.publisherGeneration && !server.isRevoked(envelope)
        }
        return (current, snapshots)
    }

    /// Removes expired snapshots while the supplied lease and revision remain current.
    func cleanup(account: SharingIdentity, lease: SharingPublisherLease, now: Date) async throws {

        try authenticate(account.id)
        server.cleanupAttempts.append(lease)
        guard lease.accountID == account.id, server.leases[account.id] == lease
        else { throw SharingError.publisherNotOwned }
        let revision = server.publisherRevisions[account.id, default: 0]
        guard let identifier = server.publisherTimeZones[account.id],
              let zone = TimeZone(identifier: identifier)
        else { throw SharingError.unavailable }
        if server.pauseNextCleanup {
            server.pauseNextCleanup = false
            await server.cleanupGate.suspend()
        }
        try authenticate(account.id)
        guard server.leases[account.id] == lease else { throw SharingError.publisherNotOwned }
        if server.failCleanup { throw SharingError.unavailable }
        guard revision == server.publisherRevisions[account.id, default: 0] else { throw SharingError.unavailable }
        server.snapshots = server.snapshots.filter { _, envelope in
            envelope.senderID != account.id
                || SharingDateWindow.permits(
                    envelope.snapshot,
                    scope: envelope.scope,
                    now: now,
                    latestSenderTimeZone: zone
                )
        }
    }

    /// Rejects work if this transport's account is not the current signed-in account.
    private func authenticate(_ accountID: String) throws {
        guard case .available(let current) = status, current.id == accountID
        else { throw SharingError.accountUnavailable }
    }

}
@MainActor
/// Controlled async gate for deterministic transport delays.
final class SharingFakeGate {

    /// Continuation suspended until the test resumes this gate.
    private var continuation: CheckedContinuation<Void, Never>?

    /// Waiters notified when the next operation suspends.
    private var observers: [CheckedContinuation<Void, Never>] = []

    /// Suspends the caller until a test resumes the gate.
    func suspend() async {

        await withCheckedContinuation { continuation in
            // allow only one suspended operation at a time
            precondition(self.continuation == nil)
            self.continuation = continuation
            let observers = self.observers
            self.observers = []
            for observer in observers { observer.resume() }
        }
    }

    /// Waits until an operation has suspended at this gate.
    func waitUntilSuspended() async {
        if continuation != nil { return }
        await withCheckedContinuation { observers.append($0) }
    }

    /// Resumes the suspended operation, if one exists.
    func resume() {
        let continuation = self.continuation
        self.continuation = nil
        continuation?.resume()
    }

}
#endif
