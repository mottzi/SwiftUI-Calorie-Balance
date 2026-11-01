import Foundation
import Testing
@testable import Count_kcal

/// Owner-attested consent ledger tests.
struct SharingControlLedgerTests {


    @Test
    /// Reconstructs the start from accepted legacy events without trusting embedded metadata.
    func legacyLedgerRecoversSharingStartFromAcceptance() throws {
        let scenario = try LedgerScenario()
        var controls = scenario.controls
        controls[0].document.connection.sharingStartedAt = scenario.time.addingTimeInterval(-86_400)
        let encoder = JSONEncoder()
        var objects = try #require(JSONSerialization.jsonObject(with: encoder.encode(controls.map(\.document))) as? [[String: Any]])
        // Existing owner documents predate the optional start-date field.
        for index in objects.indices {
            var connection = try #require(objects[index]["connection"] as? [String: Any])
            connection.removeValue(forKey: "sharingStartedAt")
            objects[index]["connection"] = connection
        }
        let decoded = try JSONDecoder().decode([SharingControlDocument].self, from: JSONSerialization.data(withJSONObject: objects))
        for index in controls.indices { controls[index].document = decoded[index] }
        let resolved = try #require(try scenario.resolve(controls))
        #expect(resolved.sharingStartedAt == scenario.acceptance.createdAt)
        #expect(scenario.pending.sharingStartedAt == nil)
        #expect(try JSONDecoder().decode(SharingConnection.self, from: encoder.encode(resolved)).sharingStartedAt == resolved.sharingStartedAt)
    }

    @Test
    /// Moving between Today and all seven days preserves the current sharing period.
    func scopeExpansionAndPartialReductionKeepSharingStart() throws {
        let scenario = try LedgerScenario()
        var connection = scenario.accepted
        let originalStart = try #require(connection.sharingStartedAt)
        let proposal = SharingProposal(
            id: UUID(), proposerID: scenario.alice.id, recipientID: scenario.bob.id,
            baseRevision: connection.revision, scopes: [.today, .history],
            createdAt: scenario.time.addingTimeInterval(100),
            expiresAt: scenario.time.addingTimeInterval(1000)
        )
        func apply(_ action: SharingConsentAction, actor: SharingIdentity, seconds: TimeInterval) throws {
            var event = scenario.event(actor: actor, connection: connection, action: action)
            event.createdAt = scenario.time.addingTimeInterval(seconds)
            connection = try SharingConsent.applying(event, to: connection, now: event.createdAt)
        }
        try apply(.propose(proposal), actor: scenario.alice, seconds: 100)
        try apply(.accept(proposalID: proposal.id), actor: scenario.bob, seconds: 200)
        #expect(connection.scopes == [.today, .history])
        #expect(connection.sharingStartedAt == originalStart)
        try apply(.reduce(to: [.today]), actor: scenario.alice, seconds: 300)
        #expect(connection.scopes == [.today])
        #expect(connection.sharingStartedAt == originalStart)
        try apply(.reduce(to: []), actor: scenario.alice, seconds: 400)
        #expect(connection.sharingStartedAt == nil)
        var resume = proposal
        resume.id = UUID()
        resume.baseRevision = connection.revision
        resume.createdAt = scenario.time.addingTimeInterval(500)
        try apply(.propose(resume), actor: scenario.alice, seconds: 500)
        #expect(connection.sharingStartedAt == nil)
        try apply(.accept(proposalID: resume.id), actor: scenario.bob, seconds: 600)
        #expect(connection.sharingStartedAt == scenario.time.addingTimeInterval(600))
        try apply(.remove, actor: scenario.alice, seconds: 700)
        #expect(connection.sharingStartedAt == nil)
    }

    @Test
    /// Concurrent partial reductions that jointly pause sharing also end its duration.
    func combinedReductionsClearSharingStart() throws {
        let scenario = try LedgerScenario(scopes: [.today, .history])
        var controls = scenario.controls
        controls[0].document.events.append(scenario.event(actor: scenario.alice, connection: scenario.accepted, action: .reduce(to: [.today])))
        controls[1].document.events.append(scenario.event(actor: scenario.bob, connection: scenario.accepted, action: .reduce(to: [.history])))
        let resolved = try #require(try scenario.resolve(controls))
        #expect(resolved.scopes.isEmpty)
        #expect(resolved.sharingStartedAt == nil)
    }

    @Test
    /// Accepts an invitation only after matching owner receipts establish readiness.
    func ownerAttestedEventsAndMatchingReceiptsEstablishMutualReadiness() throws {

        let scenario = try LedgerScenario()
        var controls = scenario.controls
        for index in controls.indices {
            controls[index].document.receipts = [scenario.receipt(ownerID: controls[index].ownerID)]
            controls[index].document.publisherGeneration = UUID()
        }
        let resolved = try #require(try scenario.resolve(controls))
        #expect(resolved.isReady(.today))
        #expect(resolved.grants.first?.generation == scenario.proposal.id)
        #expect(resolved.publisherGenerations[scenario.alice.id] == controls[0].document.publisherGeneration)
        #expect(resolved.publisherGenerations[scenario.bob.id] == controls[1].document.publisherGeneration)
    }

    @Test
    /// Uses each owner's display name without changing either account identifier.
    func eachAccountOwnsItsConfirmedDisplayNameWithoutChangingIdentity() throws {

        let scenario = try LedgerScenario()
        var controls = scenario.controls
        controls[0].document.connection.inviter.displayName = "Alice Confirmed"
        controls[0].document.connection.invitee.displayName = "Inviter's draft name"
        controls[1].document.connection.inviter.displayName = "Invitee's draft name"
        controls[1].document.connection.invitee.displayName = "Bob Confirmed"
        let resolved = try #require(try scenario.resolve(controls))
        #expect(resolved.inviter.id == scenario.alice.id)
        #expect(resolved.invitee.id == scenario.bob.id)
        #expect(resolved.inviter.displayName == "Alice Confirmed")
        #expect(resolved.invitee.displayName == "Bob Confirmed")
    }

    @Test
    /// Ignores embedded grants if the owner documents contain no consent events.
    func embeddedConnectionGrantsAreNeverConsentEvidence() throws {

        let scenario = try LedgerScenario()
        var control = scenario.controls[0]
        control.document.connection = scenario.accepted
        control.document.connection.grants[0].readyAccountIDs = [scenario.alice.id, scenario.bob.id]
        control.document.events = []
        #expect(try scenario.resolve([control]) == nil)
    }

    @Test
    /// Rejects controls whose owner, container, or account pair differs from the invitation.
    func documentAccountContainerAndPairMustMatchTheAttestedInvitation() throws {

        let scenario = try LedgerScenario()
        var wrongContainer = scenario.controls
        wrongContainer[1].document.connection.containerIdentifier = "iCloud.other"
        #expect(throws: SharingError.invalidConnection) { try scenario.resolve(wrongContainer) }
        var wrongPair = scenario.controls
        wrongPair[1].document.connection.invitee.id = "third-account"
        #expect(throws: SharingError.invalidConnection) { try scenario.resolve(wrongPair) }
        var wrongOwner = scenario.controls
        wrongOwner[1].ownerID = "third-account"
        #expect(throws: SharingError.invalidConnection) { try scenario.resolve(wrongOwner) }
        #expect(throws: SharingError.wrongAccount) {
            try SharingControlLedger.resolve(
                connectionID: scenario.seed.id,
                containerIdentifier: scenario.seed.containerIdentifier,
                inviterID: scenario.alice.id,
                accountID: "uninvited-account",
                controls: scenario.controls
            )
        }
    }

    @Test
    /// Rejects an acceptance event stored in the other account's control document.
    func anOwnerCannotAttestTheOtherAccountsAcceptance() throws {

        let scenario = try LedgerScenario()
        var controls = scenario.controls
        controls[0].document.events.append(scenario.acceptance)
        controls[1].document.events = []
        #expect(throws: SharingError.invalidConnection) { try scenario.resolve(controls) }
    }

    @Test
    /// Rejects events whose connection identity, revision, or container changes.
    func eventIdentityAndRevisionCannotDisagreeWithItsLedger() throws {

        let scenario = try LedgerScenario()
        var wrongConnection = scenario.controls
        wrongConnection[1].document.events[0].connection.id = UUID()
        #expect(throws: SharingError.invalidConnection) { try scenario.resolve(wrongConnection) }
        var wrongRevision = scenario.controls
        wrongRevision[1].document.events[0].connection.revision += 1
        #expect(throws: SharingError.invalidConnection) { try scenario.resolve(wrongRevision) }
        var wrongContainer = scenario.controls
        wrongContainer[1].document.events[0].connection.containerIdentifier = "iCloud.other"
        #expect(throws: SharingError.invalidConnection) { try scenario.resolve(wrongContainer) }
    }

    @Test
    /// Replays identical events once and rejects conflicting IDs or duplicate owners.
    func duplicateEventsAreIdempotentButConflictingIDsAndOwnerDocumentsAreRejected() throws {

        let scenario = try LedgerScenario()
        var controls = scenario.controls
        controls[1].document.events.append(scenario.acceptance)
        #expect(try scenario.resolve(controls)?.revision == scenario.accepted.revision)
        controls[1].document.events[1].createdAt = scenario.acceptance.createdAt.addingTimeInterval(1)
        #expect(throws: SharingError.invalidConnection) { try scenario.resolve(controls) }
        #expect(throws: SharingError.invalidConnection) { try scenario.resolve(scenario.controls + [scenario.controls[0]]) }
    }

    @Test
    /// Applies a same-revision scope reduction before a delayed acceptance.
    func reductionWinsOverAnAcceptanceFromTheSameRevision() throws {

        let scenario = try LedgerScenario()
        let reduction = scenario.event(
            actor: scenario.alice,
            connection: scenario.pending,
            action: .reduce(to: [])
        )
        var controls = scenario.controls
        controls[0].document.events.append(reduction)
        let resolved = try #require(try scenario.resolve(controls))
        #expect(resolved.scopes.isEmpty)
        #expect(resolved.proposal == nil)
        #expect(resolved.revision == 2)
    }

    @Test
    /// Keeps a canceled request from granting access after a delayed acceptance.
    func cancellationWinsOverADelayedAcceptance() throws {

        let scenario = try LedgerScenario()
        var controls = scenario.controls
        controls[0].document.events.append(
            scenario.event(
                actor: scenario.alice,
                connection: scenario.pending,
                action: .cancel(proposalID: scenario.proposal.id)
            )
        )
        let resolved = try #require(try scenario.resolve(controls))
        #expect(resolved.scopes.isEmpty)
        #expect(resolved.proposal == nil)
    }

    @Test
    /// Keeps only the scopes retained by both concurrent reductions.
    func concurrentReductionsKeepOnlyTheirIntersection() throws {

        let scenario = try LedgerScenario(scopes: [.today, .history])
        var controls = scenario.controls
        controls[0].document.events.append(
            scenario.event(
                actor: scenario.alice,
                connection: scenario.accepted,
                action: .reduce(to: [.today])
            )
        )
        controls[1].document.events.append(
            scenario.event(
                actor: scenario.bob,
                connection: scenario.accepted,
                action: .reduce(to: [.history])
            )
        )
        let resolved = try #require(try scenario.resolve(controls.reversed()))
        #expect(resolved.scopes.isEmpty)
        #expect(resolved.revision == scenario.accepted.revision + 1)
    }

    @Test
    /// Keeps a removal tombstone authoritative over later acceptance events.
    func removalTombstoneRejectsEveryLaterAcceptance() throws {

        let scenario = try LedgerScenario()
        let removal = scenario.event(actor: scenario.alice, connection: scenario.accepted, action: .remove)
        let removed = try SharingConsent.applying(removal, to: scenario.accepted, now: removal.createdAt)
        var controls = scenario.controls
        controls[0].document.events.append(removal)
        controls[1].document.events.append(
            scenario.event(
                actor: scenario.bob,
                connection: removed,
                action: .accept(proposalID: scenario.proposal.id)
            )
        )
        let resolved = try #require(try scenario.resolve(controls))
        #expect(resolved.removed)
        #expect(resolved.scopes.isEmpty)
        #expect(resolved.proposal == nil)
    }

    @Test
    /// Rejects an expansion accepted from a revision that has already been reduced.
    func staleExpansionAcceptanceCannotRestoreAReducedScope() throws {

        let scenario = try LedgerScenario()
        let expansion = SharingProposal(
            id: UUID(),
            proposerID: scenario.alice.id,
            recipientID: scenario.bob.id,
            baseRevision: scenario.accepted.revision,
            scopes: [.today, .history],
            createdAt: scenario.time,
            expiresAt: scenario.time.addingTimeInterval(3600)
        )
        let request = scenario.event(actor: scenario.alice, connection: scenario.accepted, action: .propose(expansion))
        let requested = try SharingConsent.applying(request, to: scenario.accepted, now: request.createdAt)
        var controls = scenario.controls
        controls[0].document.events.append(
            contentsOf: [
                request,
                scenario.event(
                    actor: scenario.alice,
                    connection: requested,
                    action: .reduce(to: [])
                )
            ]
        )
        controls[1].document.events.append(
            scenario.event(
                actor: scenario.bob,
                connection: requested,
                action: .accept(proposalID: expansion.id)
            )
        )
        let resolved = try #require(try scenario.resolve(controls))
        #expect(resolved.scopes.isEmpty)
        #expect(resolved.proposal == nil)
    }

    @Test
    /// Counts readiness only from that owner's receipt for the current generation.
    func onlyAnOwnersMatchingCurrentGenerationReceiptCounts() throws {

        let scenario = try LedgerScenario()
        var controls = scenario.controls
        var stale = scenario.receipt(ownerID: scenario.alice.id)
        stale.generation = UUID()
        controls[0].document.receipts = [stale]
        controls[1].document.receipts = [scenario.receipt(ownerID: scenario.bob.id)]
        let resolved = try #require(try scenario.resolve(controls))
        #expect(resolved.grants.first?.readyAccountIDs == [scenario.bob.id])
        #expect(!resolved.isReady(.today))
        controls[0].document.receipts.append(scenario.receipt(ownerID: scenario.bob.id))
        #expect(throws: SharingError.invalidConnection) { try scenario.resolve(controls) }
        controls[0].document.receipts = [scenario.receipt(ownerID: scenario.alice.id)]
        controls[0].document.receipts[0].connectionID = UUID()
        #expect(throws: SharingError.invalidConnection) { try scenario.resolve(controls) }
    }

    @Test
    /// Rejects reuse of a proposal generation after its scope was reduced.
    func reusedProposalGenerationCannotRecycleOldReadiness() throws {

        let scenario = try LedgerScenario()
        let reduction = scenario.event(
            actor: scenario.alice,
            connection: scenario.accepted,
            action: .reduce(to: [])
        )
        let paused = try SharingConsent.applying(reduction, to: scenario.accepted, now: reduction.createdAt)
        var recycled = scenario.proposal
        recycled.baseRevision = paused.revision
        var controls = scenario.controls
        controls[0].document.events.append(
            contentsOf: [
                reduction,
                scenario.event(
                    actor: scenario.alice,
                    connection: paused,
                    action: .propose(recycled)
                )
            ]
        )
        #expect(throws: SharingError.invalidProposal) { try scenario.resolve(controls) }
    }

    @Test
    /// Replays a past acceptance at its recorded time after the request has expired.
    func historicalAcceptanceSurvivesItsFormerRequestExpiry() throws {

        let scenario = try LedgerScenario()
        // replay uses the recorded acceptance time, not the current clock
        #expect(try scenario.resolve(scenario.controls)?.scopes == [.today])
        var controls = scenario.controls
        controls[1].document.events[0].createdAt = scenario.proposal.expiresAt
        #expect(try scenario.resolve(controls)?.scopes.isEmpty == true)
    }

    @Test
    /// Preserves valid controls through coding and rejects unknown scope values.
    func controlDocumentRoundTripsAndUnknownScopesFailDecoding() throws {

        let scenario = try LedgerScenario()
        var document = scenario.controls[0].document
        document.receipts = [scenario.receipt(ownerID: scenario.alice.id)]
        let encoded = try JSONEncoder().encode(document)
        #expect(try JSONDecoder().decode(SharingControlDocument.self, from: encoded) == document)
        let unknown = String(decoding: encoded, as: UTF8.self)
            .replacingOccurrences(
                of: "\"scope\":\"today\"",
                with: "\"scope\":\"unknown\""
            )
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(SharingControlDocument.self, from: Data(unknown.utf8))
        }
    }

}

/// Consent-ledger fixture with owner documents and request states.
private struct LedgerScenario {

    /// First account and invitation owner in the fixture.
    let alice = SharingIdentity(id: "ledger-alice", displayName: "Alice")

    /// Second account and invitation recipient in the fixture.
    let bob = SharingIdentity(id: "ledger-bob", displayName: "Bob")

    /// Fixed timestamp used by fixture events.
    let time = Date(timeIntervalSince1970: 1_790_000_000)

    /// Connection before either owner records consent.
    let seed: SharingConnection

    /// Initial Today or caller-selected scope request.
    let proposal: SharingProposal

    /// Invitation event that creates the pending connection.
    let invitation: SharingConsentMutation

    /// Connection state after the invitation event.
    let pending: SharingConnection

    /// Recipient event that accepts the proposal.
    let acceptance: SharingConsentMutation

    /// Connection state after the recipient accepts.
    let accepted: SharingConnection

    /// Creates the request and accepted connection state for the test scopes.
    init(scopes: Set<SharingScope> = [.today]) throws {

        let seed = SharingConnection(
            id: UUID(),
            containerIdentifier: "iCloud.com.count.kcal.app",
            inviter: alice,
            invitee: bob
        )
        self.seed = seed
        proposal = SharingProposal(
            id: UUID(),
            proposerID: alice.id,
            recipientID: bob.id,
            baseRevision: 0,
            scopes: scopes,
            createdAt: time,
            expiresAt: time.addingTimeInterval(3600)
        )
        invitation = SharingConsentMutation(
            id: UUID(),
            connection: seed,
            actorID: alice.id,
            expectedRevision: 0,
            action: .propose(proposal),
            createdAt: time
        )
        pending = try SharingConsent.applying(invitation, to: nil, now: time)
        acceptance = SharingConsentMutation(
            id: UUID(),
            connection: pending,
            actorID: bob.id,
            expectedRevision: 1,
            action: .accept(proposalID: proposal.id),
            createdAt: time.addingTimeInterval(1)
        )
        accepted = try SharingConsent.applying(acceptance, to: pending, now: time.addingTimeInterval(1))
    }

    /// Owner documents with the invitation and acceptance events.
    var controls: [SharingAttestedControl] {
        [
            SharingAttestedControl(
                ownerID: alice.id,
                document: SharingControlDocument(
                    connection: seed,
                    events: [invitation],
                    receipts: [],
                    publisherGeneration: nil
                )
            ),
            SharingAttestedControl(
                ownerID: bob.id,
                document: SharingControlDocument(
                    connection: pending,
                    events: [acceptance],
                    receipts: [],
                    publisherGeneration: nil
                )
            )
        ]
    }

    /// Resolves the fixture through the production ledger interface.
    func resolve(_ controls: [SharingAttestedControl]) throws -> SharingConnection? {
        try SharingControlLedger.resolve(
            connectionID: seed.id,
            containerIdentifier: seed.containerIdentifier,
            inviterID: alice.id,
            accountID: bob.id,
            controls: controls
        )
    }

    /// Builds an owner receipt for the proposal's Today grant.
    func receipt(ownerID: String) -> SharingProvisionReceipt {
        SharingProvisionReceipt(connectionID: seed.id, accountID: ownerID, scope: .today, generation: proposal.id)
    }

    /// Builds a consent event at the current connection revision.
    func event(
        actor: SharingIdentity,
        connection: SharingConnection,
        action: SharingConsentAction
    ) -> SharingConsentMutation {
        SharingConsentMutation(
            id: UUID(),
            connection: connection,
            actorID: actor.id,
            expectedRevision: connection.revision,
            action: action,
            createdAt: time.addingTimeInterval(2)
        )
    }

}
