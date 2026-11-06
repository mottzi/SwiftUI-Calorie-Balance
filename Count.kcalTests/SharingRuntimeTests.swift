import Foundation
import CloudKit
import HealthKit
import SwiftUI
import Testing
import Dependencies
import SQLiteData
@testable import Count_kcal

@Suite(.serialized, .timeLimit(.minutes(1)))
@MainActor
/// Runtime tests for action overlap, removal, and publication coordination.
struct SharingRuntimeTests {

    init() throws {
        let database = try AppDatabase.makeDatabase(path: nil)
        prepareDependencies { $0.defaultDatabase = database }
    }

    @Test
    func permissionRequestDoesNotLockTheSheetWhileSyncIsHeld() async throws {
        let session = try RuntimeSession()
        defer { session.cleanUp() }
        let id = try await session.connect(scopes: [.today, .history])
        var draft = SharingPermissionDraft(connection: try #require(session.alice.connections.first),
                                           accountID: SharingFixtures.alice.id)
        draft.goals = true
        let scopes = draft.scopes
        session.server.pauseNextFetch = true
        let saved = session.runtime.applyPermissionChange(on: session.alice) {
            try session.alice.enqueueScopeChange(connectionID: id, to: scopes)
        }
        #expect(saved)
        if saved {
            draft = SharingPermissionDraft(connection: try #require(session.alice.connections.first),
                                           accountID: SharingFixtures.alice.id)
        }
        await session.server.fetchGate.waitUntilSuspended()
        #expect(session.alice.connections.first?.proposal?.scopes == scopes)
        #expect(!session.runtime.isWorking)
        let current = try #require(session.alice.connections.first)
        #expect(!draft.isEdited && draft.matches(current))
        let proposal = try #require(draft.proposal)
        #expect(session.runtime.applyPermissionChange(on: session.alice) {
            try session.alice.enqueueCancellation(connectionID: id, proposalID: proposal.id)
        })
        #expect(!session.runtime.isWorking)
        #expect(session.alice.connections.first?.proposal == nil)
        #expect(try SharingStore(path: session.database.path).load(accountID: SharingFixtures.alice.id).pendingMutations.contains {
            if case .cancel = $0.action { return true }; return false
        })
        session.server.fetchGate.resume()
        await session.alice.refresh(.changed)
        #expect(session.server.connections[id]?.proposal == nil)
    }

    @Test
    func acceptingRequestCompletesBeforeNetworkRefresh() async throws {
        let session = try RuntimeSession()
        defer { session.cleanUp() }
        await session.bob.verifyAccount()
        let id = try await session.bob.propose(to: SharingFixtures.alice, scopes: [.today, .goals])
        await session.alice.refresh()
        let proposal = try #require(session.alice.connections.first?.proposal)
        session.server.pauseNextFetch = true
        let accepted = session.runtime.applyPermissionChange(on: session.alice) {
            try session.alice.enqueueAcceptance(connectionID: id, proposalID: proposal.id)
        }
        #expect(accepted)
        let saved = try SharingStore(path: session.database.path).load(accountID: SharingFixtures.alice.id)
        #expect(saved.pendingMutations.contains {
            if case .accept(let id) = $0.action { return id == proposal.id }; return false
        })
        await session.server.fetchGate.waitUntilSuspended()
        #expect(accepted)
        #expect(!session.runtime.isWorking)
        session.server.fetchGate.resume()
        await session.alice.refresh(.changed)
        #expect(session.alice.isPublisher)
        #expect(session.server.connections[id]?.scopes == [.today, .goals])
        #expect(session.alice.state.pendingMutations.isEmpty)
    }

    @Test
    func savedAcceptanceRetriesAfterRelaunchAndPreservesThePublisher() async throws {
        let session = try RuntimeSession()
        defer { session.cleanUp() }
        await session.bob.verifyAccount()
        let id = try await session.bob.propose(to: SharingFixtures.alice, scopes: [.today])
        await session.alice.refresh()
        let proposal = try #require(session.alice.connections.first?.proposal)
        session.server.failCommits = true
        try session.alice.enqueueAcceptance(connectionID: id, proposalID: proposal.id)
        await session.alice.refresh(.changed)
        #expect(session.alice.state.pendingMutations.count == 1)
        let lease = try #require(session.server.leases[SharingFixtures.alice.id])
        let restored = SharingCoordinator(
            store: try SharingStore(path: session.database.path),
            transport: session.server.transport(for: SharingFixtures.alice),
            deviceID: session.alice.deviceID
        )
        session.server.failCommits = false
        await restored.refresh(.changed)
        #expect(restored.state.pendingMutations.isEmpty)
        #expect(session.server.connections[id]?.scopes == [.today])
        #expect(session.server.leases[SharingFixtures.alice.id] == lease)
    }

    @Test
    func queuedAcceptanceDoesNotReplaceAnotherPublishingIPhone() async throws {
        let session = try RuntimeSession()
        defer { session.cleanUp() }
        await session.bob.verifyAccount()
        let id = try await session.bob.propose(to: SharingFixtures.alice)
        await session.alice.refresh()
        let proposal = try #require(session.alice.connections.first?.proposal)
        let other = SharingCoordinator(store: try SharingStore(),
                                       transport: session.server.transport(for: SharingFixtures.alice))
        await other.verifyAccount()
        try await other.preparePublisher()
        let lease = try #require(session.server.leases[SharingFixtures.alice.id])
        try session.alice.enqueueAcceptance(connectionID: id, proposalID: proposal.id)
        await session.alice.refresh(.changed)
        #expect(session.alice.refreshFailure as? SharingError == .publisherNotOwned)
        #expect(session.alice.state.pendingMutations.count == 1)
        #expect(session.server.connections[id]?.proposal?.id == proposal.id)
        #expect(session.server.leases[SharingFixtures.alice.id] == lease)
    }

    @Test
    func pendingDraftPreservesRequestedScopesWhenAddingAnotherOption() async throws {
        let session = try RuntimeSession()
        defer { session.cleanUp() }
        let id = try await session.connect(scopes: [.history])
        try await session.alice.changeScopes(connectionID: id, to: [.today, .history])
        let connection = try #require(session.alice.connections.first)
        var draft = SharingPermissionDraft(connection: connection, accountID: SharingFixtures.alice.id)
        #expect(draft.today && draft.history && !draft.goals)
        #expect(!draft.isEdited)
        draft.goals = true
        #expect(draft.isEdited)
        #expect(draft.matches(connection))
        try await session.alice.changeScopes(connectionID: id, to: draft.scopes)
        #expect(session.server.connections[id]?.proposal?.scopes == [.today, .history, .goals])
        #expect(session.alice.connections.first?.scopes == [.history])
        #expect(!draft.matches(try #require(session.alice.connections.first)))
    }

    @Test
    func permissionDraftDetectsAcceptanceAndKeepsImmediateReductions() async throws {
        let session = try RuntimeSession()
        defer { session.cleanUp() }
        let id = try await session.connect(scopes: [.today, .history])
        try await session.alice.changeScopes(connectionID: id, to: [.today, .history, .goals])
        let connection = try #require(session.alice.connections.first)
        var draft = SharingPermissionDraft(connection: connection, accountID: SharingFixtures.alice.id)
        draft.history = false
        #expect(draft.reductions == [.history])
        #expect(draft.scopes == [.today, .goals])
        await session.bob.refresh()
        try await session.bob.accept(connectionID: id, proposalID: try #require(connection.proposal).id)
        await session.alice.refresh()
        #expect(!draft.matches(try #require(session.alice.connections.first)))
        let current = SharingPermissionDraft(connection: try #require(session.alice.connections.first), accountID: SharingFixtures.alice.id)
        #expect(!current.isEdited)
        #expect(current.acceptedScopes == [.today, .history, .goals])
    }

    @Test
    func neverAcceptedRequestsStayOutOfPeopleAndAllowAnotherInvitation() async throws {
        for decline in [false, true] {
            let session = try RuntimeSession()
            defer { session.cleanUp() }
            await session.alice.verifyAccount()
            let id = try await session.alice.propose(to: SharingFixtures.bob)
            #expect(session.runtime.people.isEmpty)
            #expect(session.alice.connections.first?.blocksNewInvitation == true)
            let proposal = try #require(session.alice.connections.first?.proposal)
            if decline {
                await session.bob.refresh()
                try await session.bob.decline(connectionID: id, proposalID: proposal.id)
                await session.alice.refresh()
            } else {
                try await session.alice.cancel(connectionID: id, proposalID: proposal.id)
            }
            #expect(session.runtime.people.isEmpty)
            // The native CloudKit binding and coordinator share this duplicate rule.
            #expect(session.alice.connections.first?.blocksNewInvitation == false)
            let next = try await session.alice.propose(to: SharingFixtures.bob)
            #expect(next != id)
            #expect(session.runtime.people.isEmpty)
        }
    }

    @Test
    func genuinelyPausedPeopleRemainVisible() async throws {
        let session = try RuntimeSession()
        defer { session.cleanUp() }
        let id = try await session.connect(scopes: [.today])
        try await session.alice.changeScopes(connectionID: id, to: [])
        #expect(session.runtime.people.map(\.id) == [id])
        #expect(session.alice.connections.first?.firstAcceptedAt != nil)
        #expect(session.alice.connections.first?.blocksNewInvitation == true)
        try await session.alice.remove(connectionID: id)
        #expect(session.server.connections[id]?.blocksNewInvitation == false)
    }

    @Test
    func reopenedInvitationRoutesAcceptedPausedAndRemovedConnections() async throws {
        let session = try RuntimeSession()
        defer { session.cleanUp() }
        let id = try await session.connect(scopes: [.today])
        session.runtime.receivedInvitationID = id
        #expect(session.runtime.receivedInvitationState == .connected(id))
        try await session.alice.changeScopes(connectionID: id, to: [])
        #expect(session.runtime.receivedInvitationState == .connected(id))
        await session.bob.refresh()
        try await session.bob.changeScopes(connectionID: id, to: [.history])
        await session.alice.refresh()
        #expect(session.runtime.receivedInvitationState == .request(id))
        let proposal = try #require(session.alice.connections.first?.proposal)
        try await session.alice.decline(connectionID: id, proposalID: proposal.id)
        #expect(session.runtime.receivedInvitationState == .connected(id))
        try await session.alice.remove(connectionID: id)
        #expect(session.runtime.receivedInvitationState == .unavailable)
        session.runtime.receivedInvitationID = UUID()
        #expect(session.runtime.receivedInvitationState == .unavailable)
    }

    @Test
    func reopenedDeclinedInitialInvitationIsUnavailable() async throws {
        let session = try RuntimeSession()
        defer { session.cleanUp() }
        await session.bob.verifyAccount()
        let id = try await session.bob.propose(to: SharingFixtures.alice)
        await session.alice.refresh()
        session.runtime.receivedInvitationID = id
        #expect(session.runtime.receivedInvitationState == .request(id))
        let proposal = try #require(session.alice.connections.first?.proposal)
        try await session.alice.decline(connectionID: id, proposalID: proposal.id)
        #expect(session.runtime.receivedInvitationState == .unavailable)
    }

    @Test
    func senderStreakUsesFullHistoryAndExcludedDaysIndependentlyOfViewerIcons() async throws {
        let settings = Settings.shared
        let original = (settings.hideCalorieStatusIcons, settings.balanceGoal, settings.weightGoal,
                        settings.dataSource, settings.energyUnit)
        defer {
            settings.hideCalorieStatusIcons = original.0
            settings.balanceGoal = original.1
            settings.weightGoal = original.2
            settings.dataSource = original.3
            settings.energyUnit = original.4
        }
        settings.hideCalorieStatusIcons = false
        settings.balanceGoal = 300
        settings.weightGoal = .lose
        settings.dataSource = .apple
        settings.energyUnit = .kcal
        let session = try RuntimeSession(source: ConsistentStreakHealthSource())
        defer { session.cleanUp() }
        let id = try await session.connect(scopes: [.goals])
        try await session.alice.takeOverPublisher()
        let full = try #require(await SharingStreakBuilder.build(repository: session.repository, settings: settings,
                                                                choices: [], sampleData: false))
        #expect(full.days == 200)
        let excludedDate = Calendar.current.date(byAdding: .day, value: -3, to: Date.now)!
        let choices = [StoredDayChoice(id: AppDatabase.recordID(for: excludedDate, sampleData: false),
                                      choice: DayChoice.excluded.rawValue)]
        let shortened = try #require(await SharingStreakBuilder.build(repository: session.repository, settings: settings,
                                                                     choices: choices, sampleData: false))
        #expect(shortened.days == 2)
        await session.runtime.publishCurrentWindow(settings: settings)
        await session.bob.refresh()
        #expect(session.bob.streak(connectionID: id)?.days == 200)
        #expect(session.server.publicationAttempts.allSatisfy { $0.scope == .goals && $0.snapshot.now.energy.isEmpty })
        settings.hideCalorieStatusIcons = true
        await session.runtime.publishCurrentWindow(settings: settings)
        await session.bob.refresh()
        #expect(session.bob.streak(connectionID: id)?.days == 200)
        let summary = try #require(session.bob.snapshots(connectionID: id, scope: .goals).first)
        #expect(summary.snapshot.goalResult == nil)
        #expect(summary.snapshot.now.energy.isEmpty)
    }

    @Test
    func fourSamplePeopleStayAlongsideRealConnectionWithoutChangingItsStore() async throws {
        let session = try RuntimeSession()
        defer { session.cleanUp() }
        let id = try await session.connect(scopes: [.today])
        let before = session.alice.state
        @Bindable var runtime = session.runtime
        $runtime.samplePeopleEnabled.wrappedValue.toggle()
        await session.runtime.refreshSamplePeople()
        #expect(session.runtime.people.count == 5)
        #expect(session.runtime.people.filter(\.isSample).count == 4)
        #expect(session.runtime.people.contains { $0.id == id && !$0.isSample })
        #expect(session.alice.state == before)
        #expect(try SharingStore(path: session.database.path).load(accountID: SharingFixtures.alice.id) == before)
        #expect(session.server.connections.count == 1)
        #expect(session.server.publicationAttempts.isEmpty)
        let themes = ["Jonas": 1, "Lea": 3, "Noah": 5, "Maya": 8]
        let backgrounds: [String: Settings.AppBackgrounds] = ["Jonas": .black, "Lea": .dark, "Noah": .dark, "Maya": .light]
        #expect(Set(session.runtime.people.filter(\.isSample).map(\.name)) == Set(themes.keys))
        #expect(session.runtime.people.filter(\.isSample).map(\.name) == ["Lea", "Jonas", "Maya", "Noah"])
        for person in session.runtime.people.filter(\.isSample) {
            let theme = Settings.Themes[try #require(themes[person.name]) - 1]
            let snapshot = try #require(person.coordinator.snapshots(connectionID: person.id, scope: .today).first?.snapshot)
            #expect(snapshot.appearance.burned == CalorieCardSnapshotBuilder.adaptive(theme.burned))
            #expect(snapshot.appearance.consumed == CalorieCardSnapshotBuilder.adaptive(theme.consumed))
            let background = try #require(backgrounds[person.name])
            #expect(snapshot.appearance.cardBackground == CalorieCardSnapshotBuilder.adaptive(background.cardColor))
            #expect(snapshot.appearance.pageBackground == CalorieCardSnapshotBuilder.adaptive(background.pageColor))
            let normalAppearance = CalorieCardSnapshotBuilder.appearance(settings: .shared, background: background)
            #expect(snapshot.appearance.graphEmpty == normalAppearance.graphEmpty)
            #expect(snapshot.appearance.labelBackground == normalAppearance.labelBackground)
            #expect(person.connection.scopes == [.today, .history, .goals])
            #expect(person.coordinator.streak(connectionID: person.id) != nil)
            #expect(snapshot.streak == nil)
            #expect(person.coordinator.snapshots(connectionID: person.id, scope: .today).count == 1)
            #expect(person.coordinator.snapshots(connectionID: person.id, scope: .history).count == 6)
        }
        let restored = SharingRuntime(coordinator: session.alice, store: try SharingStore(),
                                      repository: session.repository, defaults: session.defaults)
        #expect(restored.samplePeopleEnabled)
        await restored.refreshSamplePeople()
        #expect(restored.people.count == 5)
        session.runtime.samplePeopleEnabled = false
        await session.runtime.refreshSamplePeople()
        #expect(session.runtime.people.map(\.id) == [id])
        #expect(session.runtime.samplePeople == nil)
        #expect(!session.defaults.bool(forKey: "sharing.debugSamplePeople"))
        #expect(session.alice.state == before)
    }

    @Test
    func samplePeopleKeepActionsLocalAlongsideRealConnections() async throws {
        let session = try RuntimeSession()
        defer { session.cleanUp() }
        let realID = try await session.connect(scopes: [.today])
        let before = session.alice.state
        session.runtime.samplePeopleEnabled = true
        await session.runtime.refreshSamplePeople()
        let person = try #require(session.runtime.people.first(where: { $0.isSample }))
        #expect(await session.runtime.perform(on: person.coordinator) {
            try await person.coordinator.changeScopes(connectionID: person.id, to: [])
        })
        #expect(person.coordinator.snapshots(connectionID: person.id, scope: .today).isEmpty)
        #expect(await session.runtime.perform(on: person.coordinator) {
            try await person.coordinator.changeScopes(connectionID: person.id, to: [.history])
        })
        #expect(person.coordinator.snapshots(connectionID: person.id, scope: .history).count == 6)
        #expect(await session.runtime.perform(on: person.coordinator) {
            try await person.coordinator.remove(connectionID: person.id)
        })
        #expect(!session.runtime.people.contains { $0.id == person.id })
        #expect(session.runtime.people.count == 5)
        #expect(session.alice.state == before)
        #expect(session.server.publicationAttempts.isEmpty)
        let samples = try #require(session.runtime.samplePeople)
        try await samples.refresh()
        #expect(samples.coordinator.connections.count == 4)
        #expect(await session.runtime.perform(on: session.alice) {
            try await session.alice.remove(connectionID: realID)
        })
        #expect(session.runtime.people.count == 4)
        #expect(session.runtime.people.allSatisfy { $0.isSample })
        session.runtime.samplePeopleEnabled = false
        await session.runtime.refreshSamplePeople()
    }

    @Test
    func samplePeopleHaveDistinctRepeatableSupportedHistories() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Zurich"))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 18)))
        let histories = SampleHealthProfile.allCases.map {
            SharingSamplePeople.snapshots(profile: $0, now: now, calendar: calendar)
        }
        #expect(Set(histories.compactMap { $0.first?.now.consumed }).count == 4)
        for (index, history) in histories.enumerated() {
            #expect(history.count == 7)
            #expect(history.allSatisfy { $0.isSupported })
            #expect(history == SharingSamplePeople.snapshots(profile: SampleHealthProfile.allCases[index], now: now, calendar: calendar))
            #expect(history.first?.midnight != nil)
            #expect(history.dropFirst().allSatisfy { $0.midnight == nil })
        }
    }

    @Test
    /// Keeps cancelled delivery preparation free of CloudKit saves and reuses saved metadata.
    func invitationPreparationIsLazyAndReusesItsSavedShare() async throws {

        var saves = 0
        let share = CKShare(rootRecord: CKRecord(recordType: "Setup"))
        let container = CKContainer(identifier: CloudKitSharingTransport.containerIdentifier)
        let id = UUID()
        let invitation = SharingCloudInvitation(id: id, container: container) {
            saves += 1
            return share
        }
        #expect(saves == 0)
        #expect(invitation.share == nil)
        #expect(invitation.id == id)
        #expect(try await invitation.prepareShare() === share)
        #expect(try await invitation.prepareShare() === share)
        #expect(saves == 1)
        #expect(invitation.share === share)
    }

    @Test
    /// Gives simultaneous native preparation callbacks the same saved invitation.
    func invitationPreparationCoalescesOverlappingCallbacks() async throws {

        let gate = SharingFakeGate()
        var saves = 0
        let share = CKShare(rootRecord: CKRecord(recordType: "Setup"))
        let invitation = SharingCloudInvitation(
            id: UUID(),
            container: CKContainer(identifier: CloudKitSharingTransport.containerIdentifier)
        ) {
            saves += 1
            await gate.suspend()
            return share
        }
        let first = Task { try await invitation.prepareShare() }
        await gate.waitUntilSuspended()
        let second = Task { try await invitation.prepareShare() }
        await Task.yield()
        gate.resume()
        #expect(try await first.value === share)
        #expect(try await second.value === share)
        #expect(saves == 1)
    }

    @Test
    /// Retries a failed preparation without changing the invitation identity.
    func invitationPreparationRetriesFailureWithTheSameIdentity() async throws {

        var attempts = 0
        let share = CKShare(rootRecord: CKRecord(recordType: "Setup"))
        let id = UUID()
        let invitation = SharingCloudInvitation(
            id: id,
            container: CKContainer(identifier: CloudKitSharingTransport.containerIdentifier)
        ) {
            attempts += 1
            if attempts == 1 { throw SharingError.unavailable }
            return share
        }
        await #expect(throws: SharingError.unavailable) { try await invitation.prepareShare() }
        #expect(invitation.share == nil)
        #expect(try await invitation.prepareShare() === share)
        #expect(attempts == 2)
        #expect(invitation.id == id)
    }

    @available(iOS 18.0, *)
    @Test
    /// Rejects public access, extra recipients, changed recipients, and inaccessible setup permissions.
    func nativeInvitationRequiresOnePrivateRecipient() throws {

        #expect(try SharingCloudInvitation.recipient(in: [], publicPermission: .none, expectedID: nil) == nil)
        let peer = CKShare.Participant.oneTimeURLParticipant()
        peer.permission = .readWrite
        let recipient = try SharingCloudInvitation.recipient(
            in: [peer], publicPermission: .none, expectedID: peer.participantID
        )
        #expect(recipient?.participantID == peer.participantID)
        #expect(throws: SharingError.wrongAccount) {
            try SharingCloudInvitation.recipient(in: [peer], publicPermission: .none, expectedID: "another-participant")
        }
        let extra = CKShare.Participant.oneTimeURLParticipant()
        extra.permission = .readWrite
        #expect(throws: SharingError.multipleRecipients) {
            try SharingCloudInvitation.recipient(in: [peer, extra], publicPermission: .none, expectedID: nil)
        }
        peer.permission = .readOnly
        #expect(try SharingCloudInvitation.recipient(
            in: [peer], publicPermission: .none, expectedID: peer.participantID
        )?.participantID == peer.participantID)
        peer.permission = .none
        #expect(throws: SharingError.wrongAccount) {
            try SharingCloudInvitation.recipient(in: [peer], publicPermission: .none, expectedID: nil)
        }
        #expect(throws: SharingError.invalidConnection) {
            try SharingCloudInvitation.recipient(in: [], publicPermission: .readOnly, expectedID: nil)
        }
    }

    @Test
    /// Returns failure so an action sheet can retain its draft for retry.
    func failedActionsReportFailureWithoutLeavingTheRuntimeBusy() async throws {

        let session = try RuntimeSession()
        defer { session.cleanUp() }
        let completed = await session.runtime.perform { throw SharingError.unavailable }
        #expect(!completed)
        #expect(!session.runtime.isWorking)
        #expect(session.runtime.actionError != nil)
        #expect(await session.runtime.perform { })
        #expect(session.runtime.actionError == nil)
        await session.runtime.publishCurrentWindow(settings: .shared)
    }

    @Test
    /// Rejects invalid names and saves only the committed trimmed name.
    func profileDraftValidationPreservesTheSavedName() async throws {

        let session = try RuntimeSession()
        defer { session.cleanUp() }
        #expect(!(await session.runtime.saveName("   ")))
        #expect(!(await session.runtime.saveName(String(repeating: "a", count: 81))))
        #expect(session.runtime.displayName == "Alice")
        #expect(await session.runtime.saveName("  Alice Example  "))
        #expect(session.runtime.displayName == "Alice Example")
        #expect(session.defaults.string(forKey: "sharing.displayName") == "Alice Example")
        await session.runtime.publishCurrentWindow(settings: .shared)
    }

    @Test
    /// Submits History alone without adding Today or claiming another phone's lease.
    func invitationPreservesIndependentScopeSelection() async throws {

        let session = try RuntimeSession()
        defer { session.cleanUp() }
        await session.alice.verifyAccount()
        let runtime = SharingRuntime(coordinator: session.alice, store: try SharingStore(),
                                     repository: session.repository, defaults: session.defaults, isFixture: true)
        #expect(!(await runtime.invite(scopes: [])))
        #expect(session.server.leases.isEmpty)
        #expect(await runtime.invite(scopes: [.history]))
        #expect(runtime.invitationCreated)
        #expect(session.alice.connections.first?.proposal?.scopes == [.history])
        #expect(session.alice.isPublisher)
    }

    @Test
    /// Verifies that distinct actions run at once and keep the busy state active.
    func distinctActionsRunImmediatelyAndBusyLastsUntilBothFinish() async throws {

        let session = try RuntimeSession()
        defer { session.cleanUp() }
        let firstGate = SharingFakeGate(), secondGate = SharingFakeGate()
        let first = Task { await session.runtime.perform { await firstGate.suspend() } }
        await firstGate.waitUntilSuspended()
        #expect(session.runtime.isWorking)
        let second = Task { await session.runtime.perform { await secondGate.suspend() } }
        await secondGate.waitUntilSuspended()
        firstGate.resume()
        _ = await first.value
        #expect(session.runtime.isWorking)
        secondGate.resume()
        _ = await second.value
        #expect(!session.runtime.isWorking)
        await session.runtime.publishCurrentWindow(settings: .shared)
    }

    @Test
    /// Verifies that removal hides cards and stores revocations during other work.
    func removalHidesCardsAndPersistsBeforeUnrelatedWorkFinishes() async throws {

        let session = try RuntimeSession()
        defer { session.cleanUp() }
        let id = try await session.connect(scopes: [.today])
        try await session.bob.takeOverPublisher()
        try await session.bob.publish(snapshot: SharingFixtures.snapshot(day: .now, capturedAt: .now, timeZone: .current))
        await session.alice.refresh()
        #expect(session.alice.cachedSnapshots.count == 1)
        let gate = SharingFakeGate()
        let unrelated = Task { await session.runtime.perform { await gate.suspend() } }
        await gate.waitUntilSuspended()
        session.server.failCommits = true
        session.server.failRevocationDirections = [.outgoing, .incoming]
        await session.runtime.perform { try await session.alice.remove(connectionID: id) }
        #expect(session.runtime.isWorking)
        #expect(session.alice.cachedSnapshots.isEmpty)
        let restored = try SharingStore(path: session.database.path).load(accountID: SharingFixtures.alice.id)
        #expect(restored.snapshots.isEmpty)
        #expect(restored.connections.first?.removed == true)
        #expect(restored.pendingMutations.count == 1)
        #expect(Set(restored.pendingRevocations.map(\.direction)) == [.outgoing, .incoming])
        gate.resume()
        _ = await unrelated.value
        #expect(!session.runtime.isWorking)
        await session.runtime.publishCurrentWindow(settings: .shared)
    }

    @Test
    /// Verifies that invitation handoff work enters while another action is suspended.
    func invitationHandoffWorkIsNotDroppedDuringAnotherAction() async throws {

        let session = try RuntimeSession()
        defer { session.cleanUp() }
        let gate = SharingFakeGate()
        let unrelated = Task { await session.runtime.perform { await gate.suspend() } }
        await gate.waitUntilSuspended()
        // invitation import enters the same perform interface; this checks handoff without a real CloudKit import
        var receivedURL: URL?
        let invitation = URL(string: "https://www.icloud.com/share/test-handoff")!
        await session.runtime.perform { receivedURL = invitation }
        #expect(receivedURL == invitation)
        #expect(session.runtime.isWorking)
        gate.resume()
        _ = await unrelated.value
        #expect(!session.runtime.isWorking)
        await session.runtime.publishCurrentWindow(settings: .shared)
    }

    @Test
    /// Verifies that foreground refresh does not schedule a delayed duplicate publication.
    func foregroundRefreshPublishesOnceWithoutADelayedDuplicate() async throws {

        let session = try RuntimeSession()
        defer { session.cleanUp() }
        _ = try await session.connect(scopes: [.today])
        try await session.alice.takeOverPublisher()
        await session.runtime.refreshIfUsed(settings: .shared)
        #expect(session.server.publicationAttempts.count == 1)
        // keep the event loop running past the debounce deadline; the former refresh/start chain added a second pass
        try await Task.sleep(for: .milliseconds(600))
        #expect(session.server.publicationAttempts.count == 1)
    }

    @Test
    /// Finishes a visible refresh while an outgoing CloudKit upload remains suspended.
    func pullRefreshDoesNotWaitForOutgoingPublication() async throws {

        let session = try RuntimeSession()
        defer { session.cleanUp() }
        let id = try await session.connect(scopes: [.today])
        try await session.bob.takeOverPublisher()
        try await session.bob.publish(snapshot: SharingFixtures.snapshot(day: .now, capturedAt: .now, timeZone: .current))
        try await session.alice.takeOverPublisher()
        await Settings.shared.updateShow(repository: session.repository)
        session.server.pauseNextPublication = true
        let publication = Task { await session.runtime.publishCurrentWindow(settings: .shared) }
        await session.server.publicationGate.waitUntilSuspended()

        var refreshFinished = false
        let refresh = Task {
            await session.runtime.refresh()
            refreshFinished = true
        }
        // bound the assertion so a failure does not leave the upload suspended
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while !refreshFinished && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(refreshFinished, "Pull-to-refresh must finish before the outgoing upload is released")
        #expect(session.alice.snapshots(connectionID: id, scope: .today).count == 1)
        session.server.publicationGate.resume()
        await publication.value
        await refresh.value
    }

    @Test
    /// Incoming reconciliation does not start uploads or retention network work.
    func incomingRefreshLeavesCleanupForPublication() async throws {
        let session = try RuntimeSession()
        defer { session.cleanUp() }
        _ = try await session.connect(scopes: [.today])
        try await session.alice.takeOverPublisher()
        await session.runtime.refresh()
        #expect(session.server.publicationAttempts.isEmpty)
        #expect(try SharingStore(path: session.database.path).load(accountID: SharingFixtures.alice.id).cleanupPending)
        await session.runtime.publishCurrentWindow(settings: .shared)
        #expect(!session.alice.state.cleanupPending)
    }

    @Test
    /// Discards a changed health batch but still attempts fenced retention cleanup.
    func changedHealthPolicyDoesNotSkipCleanup() async throws {

        let settings = Settings.shared
        let original = settings.customCalActive
        defer { settings.customCalActive = original }
        let source = PolicyChangingHealthSource { settings.customCalActive = original + 1 }
        let session = try RuntimeSession(source: source)
        defer { session.cleanUp() }
        _ = try await session.connect(scopes: [.today])
        try await session.alice.takeOverPublisher()
        await session.runtime.publishCurrentWindow(settings: settings)
        #expect(settings.customCalActive == original + 1)
        #expect(session.server.publicationAttempts.isEmpty)
        #expect(session.server.cleanupAttempts.count == 1)
        #expect(!session.alice.state.cleanupPending)
    }

    @Test
    /// Verifies that overlapping triggers await the upload for the latest visibility policy.
    func overlappingTriggersCoalesceAndAllCallersAwaitLatestPolicy() async throws {

        let session = try RuntimeSession()
        defer { session.cleanUp() }
        _ = try await session.connect(scopes: [.today])
        try await session.alice.takeOverPublisher()
        let settings = Settings.shared
        let originalVisibility = settings.hideCalorieStatusIcons
        defer { settings.hideCalorieStatusIcons = originalVisibility }
        settings.hideCalorieStatusIcons = false
        // settle the host's initial goal estimates before holding an upload
        // a unit change during startup correctly aborts a mismatched read
        await settings.updateShow(repository: session.repository)
        try #require(session.alice.isPublisher)
        try #require(session.alice.connections.first?.isReady(.today) == true)
        session.server.pauseNextPublication = true
        var firstFinished = false, secondFinished = false
        let first = Task {
            await session.runtime.publishCurrentWindow(settings: settings)
            firstFinished = true
            print("Publication regression: first caller finished, attempts \(session.server.publicationAttempts.count), error \(session.runtime.actionError ?? "none")")
        }
        print("Publication regression: waiting for the first upload")
        await session.server.publicationGate.waitUntilSuspended()
        print("Publication regression: first upload held")
        let (entered, signal) = AsyncStream<Void>.makeStream()
        let second = Task {
            signal.yield(())
            signal.finish()
            await session.runtime.publishCurrentWindow(settings: settings)
            secondFinished = true
        }
        for await _ in entered { break }
        settings.hideCalorieStatusIcons = true
        session.runtime.schedulePublication(settings: settings)
        session.runtime.schedulePublication(settings: settings)
        #expect(session.server.publicationAttempts.count == 1)
        #expect(!firstFinished && !secondFinished)

        session.server.pauseNextCleanup = true
        session.server.publicationGate.resume()
        await session.server.cleanupGate.waitUntilSuspended()
        print("Publication regression: first cleanup held")
        session.server.pauseNextPublication = true
        session.server.cleanupGate.resume()
        await session.server.publicationGate.waitUntilSuspended()
        print("Publication regression: latest-policy upload held")
        #expect(session.server.publicationAttempts.count == 2)
        #expect(session.server.publicationAttempts.first?.snapshot.now.visibleGoalReached == nil)
        #expect(session.server.publicationAttempts.last?.snapshot.now.visibleGoalReached == nil)
        #expect(!firstFinished && !secondFinished)
        session.server.publicationGate.resume()
        await first.value
        await second.value
        #expect(firstFinished && secondFinished)
        #expect(session.server.publicationAttempts.count == 2)
        #expect(session.runtime.actionError == nil)
    }

}

/// A known long streak, independent of the app's sample mode and current calendar date.
private struct ConsistentStreakHealthSource: HealthDataSource {
    func dailySums(_ type: HKQuantityTypeIdentifier, from start: Date, to end: Date, unit: HKUnit) async throws -> [Date: Double] {
        let kcal: Double
        switch type {
        case .activeEnergyBurned: kcal = 500
        case .basalEnergyBurned: kcal = 1800
        case .dietaryEnergyConsumed: kcal = 1600
        default: return [:]
        }
        let value = HKQuantity(unit: .kilocalorie(), doubleValue: kcal).doubleValue(for: unit)
        var day = Calendar.current.startOfDay(for: start)
        var values: [Date: Double] = [:]
        while day < end {
            values[day] = value
            day = Calendar.current.date(byAdding: .day, value: 1, to: day)!
        }
        return values
    }
    func weights(from start: Date, to end: Date, unit: HKUnit) async throws -> [WeightChartData] { [] }
    func latestWeight(before end: Date, unit: HKUnit) async throws -> (Double?, Date?) { (nil, nil) }
    func requestPermission() async -> Bool { true }
}

@MainActor
/// Per-test database, accounts, runtime, and fake server.
private struct RuntimeSession {

    /// Temporary directory that contains this session's database.
    let directory: URL

    /// SQLite file used by the local sharing store.
    let database: URL

    /// Isolated defaults suite used by the runtime.
    let suiteName: String

    /// Defaults values for the runtime session.
    let defaults: UserDefaults

    /// In-memory server shared by both fixture accounts.
    let server: SharingFakeServer

    /// Coordinator for the Alice fixture account.
    let alice: SharingCoordinator

    /// Coordinator for the Bob fixture account.
    let bob: SharingCoordinator

    /// Sample health repository used for publication tests.
    let repository: HealthRepository

    /// Runtime that coordinates Alice's sharing work.
    let runtime: SharingRuntime

    /// Creates fixture accounts and injects their test dependencies.
    init(source: any HealthDataSource = SampleHealthDataSource()) throws {

        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        database = directory.appendingPathComponent("sharing.sqlite")
        suiteName = "SharingRuntimeTests." + UUID().uuidString
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(true, forKey: "sharing.used")
        defaults.set("Alice", forKey: "sharing.displayName")
        let server = SharingFakeServer()
        self.server = server
        let store = try SharingStore(path: database.path)
        alice = SharingCoordinator(store: store, transport: server.transport(for: SharingFixtures.alice))
        bob = SharingCoordinator(store: try SharingStore(), transport: server.transport(for: SharingFixtures.bob))
        repository = HealthRepository(source: source)
        runtime = SharingRuntime(coordinator: alice, store: store, repository: repository, defaults: defaults)
    }

    /// Proposes, accepts, and refreshes a connection between the fixture accounts.
    func connect(scopes: Set<SharingScope>) async throws -> UUID {

        await alice.verifyAccount()
        let id = try await alice.propose(to: SharingFixtures.bob, scopes: scopes)
        await bob.refresh()
        let proposal = try #require(bob.connections.first?.proposal)
        try await bob.accept(connectionID: id, proposalID: proposal.id)
        await alice.refresh()
        await bob.refresh()
        return id
    }

    /// Removes this session's defaults domain after the test.
    func cleanUp() {
        defaults.removePersistentDomain(forName: suiteName)
        // sqlite connections can outlive this scope through completed tasks
        // let the simulator discard its temporary files after the host exits
    }

}

/// Changes the captured policy during the first measurement read.
private actor PolicyChangingHealthSource: HealthDataSource {

    /// User setting change applied during the read.
    let change: @MainActor @Sendable () -> Void

    /// Whether the first measurement has triggered the setting change.
    var changed = false

    init(change: @escaping @MainActor @Sendable () -> Void) { self.change = change }

    /// Applies the setting change once and returns deterministic measurements.
    func dailySums(_ type: HKQuantityTypeIdentifier, from start: Date, to end: Date,
                   unit: HKUnit) async throws -> [Date: Double] {

        if !changed { changed = true; await change() }
        return try await SampleHealthDataSource().dailySums(type, from: start, to: end, unit: unit)
    }

    /// Supplies no weights because publication reads energy only.
    func weights(from start: Date, to end: Date, unit: HKUnit) async throws -> [WeightChartData] { [] }

    /// Supplies no weight because publication reads energy only.
    func latestWeight(before end: Date, unit: HKUnit) async throws -> (Double?, Date?) { (nil, nil) }

    /// Allows synthetic reads without a HealthKit authorization prompt.
    func requestPermission() async -> Bool { true }

}

@Suite @MainActor
struct SharingCloudPersistenceTests {
    @Test func recordsAndCheckpointSurviveTogether() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("cache.json")
        let zone = CKRecordZone.ID(zoneName: "test", ownerName: CKCurrentUserDefaultName)
        let id = CKRecord.ID(recordName: "card", zoneID: zone)
        let record = CKRecord(recordType: "CountSharingCard", recordID: id)
        record.encryptedValues["payload"] = "private snapshot"
        record["scope"] = "today"
        record.parent = CKRecord.Reference(recordID: CKRecord.ID(recordName: "root", zoneID: zone), action: .none)
        let checkpoint = Data("checkpoint".utf8)
        let cache = try SharingCloudCache(file: file, accountID: "alice")
        cache.apply(saving: [record])
        try cache.persist(checkpoint: checkpoint)
        let restored = try SharingCloudCache(file: file, accountID: "alice")
        #expect(restored.checkpoint == checkpoint)
        #expect(restored.records[id]?.encryptedValues["payload"] as? String == "private snapshot")
        #expect(restored.records[id]?["scope"] as? String == "today")
        #expect(restored.records[id]?.parent?.recordID == record.parent?.recordID)
        #expect(throws: SharingError.wrongAccount) { try SharingCloudCache(file: file, accountID: "bob") }
        restored.apply(deletedZones: [zone])
        try restored.persist(checkpoint: Data("after deletion".utf8))
        #expect(try SharingCloudCache(file: file, accountID: "alice").records.isEmpty)
        try restored.clear()
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test func failedPersistenceDoesNotAdvanceCheckpoint() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        try Data().write(to: folder)
        let cache = try SharingCloudCache(file: folder.appendingPathComponent("cache.json"), accountID: "alice")
        #expect(throws: (any Error).self) { try cache.persist(checkpoint: Data("new".utf8)) }
        #expect(cache.checkpoint == nil)
    }

    @Test func visibleRefreshAndServerBackoff() {
        var policy = SharingFreshness()
        let now = Date(timeIntervalSince1970: 1_000)
        #expect(policy.shouldRefresh(at: now))
        policy.succeeded(at: now)
        #expect(!policy.shouldRefresh(at: now.addingTimeInterval(59)))
        #expect(policy.nextRefreshDelay(at: now.addingTimeInterval(45)) == 15)
        #expect(policy.shouldRefresh(at: now.addingTimeInterval(60)))
        #expect(policy.shouldRefresh(at: now, changed: true))
        policy.failed(at: now, serverDelay: 120)
        #expect(!policy.shouldRefresh(at: now.addingTimeInterval(119), changed: true))
        #expect(policy.nextRefreshDelay(at: now.addingTimeInterval(60)) == 60)
        #expect(policy.shouldRefresh(at: now.addingTimeInterval(120), changed: true))
        policy.succeeded(at: now.addingTimeInterval(121))
        #expect(policy.retryNotBefore == nil)
        #expect(policy.failures == 0)
    }
}
