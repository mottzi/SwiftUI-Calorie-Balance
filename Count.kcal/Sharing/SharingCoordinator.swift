import Foundation
import Observation

@MainActor @Observable
/// Account-scoped coordinator for UI state and durable consent work.
final class SharingCoordinator {

    /// Verified account state used by sharing actions.
    private(set) var accountStatus: SharingAccountStatus = .uncertain

    /// Account identity last verified by the transport.
    private(set) var identity: SharingIdentity?

    /// Persisted connections, snapshots, and durable operations.
    private(set) var state = SharingLocalState()

    /// Error from the latest coordinator refresh.
    private(set) var lastError: String?

    /// Underlying failure retained for silent retry scheduling.
    private(set) var refreshFailure: Error?

    /// Whether a refresh pass is active.
    private(set) var isRefreshing = false

    /// Identifier of this publishing device.
    let deviceID: UUID

    /// CloudKit container expected by this coordinator.
    let containerIdentifier: String

    /// Local database for this account's sharing state.
    @ObservationIgnored private let store: SharingStore

    /// Service used for account, consent, and snapshot operations.
    @ObservationIgnored private let transport: any SharingTransport

    /// Clock used for consent and date-window checks.
    @ObservationIgnored private let clock: () -> Date

    /// Generation that rejects work started for a prior account.
    @ObservationIgnored private var accountEpoch = 0

    /// Sequence that rejects older account-status responses.
    @ObservationIgnored private var verificationSequence = 0

    /// Sequence that rejects older publisher-lease claims.
    @ObservationIgnored private var publisherSequence = 0

    /// Whether another refresh arrived during the active pass.
    @ObservationIgnored private var refreshAgain = false

    /// Shared refresh task whose lifetime does not depend on a requesting view.
    @ObservationIgnored private var refreshTask: Task<Void, Never>?

    init(
        store: SharingStore,
        transport: any SharingTransport,
        containerIdentifier: String = "iCloud.com.count.kcal.app",
        deviceID: UUID = UUID(),
        clock: @escaping () -> Date = { .now }
    ) {
        self.store = store
        self.transport = transport
        self.containerIdentifier = containerIdentifier
        self.deviceID = deviceID
        self.clock = clock
    }

    /// Shares active reads and repeats only after an explicit invalidation.
    func refresh(_ request: SharingRefresh = .current) async {

        if let refreshTask {
            if request == .changed { refreshAgain = true }
            await refreshTask.value
            return
        }
        isRefreshing = true
        let task = Task {
            defer {
                isRefreshing = false
                refreshTask = nil
            }
            repeat {
                refreshAgain = false
                await performRefresh()
            } while refreshAgain
        }
        refreshTask = task
        await task.value
    }

    /// Connections that have not been removed.
    var connections: [SharingConnection] { state.connections.filter { !$0.removed } }

    /// Share removals that still need transport confirmation.
    var pendingRevocations: [SharingRevocation] { state.pendingRevocations }

    /// Cached snapshots that still pass consent and date checks.
    var cachedSnapshots: [SharedSnapshotEnvelope] { state.snapshots.filter { canDisplay($0) } }

    /// Whether local state names this device as the stored identity's publisher.
    var isPublisher: Bool { state.publisherLease?.deviceID == deviceID && identity?.id == state.publisherLease?.accountID }

    /// Verifies the account and discards state from other accounts.
    func verifyAccount() async {

        verificationSequence += 1
        let verification = verificationSequence
        var confirmedSignOut = false
        do {
            let status = try await transport.accountStatus()
            guard verification == verificationSequence else { return }
            switch status {
            case .uncertain:
                accountStatus = .uncertain
                purgeExpiredCache()
            case .signedOut:
                confirmedSignOut = true
                accountEpoch += 1
                identity = nil
                state = SharingLocalState()
                accountStatus = .signedOut
                try store.clearOtherAccounts(keeping: nil)
            case .available(let account):
                if identity?.id != account.id {
                    accountEpoch += 1
                    identity = account
                    state = SharingLocalState()
                    try store.clearOtherAccounts(keeping: account.id)
                    state = try store.load(accountID: account.id)
                    // a restored local lease does not grant publication authority
                    state.publisherLease = nil
                    for envelope in state.snapshots { observeSenderCalendar(envelope) }
                } else {
                    identity = account
                    try store.clearOtherAccounts(keeping: account.id)
                }
                accountStatus = .available(account)
                let epoch = accountEpoch
                let publisher = publisherSequence
                let lease = try await transport.publisherLease(account: account, deviceID: deviceID)
                guard verification == verificationSequence, isCurrent(account, epoch: epoch) else { return }
                guard lease == nil || (lease?.accountID == account.id && lease?.deviceID == deviceID)
                    else { throw SharingError.wrongAccount }
                if publisher == publisherSequence { state.publisherLease = lease }
                purgeExpiredCache()
            }
            lastError = nil
            refreshFailure = nil
        } catch {
            guard verification == verificationSequence else { return }
            accountStatus = confirmedSignOut ? .signedOut : .uncertain
            refreshFailure = error
            lastError = SharingError.message(for: error)
            purgeExpiredCache()
        }
    }

    @discardableResult
    /// Queues a proposal to share the selected scopes with a peer.
    func propose(to peer: SharingIdentity, scopes: Set<SharingScope> = [.today]) async throws -> UUID {

        guard let account = verifiedAccount else { throw SharingError.accountUnavailable }
        guard peer.id != account.id, !peer.id.isEmpty, !scopes.isEmpty,
              !connections.contains(where: { $0.peer(of: account.id)?.id == peer.id })
            else { throw SharingError.invalidConnection }
        let connection = SharingConnection(
            id: UUID(),
            containerIdentifier: containerIdentifier,
            inviter: account,
            invitee: peer
        )
        let proposal = makeProposal(connection: connection, scopes: scopes, account: account)
        try enqueue(connection: connection, action: .propose(proposal), account: account)
        await refresh(.changed)
        return connection.id
    }

    /// Queues the recipient's acceptance of a proposal.
    func accept(connectionID: UUID, proposalID: UUID) async throws {
        let (connection, account) = try context(connectionID)
        try enqueue(connection: connection, action: .accept(proposalID: proposalID), account: account)
        await refresh(.changed)
    }

    /// Queues the recipient's rejection of a proposal.
    func decline(connectionID: UUID, proposalID: UUID) async throws {
        let (connection, account) = try context(connectionID)
        try enqueue(connection: connection, action: .decline(proposalID: proposalID), account: account)
        await refresh(.changed)
    }

    /// Queues the inviter's cancellation of a proposal.
    func cancel(connectionID: UUID, proposalID: UUID) async throws {
        let (connection, account) = try context(connectionID)
        try enqueue(connection: connection, action: .cancel(proposalID: proposalID), account: account)
        await refresh(.changed)
    }

    /// Remove first, then request additions against the reduced revision.
    func changeScopes(connectionID: UUID, to scopes: Set<SharingScope>) async throws {

        var (connection, account) = try context(connectionID)
        let retained = connection.scopes.intersection(scopes)
        if retained != connection.scopes || (connection.proposal != nil && scopes.isSubset(of: connection.scopes)) {
            try enqueueReduction(connection: connection, to: retained, account: account, removing: false)
            connection = try context(connectionID).0
        }
        if !scopes.subtracting(connection.scopes).isEmpty {
            try enqueue(
                connection: connection,
                action: .propose(makeProposal(connection: connection, scopes: scopes, account: account)),
                account: account
            )
        }
        await refresh(.changed)
    }

    /// Hides the connection locally and queues both revocation directions.
    func remove(connectionID: UUID) async throws {
        let (connection, account) = try context(connectionID)
        try enqueueReduction(connection: connection, to: [], account: account, removing: true)
        await refresh(.changed)
    }

    /// Retries pending sharing work through a refresh.
    func retry() async { await refresh(.changed) }

    /// Claims the publisher lease for this device and records its generation.
    func takeOverPublisher() async throws {

        try await claimPublisher(.replaceExisting)
    }

    /// Selects this iPhone for first use without replacing another publishing device.
    func preparePublisher() async throws {
        try await claimPublisher(.ifUnclaimed)
    }

    /// Successful reads may publish independently. Failed reads supply no snapshot.
    func publish(snapshot: CalorieCardSnapshot) async throws {
        try await publish(snapshots: [snapshot])
    }

    /// Every publication opportunity also retries retention maintenance, including
    /// opportunities where no read succeeded or every upload failed.
    func publish(snapshots: [CalorieCardSnapshot], streakSnapshot: CalorieCardSnapshot? = nil) async throws {

        let (account, lease, epoch) = try publicationContext()
        var firstError: Error?
        for snapshot in snapshots {
            do { try await publish(snapshot, account: account, lease: lease, epoch: epoch,
                                   scopes: streakSnapshot == nil ? Set(SharingScope.allCases) : [.today, .history]) }
            catch {
                try requirePublicationAuthority(account: account, lease: lease, epoch: epoch)
                if Self.isAuthorityFailure(error) { throw error }
                firstError = firstError ?? error
            }
        }
        if let streakSnapshot {
            do { try await publish(streakSnapshot, account: account, lease: lease, epoch: epoch, scopes: [.streaks]) }
            catch {
                try requirePublicationAuthority(account: account, lease: lease, epoch: epoch)
                if Self.isAuthorityFailure(error) { throw error }
                firstError = firstError ?? error
            }
        }
        try requirePublicationAuthority(account: account, lease: lease, epoch: epoch)
        do { try await cleanupPublishedWindow() }
        catch {
            try requirePublicationAuthority(account: account, lease: lease, epoch: epoch)
            if Self.isAuthorityFailure(error) { throw error }
            firstError = firstError ?? error
        }
        if let firstError { throw firstError }
    }

    /// Local pending state survives ordinary failures. The adapter checks the same
    /// lease atomically with its deletion batches, including after delayed work.
    func cleanupPublishedWindow() async throws {

        let (account, lease, epoch) = try publicationContext()
        state.cleanupPending = true
        try persist()
        try await transport.cleanup(account: account, lease: lease, now: clock())
        try requirePublicationAuthority(account: account, lease: lease, epoch: epoch)
        state.cleanupPending = false
        try persist()
    }

    /// Returns snapshots that remain valid for the connection and scope.
    func snapshots(connectionID: UUID, scope: SharingScope) -> [SharedSnapshotEnvelope] {

        let snapshots = cachedSnapshots.filter { $0.connectionID == connectionID && $0.scope == scope }
        if scope == .today || scope == .streaks {
            return Array(snapshots.sorted { $0.snapshot.capturedAt > $1.snapshot.capturedAt }.prefix(1))
        }
        return snapshots.sorted { $0.snapshot.senderLocalDate > $1.snapshot.senderLocalDate }
    }

    /// Full sender count is available only through its own current consent grant.
    func streak(connectionID: UUID) -> CalorieCardSnapshot.StreakSummary? {
        snapshots(connectionID: connectionID, scope: .streaks).first?.snapshot.streak
    }

    /// Wake exactly at known sender midnight/request expiry, with a minute cap
    /// so wall-clock changes while foregrounded cannot leave stale dates visible.
    func nextExpiryDate() -> Date {

        let now = clock()
        var next = now.addingTimeInterval(60)
        for proposal in state.connections.compactMap(\.proposal) where proposal.expiresAt > now {
            next = min(next, proposal.expiresAt)
        }
        for sender in state.senderCalendars.values {
            guard let zone = TimeZone(identifier: sender.timeZoneIdentifier) else { continue }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = zone
            if let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) {
                next = min(next, midnight)
            }
        }
        return next
    }

    /// Removes expired requests and cached snapshots outside current consent.
    func purgeExpiredCache() {

        let expired = Set(state.connections.compactMap { connection in
            connection.proposal.flatMap { $0.expiresAt <= clock() ? $0.id : nil }
        })
        for index in state.connections.indices
            where state.connections[index].proposal.map({ expired.contains($0.id) }) == true {
            state.connections[index].proposal = nil
        }
        state.pendingMutations.removeAll { mutation in
            switch mutation.action {
            case .propose(let proposal): return expired.contains(proposal.id) || proposal.expiresAt <= clock()
            case .accept(let id): return expired.contains(id)
            default: return false
            }
        }
        let permittedSenders = Set(state.connections.filter { !$0.removed && !$0.scopes.isEmpty }.compactMap { connection in
            identity.flatMap { connection.peer(of: $0.id)?.id }
        })
        let calendars = state.senderCalendars.filter { permittedSenders.contains($0.key) }
        state.senderCalendars = calendars
        let permittedSnapshots = state.snapshots.filter { canDisplay($0) }
        state.snapshots = permittedSnapshots
        try? persist()
    }

}

extension SharingCoordinator {

    /// Records a server-verified claim and rejects completions from a prior account.
    private func claimPublisher(_ policy: SharingPublisherClaim) async throws {

        guard let account = verifiedAccount else { throw SharingError.accountUnavailable }
        let epoch = accountEpoch
        publisherSequence += 1
        let publisher = publisherSequence
        let lease = try await transport.claimPublisher(account: account, deviceID: deviceID, policy: policy)
        guard publisher == publisherSequence,
              isCurrent(account, epoch: epoch),
              lease.accountID == account.id,
              lease.deviceID == deviceID
            else { throw SharingError.wrongAccount }
        state.publisherLease = lease
        for index in state.connections.indices {
            state.connections[index].publisherGenerations[account.id] = lease.generation
        }
        try persist()
    }

    /// Refreshes the verified account's queued operations and remote state.
    private func performRefresh() async {

        await verifyAccount()
        guard let account = verifiedAccount else { return }
        let epoch = accountEpoch
        var firstError: Error?
        do {
            firstError = await flushPending(account: account, epoch: epoch)
            guard isCurrent(account, epoch: epoch) else { return }
            let remote = try await transport.fetchConnections(for: account)
            guard isCurrent(account, epoch: epoch) else { return }
            mergeVerified(remote, account: account)
            try persist()
            var attemptedProvision = false
            for connection in state.connections where !connection.removed {
                for grant in connection.grants where !grant.readyAccountIDs.contains(account.id) {
                    do {
                        let request = SharingProvisionRequest(
                            connection: connection,
                            accountID: account.id,
                            scope: grant.scope,
                            generation: grant.generation
                        )
                        attemptedProvision = true
                        let receipt = try await transport.provision(request)
                        guard isCurrent(account, epoch: epoch) else { return }
                        guard receipt.connectionID == connection.id,
                              receipt.accountID == account.id,
                              receipt.scope == grant.scope,
                              receipt.generation == grant.generation
                            else { throw SharingError.invalidConnection }
                        guard let index = state.connections.firstIndex(where: { $0.id == connection.id }),
                              let grantIndex = state.connections[index].grants.firstIndex(
                                where: { $0.scope == grant.scope && $0.generation == grant.generation }
                              ) else { continue }
                        state.connections[index].grants[grantIndex].readyAccountIDs.insert(account.id)
                        try persist()
                    } catch SharingError.peerSetupPending {
                        // the next refresh can complete setup after the peer publishes its URL
                    } catch {
                        guard isCurrent(account, epoch: epoch) else { return }
                        firstError = firstError ?? error
                    }
                }
            }
            if attemptedProvision {
                let provisioned = try await transport.fetchConnections(for: account)
                guard isCurrent(account, epoch: epoch) else { return }
                mergeVerified(provisioned, account: account)
            }
            for connection in state.connections
                where !connection.removed && connection.grants.contains(where: { connection.isReady($0.scope) }) {
                do {
                    let incoming = try await transport.fetchSnapshots(connection: connection, as: account)
                    guard isCurrent(account, epoch: epoch) else { return }
                    if let verified = incoming.connection { mergeVerified([verified], account: account) }
                    for envelope in incoming.snapshots { observeSenderCalendar(envelope) }
                    for envelope in incoming.snapshots where canDisplay(envelope) { replaceCached(envelope) }
                } catch SharingError.scopeRevoked(let connectionID, let scope) {
                    guard isCurrent(account, epoch: epoch) else { return }
                    do {
                        guard connectionID == connection.id,
                              let fetchedGrant = connection.grants.first(where: { $0.scope == scope })
                            else { throw SharingError.invalidConnection }
                        // a delayed failure for an old hierarchy cannot revoke a newly accepted generation
                        guard let current = state.connections.first(where: { $0.id == connectionID && !$0.removed }),
                              current.grants.contains(
                                where: { $0.scope == scope && $0.generation == fetchedGrant.generation }
                              )
                            else { continue }
                        try enqueueReduction(
                            connection: current,
                            to: current.scopes.subtracting([scope]),
                            account: account,
                            removing: false
                        )
                        refreshAgain = true
                    } catch { firstError = firstError ?? error }
                } catch {
                    guard isCurrent(account, epoch: epoch) else { return }
                    firstError = firstError ?? error
                }
            }
            purgeExpiredCache()
            if isPublisher {
                state.cleanupPending = true
                try persist()
            }
            refreshFailure = firstError
            lastError = firstError.map(SharingError.message(for:))
        } catch {
            if isCurrent(account, epoch: epoch) {
                refreshFailure = firstError ?? error
                lastError = SharingError.message(for: firstError ?? error)
                try? persist()
            }
        }
    }

    /// Publishes a snapshot to each ready grant while authority remains current.
    private func publish(_ snapshot: CalorieCardSnapshot, account: SharingIdentity,
                         lease: SharingPublisherLease, epoch: Int, scopes: Set<SharingScope>) async throws {

        guard snapshot.isSupported else { throw SharingError.unsupportedSchema }
        var firstError: Error?
        for connection in state.connections where !connection.removed {
        for grant in connection.grants where scopes.contains(grant.scope) && connection.isReady(grant.scope) {
            let payload = snapshot.payload(for: grant.scope)
            guard SharingDateWindow.permits(
                payload,
                scope: grant.scope,
                now: clock()
            ) else { continue }
                try requirePublicationAuthority(account: account, lease: lease, epoch: epoch)
                guard let current = state.connections.first(where: { $0.id == connection.id }),
                      current.isReady(grant.scope),
                  current.grants.contains(
                    where: { $0.scope == grant.scope && $0.generation == grant.generation }
                  ) else { continue }
            guard current.publisherGenerations[account.id] == lease.generation
                else { throw SharingError.publisherNotOwned }
            let envelope = SharedSnapshotEnvelope(
                connectionID: connection.id,
                senderID: account.id,
                scope: grant.scope,
                consentGeneration: grant.generation,
                publisherGeneration: lease.generation,
                snapshot: payload
            )
                do {
                    try await transport.publish(envelope)
                    try requirePublicationAuthority(account: account, lease: lease, epoch: epoch)
                } catch {
                    try requirePublicationAuthority(account: account, lease: lease, epoch: epoch)
                    if Self.isAuthorityFailure(error) { throw error }
                    firstError = firstError ?? error
                }
            }
        }
        if let firstError { throw firstError }
    }

    /// Returns the verified account, owned lease, and generation for publication.
    private func publicationContext() throws -> (SharingIdentity, SharingPublisherLease, Int) {

        guard let account = verifiedAccount else { throw SharingError.accountUnavailable }
        guard let lease = state.publisherLease,
              lease.deviceID == deviceID,
              lease.accountID == account.id
            else { throw SharingError.publisherNotOwned }
        return (account, lease, accountEpoch)
    }

    /// Rejects publication work after its account or lease authority changes.
    private func requirePublicationAuthority(account: SharingIdentity, lease: SharingPublisherLease, epoch: Int) throws {

        guard isCurrent(account, epoch: epoch) else { throw SharingError.accountUnavailable }
        guard state.publisherLease == lease else { throw SharingError.publisherNotOwned }
    }
}

extension SharingCoordinator {

    /// Identifies errors that invalidate the active publication authority.
    private static func isAuthorityFailure(_ error: Error) -> Bool {

        guard let error = error as? SharingError else { return false }
        switch error { case .accountUnavailable, .wrongAccount, .publisherNotOwned: return true; default: return false }
    }
}

extension SharingCoordinator {

    /// Returns the available account only when it matches the current identity.
    private var verifiedAccount: SharingIdentity? {

        guard case .available(let account) = accountStatus, account.id == identity?.id else { return nil }
        return account
    }

    /// Checks whether work still belongs to the verified account generation.
    private func isCurrent(_ account: SharingIdentity, epoch: Int) -> Bool {

        accountEpoch == epoch && verifiedAccount?.id == account.id
    }

    /// Returns a connection and account for an action, including offline reductions.
    private func context(_ connectionID: UUID) throws -> (SharingConnection, SharingIdentity) {

        // offline reductions remain possible while account verification is uncertain
        guard let account = identity else { throw SharingError.accountUnavailable }
        guard let connection = state.connections.first(where: { $0.id == connectionID && !$0.removed }),
              connection.peer(of: account.id) != nil else { throw SharingError.invalidConnection }
        return (connection, account)
    }

    /// Creates a proposal against the connection's current revision and request lifetime.
    private func makeProposal(
        connection: SharingConnection,
        scopes: Set<SharingScope>,
        account: SharingIdentity
    ) -> SharingProposal {

        let createdAt = clock()
        return SharingProposal(
            id: UUID(),
            proposerID: account.id,
            recipientID: connection.peer(of: account.id)!.id,
            baseRevision: connection.revision,
            scopes: scopes,
            createdAt: createdAt,
            expiresAt: createdAt.addingTimeInterval(SharingConsent.requestLifetime)
        )
    }

    /// Applies a consent action locally and saves it for retry.
    private func enqueue(connection: SharingConnection, action: SharingConsentAction, account: SharingIdentity) throws {

        let mutation = SharingConsentMutation(
            id: UUID(),
            connection: connection,
            actorID: account.id,
            expectedRevision: connection.revision,
            action: action,
            createdAt: clock()
        )
        let updated = try SharingConsent.applying(mutation, to: connection, now: clock())
        state.connections.removeAll { $0.id == connection.id }
        state.connections.append(updated)
        state.pendingMutations.append(mutation)
        try persist()
    }

    /// Records scope revocations before queueing a reduced consent revision.
    private func enqueueReduction(connection: SharingConnection, to scopes: Set<SharingScope>, account: SharingIdentity,
                                  removing: Bool) throws {

        for grant in connection.grants where !scopes.contains(grant.scope) {
            for direction in SharingDirection.allCases {
                let recorded = state.pendingRevocations + state.confirmedRevocations
                if recorded.contains(
                    where: {
                        $0.connectionID == connection.id && $0.accountID == account.id
                            && $0.scope == grant.scope && $0.generation == grant.generation && $0.direction == direction
                    }
                ) { continue }
                state.pendingRevocations.append(SharingRevocation(
                    id: UUID(),
                    connectionID: connection.id,
                    accountID: account.id,
                    peerID: connection.peer(of: account.id)!.id,
                    scope: grant.scope,
                    generation: grant.generation,
                    direction: direction
                ))
            }
        }
        // replaced requests cannot be retried after a reduction
        state.pendingMutations.removeAll { mutation in
            guard mutation.connection.id == connection.id else { return false }
            switch mutation.action { case .propose, .accept: return true; default: return false }
        }
        // the reduction targets the last server revision if its pending proposal was dropped
        var base = connection
        if let proposal = connection.proposal,
           !state.pendingMutations.contains(where: { $0.connection.id == connection.id }) {
            base.revision = min(base.revision, proposal.baseRevision + 1)
        }
        try enqueue(
            connection: base,
            action: removing ? .remove : .reduce(to: scopes),
            account: account
        )
        purgeExpiredCache()
    }

    /// Retries queued revocations and consent mutations in order.
    private func flushPending(account: SharingIdentity, epoch: Int) async -> Error? {

        // each deletion is recorded separately so a failed incoming leave cannot repeat a confirmed outgoing deletion
        var firstError: Error?
        for operation in state.pendingRevocations {
            do {
                try await transport.revoke(operation)
                guard isCurrent(account, epoch: epoch) else { return firstError }
                state.pendingRevocations.removeAll { $0.id == operation.id }
                state.confirmedRevocations.append(operation)
                try persist()
            } catch { firstError = firstError ?? error }
        }
        for mutation in state.pendingMutations {
            // a preceding conflict or reentrant reduction may have canceled this request
            guard state.pendingMutations.contains(where: { $0.id == mutation.id }) else { continue }
            do {
                let remote = try await transport.commit(mutation, as: account)
                guard isCurrent(account, epoch: epoch) else { return firstError }
                guard valid(remote, account: account), remote.id == mutation.connection.id
                    else { throw SharingError.invalidConnection }
                state.pendingMutations.removeAll { $0.id == mutation.id }
                // queued work already contains this result's revision
                if !state.pendingMutations.contains(where: { $0.connection.id == remote.id }) {
                    state.connections.removeAll { $0.id == remote.id }
                    state.connections.append(remote)
                }
                try persist()
            } catch let error as SharingError where error == .staleRevision || error == .invalidConnection
                || error == .invalidProposal || error == .proposalExpired || error == .staleGeneration {
                firstError = firstError ?? error
                do {
                    let remote = try await transport.fetchConnections(for: account)
                    guard isCurrent(account, epoch: epoch) else { return firstError }
                    state.pendingMutations.removeAll { $0.id == mutation.id }
                    if let current = remote.first(where: { $0.id == mutation.connection.id }),
                       valid(current, account: account) {
                        if current.removed {
                            state.pendingMutations.removeAll { $0.connection.id == current.id }
                            state.connections.removeAll { $0.id == current.id }
                            state.connections.append(current)
                        } else {
                            switch mutation.action {
                            case .reduce(let scopes):
                                try enqueueReduction(
                                    connection: current,
                                    to: scopes.intersection(current.scopes),
                                    account: account,
                                    removing: false
                                )
                            case .remove:
                                try enqueueReduction(connection: current, to: [], account: account, removing: true)
                            default:
                                if !state.pendingMutations.contains(where: { $0.connection.id == current.id }) {
                                    state.connections.removeAll { $0.id == current.id }
                                    state.connections.append(current)
                                }
                            }
                        }
                    } else {
                        state.pendingMutations.removeAll { $0.connection.id == mutation.connection.id }
                        state.connections.removeAll { $0.id == mutation.connection.id }
                    }
                    purgeExpiredCache()
                    try persist()
                } catch let reconciliationError { firstError = firstError ?? reconciliationError }
            } catch { firstError = firstError ?? error }
        }
        return firstError
    }

    /// Saves the current state under its known account identity.
    private func persist() throws {

        if let identity { try store.save(state, accountID: identity.id) }
    }
}

extension SharingCoordinator {

    /// Checks that a connection belongs to this container and account.
    private func valid(_ connection: SharingConnection, account: SharingIdentity) -> Bool {

        connection.containerIdentifier == containerIdentifier && connection.peer(of: account.id) != nil
    }

    /// Applies returned removals and retains queued or newer active state.
    private func mergeVerified(_ remote: [SharingConnection], account: SharingIdentity) {

        for connection in remote where valid(connection, account: account) {
            if connection.removed {
                state.pendingMutations.removeAll { $0.connection.id == connection.id }
                state.connections.removeAll { $0.id == connection.id }
                state.connections.append(connection)
                continue
            }
            if state.pendingMutations.contains(where: { $0.connection.id == connection.id }) { continue }
            if let local = state.connections.first(where: { $0.id == connection.id }),
               local.revision > connection.revision { continue }
            state.connections.removeAll { $0.id == connection.id }
            state.connections.append(connection)
        }
        // missing connections do not prove removal because reads can be partial
        purgeExpiredCache()
    }

    /// Checks an envelope against current identity, consent, publisher, and snapshot metadata.
    private func isTrustedEnvelope(_ envelope: SharedSnapshotEnvelope) -> Bool {

        guard let account = identity,
              let connection = state.connections.first(where: { $0.id == envelope.connectionID }),
              connection.peer(of: account.id)?.id == envelope.senderID,
              connection.isReady(envelope.scope),
              connection.grants.contains(
                where: { $0.scope == envelope.scope && $0.generation == envelope.consentGeneration }
              ),
              connection.publisherGenerations[envelope.senderID] == envelope.publisherGeneration,
              envelope.snapshot.isSupported, envelope.snapshot.capturedAt <= clock(),
              envelope.scope != .history || envelope.snapshot.midnight == nil else { return false }
        return true
    }

    /// Checks trust and sender-local date eligibility before displaying a snapshot.
    private func canDisplay(_ envelope: SharedSnapshotEnvelope) -> Bool {

        guard isTrustedEnvelope(envelope) else { return false }
        let latestZone = state.senderCalendars[envelope.senderID].flatMap { TimeZone(identifier: $0.timeZoneIdentifier) }
        return SharingDateWindow.permits(
            envelope.snapshot,
            scope: envelope.scope,
            now: clock(),
            latestSenderTimeZone: latestZone
        )
    }

    /// Updates sender calendar metadata from a trusted newer snapshot.
    private func observeSenderCalendar(_ envelope: SharedSnapshotEnvelope) {

        guard isTrustedEnvelope(envelope) else { return }
        if let current = state.senderCalendars[envelope.senderID],
           current.capturedAt >= envelope.snapshot.capturedAt { return }
        state.senderCalendars[envelope.senderID] = SharingSenderCalendar(
            timeZoneIdentifier: envelope.snapshot.timeZoneIdentifier,
            capturedAt: envelope.snapshot.capturedAt,
            snapshotID: envelope.snapshot.id
        )
    }

    /// Replaces a cached envelope unless the existing copy is newer.
    private func replaceCached(_ envelope: SharedSnapshotEnvelope) {

        if let existing = state.snapshots.first(where: { $0.id == envelope.id }),
           existing.snapshot.capturedAt > envelope.snapshot.capturedAt { return }
        state.snapshots.removeAll { $0.id == envelope.id }
        state.snapshots.append(envelope)
    }
}

/// Whether a caller needs the current read or invalidates an in-flight read.
enum SharingRefresh {

    /// Joins a read already in progress.
    case current

    /// Requires a follow-up if a read is already in progress.
    case changed

}
