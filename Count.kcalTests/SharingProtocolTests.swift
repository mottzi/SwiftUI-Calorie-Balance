import Foundation
import Testing
@testable import Count_kcal

@Suite(.serialized) @MainActor
/// Coordinator and fake transport protocol tests.
struct SharingProtocolTests {

    @Test
    func pausedPersonRetainsNameColorWithoutRetainingSharedValues() async throws {
        let pair = try SharingTestPair()
        let id = try await pair.connect(scopes: [.today])
        try await pair.alice.takeOverPublisher()
        let card = pair.snapshot()
        try await pair.alice.publish(snapshot: card)
        await pair.bob.refresh()
        #expect(pair.bob.senderNameColor(connectionID: id) == card.appearance.burned)

        let nameColor = CalorieCardSnapshot.AdaptiveColor(
            light: .init(red: 1, green: 0.5, blue: 0), dark: .init(red: 1, green: 0.6, blue: 0.2)
        )
        // Appearance can change without a newer health sample capture time.
        let updated = SharingFixtures.snapshot(day: pair.time.now, capturedAt: pair.time.now, nameColor: nameColor)
        try await pair.alice.publish(snapshot: updated)
        await pair.bob.refresh()
        #expect(pair.bob.senderNameColor(connectionID: id) == nameColor)

        try await pair.bob.changeScopes(connectionID: id, to: [])
        #expect(pair.bob.cachedSnapshots.isEmpty)
        #expect(pair.bob.state.senderCalendars.isEmpty)
        #expect(pair.bob.senderMetadata(connectionID: id) == nil)
        #expect(pair.bob.senderNameColor(connectionID: id) == nameColor)

        let restored = SharingCoordinator(
            store: pair.bobStore, transport: pair.bobTransport, clock: { pair.time.now }
        )
        await restored.verifyAccount()
        #expect(restored.senderNameColor(connectionID: id) == nameColor)
        #expect(restored.cachedSnapshots.isEmpty)
        try await restored.remove(connectionID: id)
        #expect(restored.senderNameColor(connectionID: id) == nil)
        #expect(try pair.bobStore.load(accountID: SharingFixtures.bob.id).senderNameColors.isEmpty)
    }

    @Test
    func fullStreakRequiresItsOwnAcceptedGrantAndNeverCarriesCalories() async throws {
        let pair = try SharingTestPair()
        let id = try await pair.connect(scopes: [.today, .history])
        try await pair.alice.takeOverPublisher()
        var card = SharingFixtures.snapshot(day: pair.time.now, capturedAt: pair.time.now)
        card.streak = .init(days: 24, color: card.appearance.burned)
        try await pair.alice.publish(snapshot: card)
        await pair.bob.refresh()
        #expect(pair.bob.streak(connectionID: id) == nil)
        #expect(pair.server.snapshots.values.allSatisfy { $0.snapshot.streak == nil })

        try await pair.alice.changeScopes(connectionID: id, to: [.today, .history, .streaks])
        await pair.bob.refresh()
        #expect(pair.bob.connections.first?.scopes == [.today, .history])
        let proposal = try #require(pair.bob.connections.first?.proposal)
        try await pair.bob.accept(connectionID: id, proposalID: proposal.id)
        await pair.alice.refresh()
        await pair.bob.refresh()
        try await pair.alice.publish(snapshot: card)
        await pair.bob.refresh()
        #expect(pair.bob.streak(connectionID: id)?.days == 24)
        let received = try #require(pair.bob.snapshots(connectionID: id, scope: .streaks).first?.snapshot)
        #expect(received.now.energy.isEmpty)
        #expect(received.now.visibleGoalReached == nil)
        #expect(received.midnight == nil)
        #expect(received.isExcluded == nil)
        #expect(pair.bob.snapshots(connectionID: id, scope: .today).first?.snapshot.now == card.now)
        #expect(pair.bob.snapshots(connectionID: id, scope: .today).first?.snapshot.streak == nil)

        card.streak = nil
        try await pair.alice.publish(snapshot: card)
        await pair.bob.refresh()
        #expect(pair.bob.streak(connectionID: id) == nil)
        card.streak = .init(days: 24, color: card.appearance.burned)
        try await pair.alice.publish(snapshot: card)
        await pair.bob.refresh()
        #expect(pair.bob.streak(connectionID: id)?.days == 24)
        try await pair.bob.changeScopes(connectionID: id, to: [.today, .history])
        #expect(pair.bob.streak(connectionID: id) == nil)
        #expect(pair.bob.snapshots(connectionID: id, scope: .today).count == 1)
    }

    @Test
    func streakOnlyConsentPublishesNoCalorieDataAndExpiresAtSenderMidnight() async throws {
        let pair = try SharingTestPair()
        let id = try await pair.connect(scopes: [.streaks])
        try await pair.alice.takeOverPublisher()
        var card = SharingFixtures.snapshot(day: pair.time.now, capturedAt: pair.time.now)
        card.streak = .init(days: 80, color: card.appearance.burned)
        try await pair.alice.publish(snapshot: card)
        await pair.bob.refresh()
        #expect(pair.bob.streak(connectionID: id)?.days == 80)
        #expect(pair.bob.snapshots(connectionID: id, scope: .today).isEmpty)
        #expect(pair.bob.snapshots(connectionID: id, scope: .history).isEmpty)
        #expect(pair.server.snapshots.values.allSatisfy { $0.snapshot.now.energy.isEmpty && $0.snapshot.midnight == nil })
        #expect(!SharingDateWindow.permits(card, scope: .streaks, now: pair.time.now))
        #expect(!SharingDateWindow.permits(card, scope: .today, now: pair.time.now))
        pair.time.now = card.dayEnd
        #expect(pair.bob.streak(connectionID: id) == nil)
    }

    @Test
    /// Reads stable ready connections once instead of repeating full discovery.
    func readyRefreshDiscoversOnce() async throws {

        let pair = try SharingTestPair()
        _ = try await pair.connect(scopes: [.today, .history])
        pair.server.connectionFetchCount = 0
        await pair.alice.refresh()
        #expect(pair.server.connectionFetchCount == 1)
    }

    @Test
    /// Duplicate read callers share a pass without requesting another pass.
    func duplicateRefreshesDoNotRepeatDiscovery() async throws {

        let pair = try SharingTestPair()
        _ = try await pair.connect(scopes: [.today])
        pair.server.connectionFetchCount = 0
        pair.server.pauseNextFetch = true
        let first = Task { await pair.alice.refresh() }
        await pair.server.fetchGate.waitUntilSuspended()
        let second = Task { await pair.alice.refresh() }
        await Task.yield()
        pair.server.fetchGate.resume()
        await first.value
        await second.value
        #expect(pair.server.connectionFetchCount == 1)
    }

    @Test(arguments: [false, true])
    /// Reconciles provisioning even if the receipt write succeeds before an error.
    func provisioningAttemptsStillReconcile(_ failsAfterWrite: Bool) async throws {

        let pair = try SharingTestPair()
        let id = try await pair.connect(scopes: [.today])
        pair.server.connections[id]?.grants[0].readyAccountIDs.remove(SharingFixtures.alice.id)
        if failsAfterWrite { pair.server.failProvisionAfterWriteScopes = [.today] }
        pair.server.connectionFetchCount = 0
        await pair.alice.refresh()
        #expect(pair.server.connectionFetchCount == 2)
        #expect(pair.alice.connections.first?.isReady(.today) == true)
    }

    @Test
    /// A received invitation after discovery starts requires a fresh read.
    func changedRefreshDiscoversAnInvitationArrivingDuringARead() async throws {

        let pair = try SharingTestPair()
        await pair.bob.verifyAccount()
        pair.server.pauseNextFetch = true
        let first = Task { await pair.alice.refresh() }
        await pair.server.fetchGate.waitUntilSuspended()
        let id = try await pair.bob.propose(to: SharingFixtures.alice)
        let (entered, signal) = AsyncStream<Void>.makeStream()
        let changed = Task {
            signal.yield(())
            signal.finish()
            await pair.alice.refresh(.changed)
        }
        for await _ in entered { break }
        pair.server.fetchGate.resume()
        await first.value
        await changed.value
        #expect(pair.alice.connections.first?.id == id)
        #expect(pair.alice.connections.first?.proposal?.recipientID == SharingFixtures.alice.id)
    }

    @Test
    /// Incoming completion does not wait for outgoing retention maintenance.
    func refreshDefersCleanupDurably() async throws {

        let pair = try SharingTestPair()
        _ = try await pair.connect(scopes: [.today])
        try await pair.alice.takeOverPublisher()
        pair.server.pauseNextCleanup = true
        var finished = false
        let refresh = Task { await pair.alice.refresh(); finished = true }
        try await Task.sleep(for: .milliseconds(100))
        #expect(finished)
        pair.server.cleanupGate.resume()
        await refresh.value
        #expect(try pair.aliceStore.load(accountID: SharingFixtures.alice.id).cleanupPending)
        pair.server.pauseNextCleanup = false
        try await pair.alice.cleanupPublishedWindow()
        #expect(!pair.alice.state.cleanupPending)
    }

    @Test(arguments: [false, true])
    /// A verified reduction during a payload read hides the old cached permission.
    func consentLossDuringSnapshotReadPurgesCache(_ removed: Bool) async throws {

        let pair = try SharingTestPair()
        let id = try await pair.connect(scopes: [.today, .history])
        try await pair.bob.takeOverPublisher()
        try await pair.bob.publish(snapshot: pair.snapshot())
        try await pair.bob.publish(snapshot: SharingFixtures.snapshot(
            day: Calendar.current.date(byAdding: .day, value: -1, to: pair.snapshot().dayStart)!,
            capturedAt: pair.snapshot().capturedAt, includeProjection: false
        ))
        await pair.alice.refresh()
        #expect(pair.alice.cachedSnapshots.count == 2)
        pair.server.beforeSnapshotFetch = {
            pair.server.connections[id]?.grants.removeAll { removed || $0.scope == .history }
            pair.server.connections[id]?.removed = removed
            pair.server.connections[id]?.revision += 1
        }
        await pair.alice.refresh()
        #expect(pair.alice.cachedSnapshots.count == (removed ? 0 : 1))
        #expect(pair.alice.connections.first?.scopes == (removed ? nil : [.today]))
    }

    @Test
    /// An invalid remote generation remains an error rather than a successful refresh.
    func stalePayloadReadStillReportsItsError() async throws {

        let pair = try SharingTestPair()
        _ = try await pair.connect(scopes: [.today])
        pair.server.beforeSnapshotFetch = { throw SharingError.staleGeneration }
        await pair.alice.refresh()
        #expect(pair.alice.lastError != nil)
    }

    @Test
    /// Pending peer setup preserves Today without reporting a failed History expansion.
    func waitingForPeerSetupIsNotARefreshFailure() async throws {

        let pair = try SharingTestPair()
        let id = try await pair.connect(scopes: [.today])
        try await pair.bob.takeOverPublisher()
        try await pair.bob.publish(snapshot: pair.snapshot())
        await pair.alice.refresh()
        pair.server.pendingPeerSetupScopes = [.history]
        try await pair.alice.changeScopes(connectionID: id, to: [.today, .history])
        await pair.bob.refresh()
        let proposal = try #require(pair.bob.connections.first?.proposal)
        try await pair.bob.accept(connectionID: id, proposalID: proposal.id)
        await pair.alice.refresh()
        #expect(pair.alice.lastError == nil)
        #expect(pair.alice.snapshots(connectionID: id, scope: .today).count == 1)
        #expect(pair.alice.connections.first?.isReady(.history) == false)
        pair.server.pendingPeerSetupScopes = []
        await pair.alice.refresh()
        await pair.bob.refresh()
        #expect(pair.bob.connections.first?.isReady(.history) == true)
        #expect(pair.alice.lastError == nil)
    }

    @Test
    /// Navigation cancellation does not cancel the shared refresh or report a failure.
    func refreshCompletesAfterItsViewTaskIsCancelled() async throws {

        let pair = try SharingTestPair()
        let id = try await pair.connect(scopes: [.today])
        try await pair.bob.takeOverPublisher()
        try await pair.bob.publish(snapshot: pair.snapshot())
        pair.server.pauseNextFetch = true
        let viewTask = Task { await pair.alice.refresh() }
        await pair.server.fetchGate.waitUntilSuspended()
        viewTask.cancel()
        pair.server.fetchGate.resume()
        await viewTask.value
        #expect(pair.alice.lastError == nil)
        #expect(pair.alice.snapshots(connectionID: id, scope: .today).count == 1)
        #expect(!pair.alice.isRefreshing)
    }

    @Test
    /// Concurrent callers wait for the active refresh and its requested follow-up.
    func concurrentRefreshCallersWaitForCompletion() async throws {

        let pair = try SharingTestPair()
        pair.server.pauseNextFetch = true
        let first = Task { await pair.alice.refresh() }
        await pair.server.fetchGate.waitUntilSuspended()
        let (entered, signal) = AsyncStream<Void>.makeStream()
        var secondFinished = false
        let second = Task {
            signal.yield(())
            signal.finish()
            await pair.alice.refresh()
            secondFinished = true
        }
        for await _ in entered { break }
        #expect(!secondFinished)
        first.cancel()
        pair.server.fetchGate.resume()
        await first.value
        await second.value
        #expect(secondFinished)
        #expect(pair.alice.lastError == nil)
        #expect(!pair.alice.isRefreshing)
    }

    @Test
    /// First-use setup reuses this device and cannot replace a different publisher.
    func initialPublisherSetupNeverTakesOverAnotherIPhone() async throws {

        let pair = try SharingTestPair()
        await pair.alice.verifyAccount()
        try await pair.alice.preparePublisher()
        let first = try #require(pair.server.leases[SharingFixtures.alice.id])
        try await pair.alice.preparePublisher()
        #expect(pair.server.leases[SharingFixtures.alice.id] == first)
        let other = SharingCoordinator(store: try SharingStore(), transport: pair.aliceTransport)
        await other.verifyAccount()
        await #expect(throws: SharingError.publisherNotOwned) { try await other.preparePublisher() }
        #expect(pair.server.leases[SharingFixtures.alice.id] == first)
        #expect(!other.isPublisher)
        try await other.takeOverPublisher()
        let replacement = try #require(pair.server.leases[SharingFixtures.alice.id])
        #expect(replacement.deviceID == other.deviceID)
        #expect(replacement.generation != first.generation)
        await pair.alice.verifyAccount()
        #expect(!pair.alice.isPublisher)
        await #expect(throws: SharingError.publisherNotOwned) { try await pair.alice.preparePublisher() }
        #expect(pair.server.leases[SharingFixtures.alice.id] == replacement)
    }

    @Test
    /// Unverified accounts cannot select an initial publishing iPhone.
    func initialPublisherSetupRequiresAVerifiedAccount() async throws {

        let pair = try SharingTestPair()
        pair.aliceTransport.status = .uncertain
        await pair.alice.verifyAccount()
        await #expect(throws: SharingError.accountUnavailable) { try await pair.alice.preparePublisher() }
        #expect(pair.server.leases.isEmpty)
    }

    @Test
    /// Consent and reciprocal readiness expose the fixture Today and History cards.
    func incomingRequestFixtureAdvancesTheOtherPhoneOnlyAfterConsent() async throws {

        let pair = try SharingTestPair()
        let id = try await pair.connect(scopes: [.today, .history])
        try await pair.alice.takeOverPublisher()
        try await pair.bob.takeOverPublisher()
        try await pair.bob.changeScopes(connectionID: id, to: [])
        await pair.alice.refresh()
        try await pair.bob.changeScopes(connectionID: id, to: [.today, .history])
        await pair.alice.refresh()
        let request = try #require(pair.alice.connections.first?.proposal)
        let zone = TimeZone(identifier: "Europe/Zurich")!
        try await SharingFixtures.synchronize(peer: pair.bob, recipient: pair.alice, now: pair.time.now, timeZone: zone)
        #expect(pair.alice.connections.first?.proposal?.id == request.id)
        #expect(pair.alice.cachedSnapshots.isEmpty)
        try await pair.alice.accept(connectionID: id, proposalID: request.id)
        #expect(pair.alice.connections.first?.isReady(.today) == false)
        #expect(pair.alice.cachedSnapshots.isEmpty)
        try await SharingFixtures.synchronize(peer: pair.bob, recipient: pair.alice, now: pair.time.now, timeZone: zone)
        #expect(pair.alice.connections.first?.proposal == nil)
        #expect(pair.alice.connections.first?.isReady(.today) == true)
        #expect(pair.alice.connections.first?.isReady(.history) == true)
        #expect(pair.alice.snapshots(connectionID: id, scope: .today).count == 1)
        #expect(pair.alice.snapshots(connectionID: id, scope: .history).count == 6)
        #expect(pair.alice.cachedSnapshots.allSatisfy { $0.consentGeneration == request.id })
        try await pair.alice.changeScopes(connectionID: id, to: [])
        try await SharingFixtures.synchronize(peer: pair.bob, recipient: pair.alice, now: pair.time.now, timeZone: zone)
        #expect(pair.alice.cachedSnapshots.isEmpty)
        #expect(pair.server.snapshots.isEmpty)
    }

    @Test
    /// Proposal expiry uses the timestamp captured for the proposal event.
    func advancingClockStillCreatesAnExactSevenDayProposal() async throws {

        let time = SharingTestTime()
        let advancingClock = {
            time.now = time.now.addingTimeInterval(0.001)
            return time.now
        }
        let server = SharingFakeServer(clock: advancingClock)
        let coordinator = SharingCoordinator(
            store: try SharingStore(),
            transport: server.transport(for: SharingFixtures.alice),
            clock: advancingClock
        )
        await coordinator.verifyAccount()
        let id = try await coordinator.propose(to: SharingFixtures.bob)
        let proposal = try #require(server.connections[id]?.proposal)
        #expect(proposal.expiresAt == proposal.createdAt.addingTimeInterval(SharingConsent.requestLifetime))
    }

    @Test
    /// Neither account receives a card until both setup directions are ready.
    func twoAccountsDiscloseNothingUntilBothDirectionsAreReady() async throws {

        let pair = try SharingTestPair()
        await pair.alice.verifyAccount()
        let id = try await pair.alice.propose(to: SharingFixtures.bob)
        await pair.bob.refresh()
        let proposal = try #require(pair.bob.connections.first?.proposal)
        try await pair.alice.takeOverPublisher()
        try await pair.alice.publish(snapshot: pair.snapshot())
        #expect(pair.server.snapshots.isEmpty)
        try await pair.bob.accept(connectionID: id, proposalID: proposal.id)
        #expect(pair.server.connections[id]?.isReady(.today) == false)
        try await pair.alice.publish(snapshot: pair.snapshot())
        #expect(pair.server.snapshots.isEmpty)
        await pair.alice.refresh()
        try await pair.alice.publish(snapshot: pair.snapshot())
        await pair.bob.refresh()
        #expect(pair.bob.snapshots(connectionID: id, scope: .today).count == 1)
    }

    @Test
    /// Canceling an invitation makes a delayed acceptance stale and leaves no grant.
    func canceledInvitationCannotBeAcceptedAndReplayed() async throws {

        let pair = try SharingTestPair()
        await pair.alice.verifyAccount()
        let id = try await pair.alice.propose(to: SharingFixtures.bob)
        await pair.bob.refresh()
        let connection = try #require(pair.bob.connections.first)
        let proposal = try #require(connection.proposal)
        try await pair.alice.cancel(connectionID: id, proposalID: proposal.id)
        let delayed = SharingConsentMutation(
            id: UUID(),
            connection: connection,
            actorID: SharingFixtures.bob.id,
            expectedRevision: connection.revision,
            action: .accept(proposalID: proposal.id),
            createdAt: pair.time.now
        )
        await #expect(throws: SharingError.staleRevision) {
            _ = try await pair.bobTransport.commit(delayed, as: SharingFixtures.bob)
        }
        await pair.bob.refresh()
        #expect(pair.bob.connections.first?.proposal == nil)
        #expect(pair.bob.connections.first?.scopes.isEmpty == true)
    }

    @Test
    /// A delayed acceptance cannot restore scopes removed at a newer revision.
    func delayedAcceptanceCannotUndoAReduction() async throws {

        let pair = try SharingTestPair()
        let id = try await pair.connect(scopes: [.today])
        try await pair.alice.changeScopes(connectionID: id, to: [.today, .history])
        await pair.bob.refresh()
        let proposal = try #require(pair.bob.connections.first?.proposal)
        let before = try #require(pair.server.connections[id])
        let delayed = SharingConsentMutation(
            id: UUID(),
            connection: before,
            actorID: SharingFixtures.bob.id,
            expectedRevision: before.revision,
            action: .accept(proposalID: proposal.id),
            createdAt: pair.time.now
        )
        try await pair.alice.changeScopes(connectionID: id, to: [])
        await #expect(throws: SharingError.staleRevision) {
            _ = try await pair.bobTransport.commit(delayed, as: SharingFixtures.bob)
        }
        await pair.bob.refresh()
        #expect(pair.bob.connections.first?.scopes.isEmpty == true)
        #expect(pair.bob.cachedSnapshots.isEmpty)
    }

    @Test
    /// Only the intended account can accept before the proposal expires.
    func proposalExpirationAndIntendedAccountAreEnforced() async throws {

        let pair = try SharingTestPair()
        await pair.alice.verifyAccount()
        let id = try await pair.alice.propose(to: SharingFixtures.bob)
        let connection = try #require(pair.server.connections[id])
        let proposal = try #require(connection.proposal)
        let wrong = SharingConsentMutation(
            id: UUID(),
            connection: connection,
            actorID: SharingFixtures.alice.id,
            expectedRevision: connection.revision,
            action: .accept(proposalID: proposal.id),
            createdAt: pair.time.now
        )
        #expect(throws: SharingError.invalidProposal) {
            try SharingConsent.applying(wrong, to: connection, now: pair.time.now)
        }
        pair.time.now = proposal.expiresAt
        let expired = SharingConsentMutation(
            id: UUID(),
            connection: connection,
            actorID: SharingFixtures.bob.id,
            expectedRevision: connection.revision,
            action: .accept(proposalID: proposal.id),
            createdAt: pair.time.now
        )
        #expect(throws: SharingError.proposalExpired) {
            try SharingConsent.applying(expired, to: connection, now: pair.time.now)
        }
        await pair.bob.refresh()
        #expect(pair.bob.connections.first?.proposal == nil)
    }

    @Test
    /// A repeated reduction is idempotent and stale reads cannot restore a removed scope.
    func duplicateCommandsAndOutOfOrderReadsCannotRestoreOldScope() async throws {

        let pair = try SharingTestPair()
        let id = try await pair.connect(scopes: [.today, .history])
        let old = try #require(pair.server.connections[id])
        let command = SharingConsentMutation(
            id: UUID(),
            connection: old,
            actorID: SharingFixtures.alice.id,
            expectedRevision: old.revision,
            action: .reduce(to: [.today]),
            createdAt: pair.time.now
        )
        let once = try await pair.aliceTransport.commit(command, as: SharingFixtures.alice)
        let twice = try await pair.aliceTransport.commit(command, as: SharingFixtures.alice)
        #expect(once == twice)
        await pair.bob.refresh()
        #expect(pair.bob.connections.first?.scopes == [.today])
        pair.server.connections[id] = old
        await pair.bob.refresh()
        #expect(pair.bob.connections.first?.scopes == [.today])
    }

    @Test(arguments: SharingDirection.allCases)
    /// Confirmed revocation directions survive restart while failed work remains retryable.
    func partialRevocationSurvivesSQLiteReopenAndRetriesOnlyUnconfirmedDirection(
        failedDirection: SharingDirection
    ) async throws {

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("alice.sqlite").path
        let pair = try SharingTestPair(aliceStore: SharingStore(path: path))
        let id = try await pair.connect(scopes: [.today, .history])
        pair.server.failRevocationDirections = [failedDirection]
        try await pair.alice.changeScopes(connectionID: id, to: [.today])
        #expect(pair.alice.connections.first?.scopes == [.today])
        #expect(pair.alice.pendingRevocations.count == 1)
        #expect(pair.alice.pendingRevocations.first?.direction == failedDirection)
        let confirmedAttempts = pair.server.revocationAttempts.filter { $0.direction != failedDirection }.count
        let reopened = try SharingStore(path: path)
        let restarted = SharingCoordinator(
            store: reopened,
            transport: pair.aliceTransport,
            deviceID: pair.alice.deviceID,
            clock: { pair.time.now }
        )
        await restarted.verifyAccount()
        #expect(restarted.pendingRevocations.count == 1)
        pair.server.failRevocationDirections = []
        await restarted.retry()
        #expect(restarted.pendingRevocations.isEmpty)
        #expect(pair.server.revocationAttempts.filter { $0.direction != failedDirection }.count == confirmedAttempts)
        #expect(restarted.connections.first?.scopes == [.today])
    }

    @Test
    /// A stale reduction also revokes both directions of a newly learned grant generation.
    func staleReductionAlsoRevokesANewlyLearnedGrantGeneration() async throws {

        let pair = try SharingTestPair()
        let id = try await pair.connect(scopes: [.today, .history])
        let oldGeneration = try #require(
            pair.bob.connections.first?.grants.first(where: { $0.scope == .history })?.generation
        )
        try await pair.alice.changeScopes(connectionID: id, to: [.today])
        try await pair.alice.changeScopes(connectionID: id, to: [.today, .history])
        let expanded = try #require(pair.server.connections[id])
        let proposal = try #require(expanded.proposal)
        let acceptance = SharingConsentMutation(
            id: UUID(),
            connection: expanded,
            actorID: SharingFixtures.bob.id,
            expectedRevision: expanded.revision,
            action: .accept(proposalID: proposal.id),
            createdAt: pair.time.now
        )
        let accepted = try await pair.bobTransport.commit(acceptance, as: SharingFixtures.bob)
        let newGeneration = try #require(accepted.grants.first(where: { $0.scope == .history })?.generation)
        #expect(newGeneration != oldGeneration)
        // bob's local connection still describes the old grant generation
        try await pair.bob.changeScopes(connectionID: id, to: [.today])
        #expect(pair.bob.pendingRevocations.count == 2)
        #expect(pair.bob.pendingRevocations.allSatisfy { $0.generation == newGeneration })
        await pair.bob.retry()
        #expect(pair.bob.pendingRevocations.isEmpty)
        #expect(pair.server.connections[id]?.scopes == [.today])
        #expect(
            pair.bob.state.confirmedRevocations.contains(where: {
                $0.generation == newGeneration && $0.direction == .outgoing
            })
        )
        #expect(
            pair.bob.state.confirmedRevocations.contains(where: {
                $0.generation == newGeneration && $0.direction == .incoming
            })
        )
    }

    @Test
    /// Mixed scope changes reduce access before the new proposal is committed.
    func mixedChangeRemovesBeforeProposingAdditionAndInvalidatesOldProposal() async throws {

        let pair = try SharingTestPair()
        let id = try await pair.connect(scopes: [.today])
        pair.server.failCommits = true
        try await pair.alice.changeScopes(connectionID: id, to: [.history])
        #expect(pair.alice.connections.first?.scopes.isEmpty == true)
        #expect(pair.alice.connections.first?.proposal?.scopes == [.history])
        #expect(pair.alice.state.pendingMutations.count == 2)
        if case .reduce(let retained) = pair.alice.state.pendingMutations[0].action { #expect(retained.isEmpty) }
        else { Issue.record("The reduction must precede the expansion") }
        pair.server.failCommits = false
        await pair.alice.retry()
        #expect(pair.server.connections[id]?.scopes.isEmpty == true)
        #expect(pair.server.connections[id]?.proposal?.scopes == [.history])
    }

    @Test
    /// A successful zero snapshot replaces prior values, while a failed upload preserves the prior card.
    func successfulZeroPublishesWhileFailedUploadPreservesPriorCapture() async throws {

        let pair = try SharingTestPair()
        let id = try await pair.connect(scopes: [.today])
        try await pair.alice.takeOverPublisher()
        let first = pair.snapshot()
        try await pair.alice.publish(snapshot: first)
        await pair.bob.refresh()
        pair.time.now = pair.time.now.addingTimeInterval(60)
        let zero = pair.snapshot(active: 0, resting: 0, consumed: 0)
        pair.server.failPublication = true
        await #expect(throws: SharingError.unavailable) { try await pair.alice.publish(snapshot: zero) }
        await pair.bob.refresh()
        #expect(pair.bob.cachedSnapshots.first?.snapshot.capturedAt == first.capturedAt)
        pair.server.failPublication = false
        try await pair.alice.publish(snapshot: zero)
        await pair.bob.refresh()
        #expect(pair.bob.snapshots(connectionID: id, scope: .today).first?.snapshot.now.consumed == 0)
        #expect(pair.bob.cachedSnapshots.first?.snapshot.now.burned == 0)
        #expect(pair.bob.cachedSnapshots.first?.snapshot.capturedAt == zero.capturedAt)
    }

    @Test
    /// Cached Today expires at the sender known midnight and schedules another check.
    func foregroundExpiryWakesAtTheKnownSendersMidnight() async throws {

        let pair = try SharingTestPair()
        pair.time.now = ISO8601DateFormatter().date(from: "2026-10-24T21:59:50Z")!
        _ = try await pair.connect(scopes: [.today])
        try await pair.alice.takeOverPublisher()
        try await pair.alice.publish(snapshot: pair.snapshot())
        await pair.bob.refresh()
        let midnight = ISO8601DateFormatter().date(from: "2026-10-24T22:00:00Z")!
        #expect(pair.bob.nextExpiryDate() == midnight)
        pair.time.now = midnight
        pair.bob.purgeExpiredCache()
        #expect(pair.bob.cachedSnapshots.isEmpty)
        #expect(pair.bob.nextExpiryDate() == midnight.addingTimeInterval(60))
    }

    @Test
    /// Sender-local date windows follow calendar days across daylight-saving changes.
    func senderMidnightExpiresTodayAndSevenCalendarDatesHandleDST() async throws {

        let time = ISO8601DateFormatter()
        let now = try #require(time.date(from: "2026-10-26T10:00:00Z"))
        let zone = try #require(TimeZone(identifier: "Europe/Zurich"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let today = calendar.startOfDay(for: now)
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: today))
        let yesterdayCard = SharingFixtures.snapshot(
            day: yesterday,
            capturedAt: now,
            timeZone: zone,
            includeProjection: false
        )
        #expect(yesterdayCard.dayEnd.timeIntervalSince(yesterdayCard.dayStart) == 25 * 60 * 60)
        #expect(!SharingDateWindow.permits(yesterdayCard, scope: .today, now: now))
        #expect(SharingDateWindow.permits(yesterdayCard, scope: .history, now: now))
        let oldest = try #require(calendar.date(byAdding: .day, value: -6, to: today))
        #expect(
            SharingDateWindow.permits(
                SharingFixtures.snapshot(
                    day: oldest,
                    capturedAt: now,
                    timeZone: zone,
                    includeProjection: false
                ),
                scope: .history,
                now: now
            )
        )
        let expired = try #require(calendar.date(byAdding: .day, value: -7, to: today))
        #expect(
            !SharingDateWindow.permits(
                SharingFixtures.snapshot(
                    day: expired,
                    capturedAt: now,
                    timeZone: zone,
                    includeProjection: false
                ),
                scope: .history,
                now: now
            )
        )
        let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
        let tokyoCard = SharingFixtures.snapshot(day: now, capturedAt: now, timeZone: tokyo)
        #expect(SharingDateWindow.permits(tokyoCard, scope: .today, now: now))
    }

    @Test
    /// A new sender time zone replaces Today while History keeps its labels across restart.
    func newerSenderTimeZoneReplacesTodayWithoutRegroupingHistoryAndSurvivesRestart() async throws {

        let pair = try SharingTestPair()
        pair.time.now = ISO8601DateFormatter().date(from: "2026-10-23T22:30:00Z")!
        let id = try await pair.connect(scopes: [.today, .history])
        try await pair.alice.takeOverPublisher()
        let zurich = TimeZone(identifier: "Europe/Zurich")!
        let newYork = TimeZone(identifier: "America/New_York")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zurich
        let oldToday = SharingFixtures.snapshot(
            day: pair.time.now,
            capturedAt: pair.time.now.addingTimeInterval(-120),
            timeZone: zurich
        )
        let yesterday = SharingFixtures.snapshot(
            day: calendar.date(byAdding: .day, value: -1, to: pair.time.now)!,
            capturedAt: pair.time.now.addingTimeInterval(-110),
            timeZone: zurich,
            includeProjection: false
        )
        let history = SharingFixtures.snapshot(
            day: calendar.date(byAdding: .day, value: -6, to: pair.time.now)!,
            capturedAt: pair.time.now.addingTimeInterval(-100),
            timeZone: zurich,
            includeProjection: false
        )
        try await pair.alice.publish(snapshot: oldToday)
        try await pair.alice.publish(snapshot: yesterday)
        try await pair.alice.publish(snapshot: history)
        await pair.bob.refresh()
        #expect(pair.bob.snapshots(connectionID: id, scope: .today).first?.snapshot.senderLocalDate == "2026-10-24")
        #expect(pair.bob.snapshots(connectionID: id, scope: .history).count == 2)
        let traveled = SharingFixtures.snapshot(
            day: pair.time.now,
            capturedAt: pair.time.now.addingTimeInterval(-60),
            timeZone: newYork
        )
        pair.aliceTransport.publisherTimeZone = newYork
        try await pair.alice.publish(snapshot: traveled)
        await pair.bob.refresh()
        #expect(pair.bob.snapshots(connectionID: id, scope: .today).map(\.snapshot.id) == [traveled.id])
        #expect(pair.bob.snapshots(connectionID: id, scope: .history).map(\.snapshot.id) == [history.id])
        #expect(pair.bob.snapshots(connectionID: id, scope: .history).first?.snapshot.dayStart == history.dayStart)
        #expect(pair.bob.state.senderCalendars[SharingFixtures.alice.id]?.timeZoneIdentifier == newYork.identifier)
        let restarted = SharingCoordinator(
            store: pair.bobStore,
            transport: pair.bobTransport,
            deviceID: pair.bob.deviceID,
            clock: { pair.time.now }
        )
        await restarted.verifyAccount()
        pair.bobTransport.status = .uncertain
        await restarted.refresh()
        #expect(restarted.snapshots(connectionID: id, scope: .today).map(\.snapshot.id) == [traveled.id])
        #expect(
            restarted.snapshots(connectionID: id, scope: .history).first?.snapshot.senderLocalDate
                == history.senderLocalDate
        )
    }

    @Test
    /// The latest sender time zone can exclude labels outside the History window.
    func newestSenderDateWindowExcludesOldLabelsAfterCrossingTheDateLine() {

        let now = ISO8601DateFormatter().date(from: "2026-10-24T09:30:00Z")!
        let honolulu = TimeZone(identifier: "Pacific/Honolulu")!
        let tokyo = TimeZone(identifier: "Asia/Tokyo")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = honolulu
        let oldest = calendar.date(byAdding: .day, value: -6, to: now)!
        let captured = SharingFixtures.snapshot(
            day: oldest,
            capturedAt: now,
            timeZone: honolulu,
            includeProjection: false
        )
        #expect(SharingDateWindow.permits(captured, scope: .history, now: now))
        #expect(!SharingDateWindow.permits(captured, scope: .history, now: now, latestSenderTimeZone: tokyo))
        #expect(captured.senderLocalDate == "2026-10-17")
    }

    @Test
    /// Future and unsupported snapshots do not replace the last trusted sender calendar.
    func futureAndUnknownSnapshotsCannotChangeTheKnownSenderCalendar() async throws {

        let pair = try SharingTestPair()
        let id = try await pair.connect(scopes: [.today])
        try await pair.alice.takeOverPublisher()
        try await pair.alice.publish(snapshot: pair.snapshot())
        await pair.bob.refresh()
        let original = pair.bob.state.senderCalendars[SharingFixtures.alice.id]
        let connection = try #require(pair.server.connections[id])
        let grant = try #require(connection.grants.first)
        let publisher = try #require(connection.publisherGenerations[SharingFixtures.alice.id])
        let future = SharingFixtures.snapshot(
            day: pair.time.now,
            capturedAt: pair.time.now.addingTimeInterval(60),
            timeZone: TimeZone(identifier: "Asia/Tokyo")!
        )
        let envelope = SharedSnapshotEnvelope(
            connectionID: id,
            senderID: SharingFixtures.alice.id,
            scope: .today,
            consentGeneration: grant.generation,
            publisherGeneration: publisher,
            snapshot: future
        )
        pair.server.snapshots[envelope.id] = envelope
        await pair.bob.refresh()
        #expect(pair.bob.state.senderCalendars[SharingFixtures.alice.id] == original)
        let unknown = CalorieCardSnapshot(
            schemaVersion: 999,
            senderLocalDate: future.senderLocalDate,
            timeZoneIdentifier: future.timeZoneIdentifier,
            dayStart: future.dayStart,
            dayEnd: future.dayEnd,
            capturedAt: pair.time.now,
            now: future.now,
            midnight: future.midnight,
            energyUnit: future.energyUnit,
            appearance: future.appearance
        )
        var invalid = envelope
        invalid.snapshot = unknown
        pair.server.snapshots[invalid.id] = invalid
        await pair.bob.refresh()
        #expect(pair.bob.state.senderCalendars[SharingFixtures.alice.id] == original)
    }

    @Test
    /// History excludes projected Midnight values and snapshots with unknown schemas.
    func historyNeverReceivesMidnightProjectionAndUnknownSchemasStayUnavailable() async throws {

        let time = ISO8601DateFormatter().date(from: "2026-10-26T10:00:00Z")!
        let previous = time.addingTimeInterval(-24 * 60 * 60)
        let projected = SharingFixtures.snapshot(day: previous, capturedAt: previous)
        #expect(!SharingDateWindow.permits(projected, scope: .history, now: time))
        let final = SharingFixtures.snapshot(day: previous, capturedAt: time, includeProjection: false)
        #expect(SharingDateWindow.permits(final, scope: .history, now: time))
        let unknown = CalorieCardSnapshot(
            schemaVersion: 999,
            senderLocalDate: final.senderLocalDate,
            timeZoneIdentifier: final.timeZoneIdentifier,
            dayStart: final.dayStart,
            dayEnd: final.dayEnd,
            capturedAt: final.capturedAt,
            now: final.now,
            midnight: nil,
            energyUnit: final.energyUnit,
            appearance: final.appearance
        )
        #expect(!SharingDateWindow.permits(unknown, scope: .history, now: time))
    }

    @Test
    /// Uncertain account status preserves cache, while a confirmed switch clears account state.
    func cacheSurvivesUncertainAccountButConfirmedSwitchClearsCredentialsAndCache() async throws {

        let pair = try SharingTestPair()
        _ = try await pair.connect(scopes: [.today])
        try await pair.alice.takeOverPublisher()
        try await pair.alice.publish(snapshot: pair.snapshot())
        await pair.bob.refresh()
        #expect(pair.bob.cachedSnapshots.count == 1)
        pair.bobTransport.status = .uncertain
        await pair.bob.refresh()
        #expect(pair.bob.cachedSnapshots.count == 1)
        await #expect(throws: SharingError.accountUnavailable) { try await pair.bob.publish(snapshot: pair.snapshot()) }
        let other = SharingIdentity(id: "other-account", displayName: "Other")
        pair.bobTransport.status = .available(other)
        await pair.bob.verifyAccount()
        #expect(pair.bob.cachedSnapshots.isEmpty)
        #expect(pair.bob.connections.isEmpty)
        #expect(try pair.bobStore.load(accountID: SharingFixtures.bob.id) == SharingLocalState())
        pair.bobTransport.status = .signedOut
        await pair.bob.verifyAccount()
        #expect(pair.bob.identity == nil)
    }

    @Test(arguments: ["reduce", "remove"], ["switch", "signout"])
    /// Account changes erase calorie cache and retain restrictive work for later retry.
    func accountChangesEraseCardsButRetainRestrictiveWork(action: String, accountChange: String) async throws {

        let pair = try SharingTestPair()
        let id = try await pair.connect(scopes: [.today, .history])
        let historyGrant = try #require(
            pair.alice.connections.first?.grants.first(where: { $0.scope == .history })
        )
        let historyGeneration = historyGrant.generation
        try await pair.alice.takeOverPublisher()
        try await pair.bob.takeOverPublisher()
        try await pair.bob.publish(snapshot: pair.snapshot())
        let yesterday = SharingFixtures.snapshot(
            day: pair.time.now.addingTimeInterval(-24 * 60 * 60),
            capturedAt: pair.time.now,
            includeProjection: false
        )
        try await pair.bob.publish(snapshot: yesterday)
        await pair.alice.refresh()
        #expect(pair.alice.cachedSnapshots.count == 2)
        let (_, unrelatedID) = try await pair.connectAdditionalPeer()
        pair.server.failRevocationDirections = [.incoming]
        pair.server.failCommits = true
        if action == "reduce" { try await pair.alice.changeScopes(connectionID: id, to: [.today]) }
        else { try await pair.alice.remove(connectionID: id) }
        #expect(!pair.alice.pendingRevocations.isEmpty)
        let confirmedOutgoing = pair.server.revocationAttempts.filter { $0.direction == .outgoing }.count
        let other = SharingIdentity(id: "replacement-account", displayName: "Other")
        pair.aliceTransport.status = accountChange == "switch" ? .available(other) : .signedOut
        await pair.alice.verifyAccount()
        #expect(pair.alice.cachedSnapshots.isEmpty)
        #expect(pair.alice.state.pendingMutations.isEmpty)
        let retained = try pair.aliceStore.load(accountID: SharingFixtures.alice.id)
        #expect(retained.snapshots.isEmpty)
        #expect(retained.senderCalendars.isEmpty)
        #expect(retained.senderNameColors.isEmpty)
        #expect(retained.publisherLease == nil)
        #expect(!retained.cleanupPending)
        #expect(retained.connections.map(\.id) == [id])
        #expect(!retained.connections.contains(where: { $0.id == unrelatedID }))
        #expect(retained.connections.allSatisfy { connection in
            connection.proposal == nil
                && connection.publisherGenerations.isEmpty
                && connection.grants.allSatisfy { $0.readyAccountIDs.isEmpty }
        })
        #expect(retained.pendingMutations.count == 1)
        #expect(retained.pendingMutations.allSatisfy { mutation in
            guard mutation.actorID == SharingFixtures.alice.id, mutation.connection.proposal == nil,
                  mutation.connection.publisherGenerations.isEmpty,
                  mutation.connection.grants.allSatisfy({ $0.readyAccountIDs.isEmpty }) else { return false }
            switch mutation.action { case .reduce, .remove: return true; default: return false }
        })
        #expect(!retained.pendingRevocations.isEmpty)
        let historyOutgoingConfirmed = retained.confirmedRevocations.contains { operation in
            operation.scope == .history && operation.generation == historyGeneration && operation.direction == .outgoing
        }
        #expect(historyOutgoingConfirmed)
        #expect(retained.connections.first?.scopes == (action == "reduce" ? [.today] : []))
        pair.server.failCommits = false
        pair.server.failRevocationDirections = []
        pair.aliceTransport.status = .available(SharingFixtures.alice)
        await pair.alice.refresh()
        #expect(pair.alice.pendingRevocations.isEmpty)
        #expect(pair.alice.state.pendingMutations.isEmpty)
        #expect(pair.alice.snapshots(connectionID: id, scope: .history).isEmpty)
        #expect(pair.server.connections[id]?.scopes == (action == "reduce" ? [.today] : []))
        #expect(pair.server.connections[id]?.removed == (action == "remove"))
        let historyIncomingRevoked = pair.server.revoked.contains { operation in
            operation.connectionID == id
                && operation.scope == .history
                && operation.generation == historyGeneration
                && operation.direction == .incoming
        }
        #expect(historyIncomingRevoked)
        #expect(pair.server.revocationAttempts.filter { $0.direction == .outgoing }.count == confirmedOutgoing)
        // bob's separate local store is untouched by alice's account cleanup
        let bobConnections = try pair.bobStore.load(accountID: SharingFixtures.bob.id).connections
        #expect(bobConnections.first?.scopes == [.today, .history])
    }

    @Test
    /// A takeover invalidates the old device and a restored local lease.
    func publisherTakeoverRejectsOldDeviceAndRestoredLease() async throws {

        let pair = try SharingTestPair()
        _ = try await pair.connect(scopes: [.today])
        try await pair.alice.takeOverPublisher()
        let old = try #require(pair.alice.state.publisherLease)
        let next = SharingCoordinator(
            store: try SharingStore(),
            transport: pair.aliceTransport,
            clock: { pair.time.now }
        )
        await next.refresh()
        try await next.takeOverPublisher()
        #expect(next.state.publisherLease?.generation != old.generation)
        await #expect(throws: SharingError.publisherNotOwned) {
            try await pair.alice.publish(snapshot: pair.snapshot())
        }
        let restored = SharingCoordinator(
            store: pair.aliceStore,
            transport: pair.aliceTransport,
            deviceID: pair.alice.deviceID,
            clock: { pair.time.now }
        )
        await restored.verifyAccount()
        #expect(!restored.isPublisher)
        await #expect(throws: SharingError.publisherNotOwned) { try await restored.publish(snapshot: pair.snapshot()) }
    }

    @Test
    /// A queued mutation completes before the suspended refresh returns.
    func mutationDuringASuspendedRefreshRunsItsQueuedWorkBeforeRefreshFinishes() async throws {

        let pair = try SharingTestPair()
        let id = try await pair.connect(scopes: [.today])
        pair.server.pauseNextFetch = true
        let refresh = Task { await pair.bob.refresh() }
        await pair.server.fetchGate.waitUntilSuspended()
        let (entered, signal) = AsyncStream<Void>.makeStream()
        let mutation = Task {
            signal.yield(())
            signal.finish()
            try await pair.bob.changeScopes(connectionID: id, to: [])
        }
        for await _ in entered { break }
        #expect(pair.bob.connections.first?.scopes.isEmpty == true)
        pair.server.fetchGate.resume()
        await refresh.value
        try await mutation.value
        #expect(pair.bob.pendingRevocations.isEmpty)
        #expect(pair.bob.state.pendingMutations.isEmpty)
        #expect(pair.server.connections[id]?.scopes.isEmpty == true)
    }

    @Test
    /// A delayed account check cannot overwrite a newer confirmed identity.
    func staleAccountVerificationCannotUndoAConfirmedSwitch() async throws {

        let pair = try SharingTestPair()
        _ = try await pair.connect(scopes: [.today])
        pair.bobTransport.pauseNextAccountCheck = true
        let oldVerification = Task { await pair.bob.verifyAccount() }
        await pair.bobTransport.accountGate.waitUntilSuspended()
        let other = SharingIdentity(id: "replacement-account", displayName: "Other")
        pair.bobTransport.status = .available(other)
        await pair.bob.verifyAccount()
        #expect(pair.bob.identity?.id == other.id)
        pair.bobTransport.accountGate.resume()
        await oldVerification.value
        #expect(pair.bob.identity?.id == other.id)
        #expect(pair.bob.connections.isEmpty)
        #expect(try pair.bobStore.load(accountID: SharingFixtures.bob.id).connections.isEmpty)
    }

    @Test
    /// A reduction hides cached data and blocks publication while account status is uncertain.
    func offlineReductionImmediatelyPurgesCacheAndBlocksFurtherPublication() async throws {

        let pair = try SharingTestPair()
        let id = try await pair.connect(scopes: [.today])
        try await pair.alice.takeOverPublisher()
        try await pair.bob.takeOverPublisher()
        try await pair.alice.publish(snapshot: pair.snapshot())
        await pair.bob.refresh()
        pair.bobTransport.status = .uncertain
        try await pair.bob.changeScopes(connectionID: id, to: [])
        #expect(pair.bob.cachedSnapshots.isEmpty)
        #expect(pair.bob.pendingRevocations.count == 2)
        #expect(pair.bob.connections.first?.scopes.isEmpty == true)
        await #expect(throws: SharingError.accountUnavailable) { try await pair.bob.publish(snapshot: pair.snapshot()) }
        pair.bobTransport.status = .available(SharingFixtures.bob)
        await pair.bob.retry()
        #expect(pair.bob.pendingRevocations.isEmpty)
        await pair.alice.refresh()
        #expect(pair.alice.connections.first?.scopes.isEmpty == true)
    }

    @Test(arguments: ["decline", "cancel", "expire"])
    /// Decline, cancellation, and expiry preserve Today until fresh consent adds History.
    func expansionAnswersPreserveTodayAndLaterAcceptanceAddsHistory(answer: String) async throws {

        let pair = try SharingTestPair()
        let id = try await pair.connect(scopes: [.today])
        let originalToday = try #require(pair.alice.connections.first?.grants.first(where: { $0.scope == .today }))
        try await pair.alice.takeOverPublisher()
        try await pair.alice.publish(snapshot: pair.snapshot())
        await pair.bob.refresh()
        try await pair.alice.changeScopes(connectionID: id, to: [.today, .history])
        await pair.bob.refresh()
        let requested = try #require(pair.bob.connections.first?.proposal)
        pair.time.now = pair.time.now.addingTimeInterval(60)
        let whileWaiting = pair.snapshot(consumed: 1800)
        try await pair.alice.publish(snapshot: whileWaiting)
        await pair.bob.refresh()
        #expect(pair.bob.snapshots(connectionID: id, scope: .today).first?.snapshot.id == whileWaiting.id)
        #expect(pair.bob.connections.first?.grants.first(where: { $0.scope == .today }) == originalToday)
        #expect(pair.bob.connections.first?.scopes == [.today])
        switch answer {
        case "decline": try await pair.bob.decline(connectionID: id, proposalID: requested.id)
        case "cancel": try await pair.alice.cancel(connectionID: id, proposalID: requested.id)
        default: pair.time.now = requested.expiresAt
        }
        await pair.alice.refresh()
        await pair.bob.refresh()
        #expect(pair.bob.connections.first?.proposal == nil)
        #expect(pair.bob.connections.first?.scopes == [.today])
        #expect(pair.bob.connections.first?.grants.first(where: { $0.scope == .today }) == originalToday)
        pair.time.now = pair.time.now.addingTimeInterval(60)
        let afterAnswer = pair.snapshot(consumed: 1900)
        try await pair.alice.publish(snapshot: afterAnswer)
        await pair.bob.refresh()
        #expect(pair.bob.snapshots(connectionID: id, scope: .today).first?.snapshot.id == afterAnswer.id)
        try await pair.alice.changeScopes(connectionID: id, to: [.today, .history])
        await pair.bob.refresh()
        let renewed = try #require(pair.bob.connections.first?.proposal)
        #expect(renewed.id != requested.id)
        try await pair.bob.accept(connectionID: id, proposalID: renewed.id)
        #expect(pair.server.connections[id]?.isReady(.history) == false)
        await pair.alice.refresh()
        await pair.bob.refresh()
        #expect(pair.bob.connections.first?.isReady(.history) == true)
        #expect(pair.bob.connections.first?.grants.first(where: { $0.scope == .today }) == originalToday)
        let yesterday = SharingFixtures.snapshot(
            day: pair.time.now.addingTimeInterval(-24 * 60 * 60),
            capturedAt: pair.time.now,
            includeProjection: false
        )
        try await pair.alice.publish(snapshot: yesterday)
        await pair.bob.refresh()
        #expect(pair.bob.snapshots(connectionID: id, scope: .history).first?.snapshot.id == yesterday.id)
    }

    @Test
    /// Resuming after pause requires a new grant generation and both readiness receipts.
    func pausedResumptionRequiresFreshConsentAndBothReadinessReceipts() async throws {

        let pair = try SharingTestPair()
        let id = try await pair.connect(scopes: [.today])
        let oldGeneration = try #require(pair.alice.connections.first?.grants.first?.generation)
        try await pair.alice.takeOverPublisher()
        try await pair.alice.publish(snapshot: pair.snapshot())
        await pair.bob.refresh()
        try await pair.alice.changeScopes(connectionID: id, to: [])
        await pair.bob.refresh()
        #expect(pair.bob.cachedSnapshots.isEmpty)
        try await pair.alice.changeScopes(connectionID: id, to: [.today])
        await pair.bob.refresh()
        let resumption = try #require(pair.bob.connections.first?.proposal)
        #expect(resumption.id != oldGeneration)
        try await pair.alice.publish(snapshot: pair.snapshot())
        #expect(pair.server.snapshots.isEmpty)
        pair.server.failProvisionScopes = [.today]
        try await pair.bob.accept(connectionID: id, proposalID: resumption.id)
        await pair.alice.refresh()
        #expect(pair.alice.connections.first?.scopes == [.today])
        #expect(pair.alice.connections.first?.isReady(.today) == false)
        try await pair.alice.publish(snapshot: pair.snapshot())
        #expect(pair.server.snapshots.isEmpty)
        pair.server.failProvisionScopes = []
        await pair.bob.refresh()
        #expect(pair.server.connections[id]?.grants.first?.readyAccountIDs == [SharingFixtures.bob.id])
        #expect(pair.server.connections[id]?.isReady(.today) == false)
        try await pair.alice.publish(snapshot: pair.snapshot())
        #expect(pair.server.snapshots.isEmpty)
        await pair.alice.refresh()
        await pair.bob.refresh()
        #expect(pair.bob.connections.first?.isReady(.today) == true)
        #expect(pair.bob.connections.first?.grants.first?.generation == resumption.id)
        pair.time.now = pair.time.now.addingTimeInterval(60)
        let resumed = pair.snapshot(consumed: 1900)
        try await pair.alice.publish(snapshot: resumed)
        await pair.bob.refresh()
        #expect(pair.bob.snapshots(connectionID: id, scope: .today).first?.snapshot.id == resumed.id)
    }

    @Test
    /// One peer keeps its previous card when another peer receives a newer card.
    func failedPeerPublicationPreservesItsCardWhileHealthyPeerAdvances() async throws {

        let pair = try SharingTestPair()
        let bobID = try await pair.connect(scopes: [.today])
        let (charlie, charlieID) = try await pair.connectAdditionalPeer()
        try await pair.alice.takeOverPublisher()
        let previous = pair.snapshot()
        try await pair.alice.publish(snapshot: previous)
        await pair.bob.refresh()
        await charlie.refresh()
        pair.server.failPublicationConnections = [bobID]
        pair.time.now = pair.time.now.addingTimeInterval(60)
        let newer = pair.snapshot(consumed: 1900)
        await #expect(throws: SharingError.unavailable) { try await pair.alice.publish(snapshot: newer) }
        await pair.bob.refresh()
        await charlie.refresh()
        #expect(pair.bob.snapshots(connectionID: bobID, scope: .today).first?.snapshot.id == previous.id)
        #expect(charlie.snapshots(connectionID: charlieID, scope: .today).first?.snapshot.id == newer.id)
        #expect(pair.server.publicationAttempts.contains(where: {
            $0.connectionID == bobID && $0.snapshot.id == newer.id
        }))
        #expect(pair.server.publicationAttempts.contains(where: {
            $0.connectionID == charlieID && $0.snapshot.id == newer.id
        }))
    }

    @Test
    /// A failed History date does not block a newer Today publication in the same batch.
    func failedHistoricalDateDoesNotSuppressTodayInPublicationBatch() async throws {

        let pair = try SharingTestPair()
        let id = try await pair.connect(scopes: [.today, .history])
        try await pair.alice.takeOverPublisher()
        let previousHistory = SharingFixtures.snapshot(
            day: pair.time.now.addingTimeInterval(-24 * 60 * 60),
            capturedAt: pair.time.now,
            includeProjection: false
        )
        try await pair.alice.publish(snapshots: [previousHistory, pair.snapshot()])
        await pair.bob.refresh()
        pair.time.now = pair.time.now.addingTimeInterval(60)
        let failedHistory = SharingFixtures.snapshot(
            day: previousHistory.dayStart,
            capturedAt: pair.time.now,
            consumed: 1900,
            includeProjection: false
        )
        let newerToday = pair.snapshot(consumed: 1900)
        pair.server.failPublicationDates = [failedHistory.senderLocalDate]
        await #expect(throws: SharingError.unavailable) {
            try await pair.alice.publish(snapshots: [failedHistory, newerToday])
        }
        await pair.bob.refresh()
        #expect(pair.bob.snapshots(connectionID: id, scope: .today).first?.snapshot.id == newerToday.id)
        #expect(pair.bob.snapshots(connectionID: id, scope: .history).first?.snapshot.id == previousHistory.id)
    }

    @Test
    /// An empty publication retries durable cleanup after upload failures.
    func emptyPublicationOpportunityRetriesDurableCleanupAfterEveryUploadFails() async throws {

        let pair = try SharingTestPair()
        _ = try await pair.connect(scopes: [.today])
        try await pair.alice.takeOverPublisher()
        let expired = pair.snapshot()
        try await pair.alice.publish(snapshot: expired)
        pair.time.now = pair.time.now.addingTimeInterval(24 * 60 * 60)
        pair.server.failPublication = true
        pair.server.failCleanup = true
        let attempts = pair.server.cleanupAttempts.count
        await #expect(throws: SharingError.unavailable) { try await pair.alice.publish(snapshots: [pair.snapshot()]) }
        #expect(pair.server.cleanupAttempts.count == attempts + 1)
        #expect(pair.alice.state.cleanupPending)
        #expect(try pair.aliceStore.load(accountID: SharingFixtures.alice.id).cleanupPending)
        #expect(pair.server.snapshots.values.contains(where: { $0.snapshot.id == expired.id }))
        pair.server.failCleanup = false
        try await pair.alice.publish(snapshots: [])
        #expect(!pair.alice.state.cleanupPending)
        #expect(pair.server.cleanupAttempts.count == attempts + 2)
        #expect(!pair.server.snapshots.values.contains(where: { $0.snapshot.id == expired.id }))
    }

    @Test
    /// Cleanup runs only for a verified account that owns publisher authority.
    func nonpublisherAndUnverifiedAccountNeverInvokeCleanup() async throws {

        let pair = try SharingTestPair()
        _ = try await pair.connect(scopes: [.today])
        await pair.alice.refresh()
        #expect(pair.server.cleanupAttempts.isEmpty)
        await #expect(throws: SharingError.publisherNotOwned) { try await pair.alice.cleanupPublishedWindow() }
        await #expect(throws: SharingError.publisherNotOwned) { try await pair.alice.publish(snapshots: []) }
        pair.aliceTransport.status = .uncertain
        await pair.alice.verifyAccount()
        await #expect(throws: SharingError.accountUnavailable) { try await pair.alice.cleanupPublishedWindow() }
        #expect(pair.server.cleanupAttempts.isEmpty)
    }

    @Test
    /// A stale publisher cleanup cannot delete the current publisher Tokyo Today card.
    func queuedOldPublisherCleanupCannotDeleteTheNewPublishersTokyoDay() async throws {

        let pair = try SharingTestPair()
        pair.time.now = ISO8601DateFormatter().date(from: "2026-10-24T09:30:00Z")!
        let id = try await pair.connect(scopes: [.today, .history])
        let honolulu = TimeZone(identifier: "Pacific/Honolulu")!
        let tokyo = TimeZone(identifier: "Asia/Tokyo")!
        pair.aliceTransport.publisherTimeZone = honolulu
        try await pair.alice.takeOverPublisher()
        pair.server.pauseNextCleanup = true
        let queued = Task { () -> SharingError? in
            do { try await pair.alice.cleanupPublishedWindow(); return nil }
            catch let error as SharingError { return error }
            catch { Issue.record("Unexpected cleanup error"); return .unavailable }
        }
        await pair.server.cleanupGate.waitUntilSuspended()
        let newTransport = pair.server.transport(for: SharingFixtures.alice)
        newTransport.publisherTimeZone = tokyo
        let currentPublisher = SharingCoordinator(
            store: try SharingStore(),
            transport: newTransport,
            clock: { pair.time.now }
        )
        await currentPublisher.refresh()
        try await currentPublisher.takeOverPublisher()
        let current = SharingFixtures.snapshot(day: pair.time.now, capturedAt: pair.time.now, timeZone: tokyo)
        try await currentPublisher.publish(snapshot: current)
        #expect(!SharingDateWindow.permits(current, scope: .today, now: pair.time.now, latestSenderTimeZone: honolulu))
        let oldCapture = SharingFixtures.snapshot(
            day: pair.time.now.addingTimeInterval(-48 * 60 * 60),
            capturedAt: pair.time.now.addingTimeInterval(-60),
            timeZone: honolulu,
            includeProjection: false
        )
        try await currentPublisher.publish(snapshot: oldCapture)
        #expect(pair.server.publisherTimeZones[SharingFixtures.alice.id] == tokyo.identifier)
        pair.server.cleanupGate.resume()
        #expect(await queued.value == .publisherNotOwned)
        await #expect(throws: SharingError.publisherNotOwned) { try await pair.alice.cleanupPublishedWindow() }
        await #expect(throws: SharingError.publisherNotOwned) { try await pair.alice.publish(snapshots: []) }
        let attempts = pair.server.cleanupAttempts.count
        await pair.alice.refresh()
        #expect(pair.server.cleanupAttempts.count == attempts)
        #expect(pair.server.snapshots.values.contains(where: {
            $0.connectionID == id && $0.scope == .today && $0.snapshot.id == current.id
        }))
    }

    @Test
    /// A queued upload from the old publisher cannot overwrite the replacement snapshot.
    func queuedPublicationCannotRestoreThePreviousPublisherAfterTakeover() async throws {

        let pair = try SharingTestPair()
        let id = try await pair.connect(scopes: [.today])
        try await pair.alice.takeOverPublisher()
        let oldCard = pair.snapshot()
        pair.server.pauseNextPublication = true
        let queued = Task { () -> SharingError? in
            do { try await pair.alice.publish(snapshot: oldCard); return nil }
            catch let error as SharingError { return error }
            catch { Issue.record("Unexpected publication error"); return .unavailable }
        }
        await pair.server.publicationGate.waitUntilSuspended()
        let replacement = SharingCoordinator(
            store: try SharingStore(),
            transport: pair.server.transport(for: SharingFixtures.alice),
            clock: { pair.time.now }
        )
        await replacement.refresh()
        try await replacement.takeOverPublisher()
        pair.time.now = pair.time.now.addingTimeInterval(60)
        let current = pair.snapshot(consumed: 1900)
        try await replacement.publish(snapshot: current)
        pair.server.publicationGate.resume()
        #expect(await queued.value == .publisherNotOwned)
        await pair.bob.refresh()
        #expect(pair.bob.snapshots(connectionID: id, scope: .today).map(\.snapshot.id) == [current.id])
        #expect(!pair.server.snapshots.values.contains { $0.snapshot.id == oldCard.id })
    }

    @Test
    /// A queued History upload cannot undo a reduction, while Today remains available.
    func queuedHistoryPublicationCannotUndoPeerReductionWhileTodayContinues() async throws {

        let pair = try SharingTestPair()
        let id = try await pair.connect(scopes: [.today, .history])
        try await pair.alice.takeOverPublisher()
        let history = SharingFixtures.snapshot(
            day: pair.time.now.addingTimeInterval(-24 * 60 * 60),
            capturedAt: pair.time.now,
            includeProjection: false
        )
        pair.server.pauseNextPublication = true
        let queued = Task { () -> SharingError? in
            do { try await pair.alice.publish(snapshot: history); return nil }
            catch let error as SharingError { return error }
            catch { Issue.record("Unexpected publication error"); return .unavailable }
        }
        await pair.server.publicationGate.waitUntilSuspended()
        try await pair.bob.changeScopes(connectionID: id, to: [.today])
        pair.server.publicationGate.resume()
        #expect(await queued.value == .staleGeneration)
        #expect(pair.server.snapshots.values.allSatisfy { $0.scope != .history })
        await pair.alice.refresh()
        try await pair.alice.publish(snapshot: pair.snapshot())
        await pair.bob.refresh()
        #expect(pair.bob.snapshots(connectionID: id, scope: .today).count == 1)
        #expect(pair.bob.snapshots(connectionID: id, scope: .history).isEmpty)
    }

    @Test
    /// A delayed cleanup cannot use a publisher time zone that has since changed.
    func queuedCleanupCannotUseTheSamePublishersPreviousTimeZone() async throws {

        let pair = try SharingTestPair()
        pair.time.now = ISO8601DateFormatter().date(from: "2026-10-24T09:30:00Z")!
        let id = try await pair.connect(scopes: [.today])
        let honolulu = TimeZone(identifier: "Pacific/Honolulu")!
        let tokyo = TimeZone(identifier: "Asia/Tokyo")!
        pair.aliceTransport.publisherTimeZone = honolulu
        try await pair.alice.takeOverPublisher()
        pair.server.pauseNextCleanup = true
        let queued = Task { () -> SharingError? in
            do { try await pair.alice.cleanupPublishedWindow(); return nil }
            catch let error as SharingError { return error }
            catch { Issue.record("Unexpected cleanup error"); return .unavailable }
        }
        await pair.server.cleanupGate.waitUntilSuspended()
        pair.aliceTransport.publisherTimeZone = tokyo
        let current = SharingFixtures.snapshot(day: pair.time.now, capturedAt: pair.time.now, timeZone: tokyo)
        try await pair.alice.publish(snapshot: current)
        #expect(!SharingDateWindow.permits(current, scope: .today, now: pair.time.now, latestSenderTimeZone: honolulu))
        pair.server.cleanupGate.resume()
        #expect(await queued.value == .unavailable)
        // the newer publication already completed cleanup using Tokyo
        // a delayed failure must not undo that successful maintenance opportunity
        #expect(!pair.alice.state.cleanupPending)
        #expect(try !pair.aliceStore.load(accountID: SharingFixtures.alice.id).cleanupPending)
        try await pair.alice.publish(snapshots: [])
        #expect(!pair.alice.state.cleanupPending)
        await pair.bob.refresh()
        #expect(pair.bob.snapshots(connectionID: id, scope: .today).map(\.snapshot.id) == [current.id])
    }

    @Test
    /// A History provisioning failure leaves accepted Today updates available.
    func historyProvisionFailureDoesNotInterruptAcceptedTodayRefresh() async throws {

        let pair = try SharingTestPair()
        let id = try await pair.connect(scopes: [.today])
        try await pair.alice.takeOverPublisher()
        try await pair.alice.publish(snapshot: pair.snapshot())
        await pair.bob.refresh()
        try await pair.alice.changeScopes(connectionID: id, to: [.today, .history])
        await pair.bob.refresh()
        let proposal = try #require(pair.bob.connections.first?.proposal)
        pair.server.failProvisionScopes = [.history]
        try await pair.bob.accept(connectionID: id, proposalID: proposal.id)
        await pair.alice.refresh()
        pair.time.now = pair.time.now.addingTimeInterval(60)
        let newer = pair.snapshot(consumed: 1900)
        try await pair.alice.publish(snapshot: newer)
        await pair.bob.refresh()
        #expect(pair.bob.connections.first?.isReady(.today) == true)
        #expect(pair.bob.connections.first?.isReady(.history) == false)
        #expect(pair.bob.snapshots(connectionID: id, scope: .today).first?.snapshot.id == newer.id)
        #expect(pair.bob.snapshots(connectionID: id, scope: .history).isEmpty)
        #expect(pair.bob.lastError != nil)
    }

    @Test
    /// Pending revocation for one peer does not block another peer snapshot refresh.
    func pendingRevocationForOnePeerDoesNotBlockAnotherPeersRefresh() async throws {

        let pair = try SharingTestPair()
        let bobID = try await pair.connect(scopes: [.today, .history])
        let (charlie, charlieID) = try await pair.connectAdditionalPeer()
        try await charlie.takeOverPublisher()
        try await charlie.publish(snapshot: pair.snapshot())
        await pair.alice.refresh()
        pair.bobTransport.status = .uncertain
        pair.server.failRevocationDirections = [.incoming]
        try await pair.alice.changeScopes(connectionID: bobID, to: [.today])
        #expect(pair.alice.pendingRevocations.count == 1)
        pair.time.now = pair.time.now.addingTimeInterval(60)
        let newer = pair.snapshot(consumed: 1900)
        try await charlie.publish(snapshot: newer)
        await pair.alice.refresh()
        #expect(pair.alice.pendingRevocations.first?.connectionID == bobID)
        #expect(pair.alice.pendingRevocations.first?.scope == .history)
        #expect(pair.alice.connections.first(where: { $0.id == bobID })?.scopes == [.today])
        #expect(pair.alice.snapshots(connectionID: charlieID, scope: .today).first?.snapshot.id == newer.id)
    }

    @Test
    /// A failed peer fetch preserves its cache while another peer refreshes.
    func failedSnapshotFetchForOnePeerPreservesItAndRefreshesAnotherPeer() async throws {

        let pair = try SharingTestPair()
        let bobID = try await pair.connect(scopes: [.today])
        let (charlie, charlieID) = try await pair.connectAdditionalPeer()
        try await pair.bob.takeOverPublisher()
        try await charlie.takeOverPublisher()
        let previous = pair.snapshot()
        try await pair.bob.publish(snapshot: previous)
        try await charlie.publish(snapshot: previous)
        await pair.alice.refresh()
        pair.server.failSnapshotConnections = [bobID]
        pair.time.now = pair.time.now.addingTimeInterval(60)
        let newer = pair.snapshot(consumed: 1900)
        try await charlie.publish(snapshot: newer)
        await pair.alice.refresh()
        #expect(pair.alice.snapshots(connectionID: bobID, scope: .today).first?.snapshot.id == previous.id)
        #expect(pair.alice.snapshots(connectionID: charlieID, scope: .today).first?.snapshot.id == newer.id)
        #expect(pair.alice.pendingRevocations.isEmpty)
    }

    @Test
    /// Learned History loss clears only History and retries with its recorded generation.
    func learnedHistoryShareLossClearsOnlyHistoryAndPersistsOriginalGenerationRetries() async throws {

        let pair = try SharingTestPair()
        let id = try await pair.connect(scopes: [.today, .history])
        try await pair.alice.takeOverPublisher()
        try await pair.alice.publish(snapshot: pair.snapshot())
        let yesterday = SharingFixtures.snapshot(
            day: pair.time.now.addingTimeInterval(-24 * 60 * 60),
            capturedAt: pair.time.now,
            includeProjection: false
        )
        try await pair.alice.publish(snapshot: yesterday)
        await pair.bob.refresh()
        #expect(pair.bob.snapshots(connectionID: id, scope: .today).count == 1)
        #expect(pair.bob.snapshots(connectionID: id, scope: .history).count == 1)
        let historyGrant = try #require(
            pair.bob.connections.first?.grants.first(where: { $0.scope == .history })
        )
        let generation = historyGrant.generation
        // the owner phone is offline, so bob can revoke his outgoing share and
        // leave the known incoming share without requiring alice's app to run
        pair.aliceTransport.status = .uncertain
        pair.server.scopeFetchFailures[id] = [.history]
        pair.server.failRevocationDirections = [.incoming]
        await pair.bob.refresh()
        #expect(pair.bob.snapshots(connectionID: id, scope: .history).isEmpty)
        #expect(pair.bob.snapshots(connectionID: id, scope: .today).count == 1)
        #expect(pair.bob.connections.first?.scopes == [.today])
        #expect(pair.bob.pendingRevocations.count == 1)
        #expect(pair.bob.pendingRevocations.first?.scope == .history)
        #expect(pair.bob.pendingRevocations.first?.generation == generation)
        #expect(pair.bob.pendingRevocations.first?.direction == .incoming)
        let confirmedOutgoing = pair.server.revocationAttempts.filter { $0.direction == .outgoing }.count
        let restarted = SharingCoordinator(
            store: pair.bobStore,
            transport: pair.bobTransport,
            deviceID: pair.bob.deviceID,
            clock: { pair.time.now }
        )
        await restarted.verifyAccount()
        #expect(restarted.pendingRevocations.first?.generation == generation)
        pair.server.failRevocationDirections = []
        await restarted.retry()
        #expect(restarted.pendingRevocations.isEmpty)
        #expect(restarted.snapshots(connectionID: id, scope: .today).count == 1)
        #expect(pair.server.revocationAttempts.filter { $0.direction == .outgoing }.count == confirmedOutgoing)
    }

    @Test
    /// A failed network fetch preserves accepted Today and History cache.
    func networkFetchFailurePreservesBothAcceptedScopesAndCache() async throws {

        let pair = try SharingTestPair()
        _ = try await pair.connect(scopes: [.today, .history])
        try await pair.alice.takeOverPublisher()
        try await pair.alice.publish(snapshot: pair.snapshot())
        let yesterday = SharingFixtures.snapshot(
            day: pair.time.now.addingTimeInterval(-24 * 60 * 60),
            capturedAt: pair.time.now,
            includeProjection: false
        )
        try await pair.alice.publish(snapshot: yesterday)
        await pair.bob.refresh()
        pair.server.failFetch = true
        await pair.bob.refresh()
        #expect(pair.bob.connections.first?.scopes == [.today, .history])
        #expect(pair.bob.cachedSnapshots.count == 2)
        #expect(pair.bob.pendingRevocations.isEmpty)
    }

    @Test
    /// A peer removal invalidates an expansion queued during an outage.
    func peerRemovalWinsOverAnOfflineQueuedExpansion() async throws {

        let pair = try SharingTestPair()
        let id = try await pair.connect(scopes: [.today])
        pair.server.failCommits = true
        try await pair.alice.changeScopes(connectionID: id, to: [.today, .history])
        #expect(pair.alice.state.pendingMutations.count == 1)
        pair.server.failCommits = false
        try await pair.bob.remove(connectionID: id)
        await pair.alice.retry()
        #expect(pair.alice.state.pendingMutations.isEmpty)
        #expect(pair.alice.connections.isEmpty)
        #expect(pair.alice.cachedSnapshots.isEmpty)
    }

    @Test
    /// Learned removal clears cached cards and retains cleanup work until success.
    func learnedRemovalRejectsStoredSnapshotsAndCleanupFailurePersists() async throws {

        let pair = try SharingTestPair()
        let id = try await pair.connect(scopes: [.today])
        try await pair.alice.takeOverPublisher()
        try await pair.alice.publish(snapshot: pair.snapshot())
        await pair.bob.refresh()
        #expect(pair.bob.cachedSnapshots.count == 1)
        try await pair.bob.takeOverPublisher()
        pair.server.failCleanup = true
        await pair.bob.refresh()
        await #expect(throws: SharingError.unavailable) { try await pair.bob.cleanupPublishedWindow() }
        #expect(pair.bob.state.cleanupPending)
        #expect(try pair.bobStore.load(accountID: SharingFixtures.bob.id).cleanupPending)
        pair.server.failCleanup = false
        try await pair.alice.remove(connectionID: id)
        await pair.bob.refresh()
        #expect(pair.bob.connections.isEmpty)
        #expect(pair.bob.cachedSnapshots.isEmpty)
        try await pair.bob.cleanupPublishedWindow()
        #expect(!pair.bob.state.cleanupPending)
    }

}

@MainActor
/// Mutable clock shared by protocol tests.
private final class SharingTestTime {

    /// Current timestamp returned by the test clock.
    var now = ISO8601DateFormatter().date(from: "2026-10-24T12:00:00Z")!

}

@MainActor
/// Two-account coordinator fixture backed by one fake service.
private struct SharingTestPair {

    /// Clock shared by both coordinators and the fake service.
    let time: SharingTestTime

    /// Fake service shared by both accounts.
    let server: SharingFakeServer

    /// Local persistence for the first account.
    let aliceStore: SharingStore

    /// Local persistence for the second account.
    let bobStore: SharingStore

    /// Transport authenticated as the first account.
    let aliceTransport: FakeSharingTransport

    /// Transport authenticated as the second account.
    let bobTransport: FakeSharingTransport

    /// Coordinator for the first account.
    let alice: SharingCoordinator

    /// Coordinator for the second account.
    let bob: SharingCoordinator

    /// Creates the shared service, local stores, transports, and coordinators.
    init(aliceStore: SharingStore? = nil) throws {

        let time = SharingTestTime()
        self.time = time
        server = SharingFakeServer(clock: { time.now })
        self.aliceStore = try aliceStore ?? SharingStore()
        bobStore = try SharingStore()
        aliceTransport = server.transport(for: SharingFixtures.alice)
        bobTransport = server.transport(for: SharingFixtures.bob)
        aliceTransport.publisherTimeZone = TimeZone(identifier: "Europe/Zurich")!
        bobTransport.publisherTimeZone = TimeZone(identifier: "Europe/Zurich")!
        alice = SharingCoordinator(store: self.aliceStore, transport: aliceTransport, clock: { time.now })
        bob = SharingCoordinator(store: bobStore, transport: bobTransport, clock: { time.now })
    }

    /// Creates a connection and waits for both accounts to report readiness.
    func connect(scopes: Set<SharingScope>) async throws -> UUID {

        await alice.verifyAccount()
        let id = try await alice.propose(to: SharingFixtures.bob, scopes: scopes)
        await bob.refresh()
        let proposal = try #require(bob.connections.first?.proposal)
        try await bob.accept(connectionID: id, proposalID: proposal.id)
        await alice.refresh()
        await bob.refresh()
        #expect(alice.connections.first?.scopes == scopes)
        #expect(scopes.allSatisfy { bob.connections.first?.isReady($0) == true })
        return id
    }

    /// Adds a third account to the shared fake service.
    func connectAdditionalPeer() async throws -> (SharingCoordinator, UUID) {

        let identity = SharingIdentity(id: "fixture-charlie", displayName: "Charlie")
        let peer = SharingCoordinator(
            store: try SharingStore(),
            transport: server.transport(for: identity),
            clock: { time.now }
        )
        let id = try await alice.propose(to: identity)
        await peer.refresh()
        let proposal = try #require(peer.connections.first?.proposal)
        try await peer.accept(connectionID: id, proposalID: proposal.id)
        await alice.refresh()
        await peer.refresh()
        return (peer, id)
    }

    /// Builds a Now and Midnight snapshot with the supplied energy totals.
    func snapshot(active: Int = 400, resting: Int = 1400, consumed: Int = 1700) -> CalorieCardSnapshot {
        let original = SharingFixtures.snapshot(day: time.now, capturedAt: time.now)
        let energy = EnergyBalance(active: active, resting: resting, consumed: consumed)
        let values = CalorieCardSnapshot.ModeValues(energy: energy, visibleGoalReached: nil)
        return CalorieCardSnapshot(
            senderLocalDate: original.senderLocalDate,
            timeZoneIdentifier: original.timeZoneIdentifier,
            dayStart: original.dayStart,
            dayEnd: original.dayEnd,
            capturedAt: time.now,
            now: values,
            midnight: values,
            energyUnit: original.energyUnit,
            appearance: original.appearance
        )
    }
}
