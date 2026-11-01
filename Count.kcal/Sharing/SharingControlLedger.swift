import Foundation

/// The payload in one account's owner-controlled, read-only permission record.
/// The embedded connection supplies identity metadata, never accepted grants.
struct SharingControlDocument: Codable, Equatable, Sendable {
    /// Connection state stored with the account's control events.
    var connection: SharingConnection

    /// Consent events attested by this account.
    var events: [SharingConsentMutation]

    /// Scope readiness receipts stored by this account.
    var receipts: [SharingProvisionReceipt]

    /// Latest publisher generation recorded by this account.
    var publisherGeneration: UUID?
}

/// Adapter-verified owner identity paired with its control document.
/// A writable setup record's claimed owner ID does not provide this attestation.
struct SharingAttestedControl: Equatable, Sendable {
    /// Account identity verified by the adapter.
    var ownerID: String

    /// Control data owned by that account.
    var document: SharingControlDocument
}

/// Replay engine for adapter-verified owner controls and connection state.
/// Identity relationships are checked here; CloudKit record ownership is verified by the adapter.
enum SharingControlLedger {

    /// Rebuilds connection state from controls whose owners the adapter verified.
    static func resolve(
        connectionID: UUID,
        containerIdentifier: String,
        inviterID: String,
        accountID: String,
        controls: [SharingAttestedControl]
    ) throws -> SharingConnection? {

        guard !inviterID.isEmpty,
              !accountID.isEmpty,
              !containerIdentifier.isEmpty else { throw SharingError.invalidConnection }
        guard Set(controls.map(\.ownerID)).count == controls.count else { throw SharingError.invalidConnection }
        guard let seed = controls.first(where: { $0.ownerID == inviterID })?.document.connection else { return nil }
        guard seed.id == connectionID, seed.containerIdentifier == containerIdentifier,
              seed.inviter.id == inviterID, !seed.invitee.id.isEmpty,
              seed.inviter.id != seed.invitee.id else { throw SharingError.invalidConnection }
        guard seed.peer(of: accountID) != nil else { throw SharingError.wrongAccount }
        let parties = Set([seed.inviter.id, seed.invitee.id])
        var events: [UUID: SharingConsentMutation] = [:]
        var proposals: [UUID: SharingProposal] = [:]
        for control in controls {
            guard parties.contains(control.ownerID),
                  matches(control.document.connection, seed: seed) else { throw SharingError.invalidConnection }
            for event in control.document.events {
                guard event.actorID == control.ownerID, event.expectedRevision >= 0,
                      event.connection.revision == event.expectedRevision,
                      event.createdAt.timeIntervalSinceReferenceDate.isFinite,
                      matches(event.connection, seed: seed) else { throw SharingError.invalidConnection }
                if let duplicate = events[event.id], duplicate != event { throw SharingError.invalidConnection }
                events[event.id] = event
                if case .propose(let proposal) = event.action {
                    guard proposal.createdAt.timeIntervalSinceReferenceDate.isFinite,
                          proposal.expiresAt.timeIntervalSinceReferenceDate.isFinite
                    else { throw SharingError.invalidProposal }
                    // grant generations cannot be recycled after a reduction
                    if let duplicate = proposals[proposal.id], duplicate != proposal {
                        throw SharingError.invalidProposal
                    }
                    proposals[proposal.id] = proposal
                }
            }
            for receipt in control.document.receipts {
                guard receipt.connectionID == connectionID,
                      receipt.accountID == control.ownerID else { throw SharingError.invalidConnection }
            }
        }

        let revisions = Dictionary(grouping: events.values, by: \.expectedRevision)
        var state: SharingConnection?
        for revision in revisions.keys.sorted() {
            let candidates = revisions[revision]!.sorted { $0.id.uuidString < $1.id.uuidString }
            // concurrent reductions combine so neither account restores a removed permission
            let reductions = candidates.compactMap { event -> SharingConnection? in
                guard isReduction(event.action) else { return nil }
                return try? SharingConsent.applying(event, to: state, now: event.createdAt)
            }
            if var reduced = reductions.first {
                let retained = reductions.dropFirst().reduce(reduced.scopes) { $0.intersection($1.scopes) }
                reduced.grants.removeAll { !retained.contains($0.scope) }
                if reduced.grants.isEmpty { reduced.sharingStartedAt = nil }
                reduced.removed = reductions.contains(where: \.removed)
                state = reduced
                continue
            }
            // cancellation or decline at the acceptance revision blocks a delayed acceptance
            if let canceled = candidates.lazy.compactMap({ event -> SharingConnection? in
                guard isCancellation(event.action) else { return nil }
                return try? SharingConsent.applying(event, to: state, now: event.createdAt)
            }).first {
                state = canceled
                continue
            }
            for event in candidates {
                // use the event time so an accepted invitation keeps its grants after expiry
                if let next = try? SharingConsent.applying(event, to: state, now: event.createdAt) { state = next }
            }
        }
        guard var connection = state else { return nil }
        for control in controls {
            // each account controls its own display name, not the other person's invitation label
            if control.ownerID == connection.inviter.id {
                connection.inviter.displayName = control.document.connection.inviter.displayName
            } else {
                connection.invitee.displayName = control.document.connection.invitee.displayName
            }
            for receipt in control.document.receipts {
                let receiptGrantIndex = connection.grants.firstIndex { grant in
                    guard grant.scope == receipt.scope else { return false }
                    guard grant.generation == receipt.generation else { return false }
                    return true
                }
                if let receiptGrantIndex {
                    connection.grants[receiptGrantIndex].readyAccountIDs.insert(control.ownerID)
                }
            }
            if let generation = control.document.publisherGeneration {
                connection.publisherGenerations[control.ownerID] = generation
            }
        }
        return connection
    }

}

extension SharingControlLedger {

    /// Checks the identity fields shared by every control document.
    private static func matches(_ connection: SharingConnection, seed: SharingConnection) -> Bool {
        connection.id == seed.id && connection.containerIdentifier == seed.containerIdentifier
            && connection.inviter.id == seed.inviter.id && connection.invitee.id == seed.invitee.id
    }

    /// Identifies consent actions that remove granted scopes.
    private static func isReduction(_ action: SharingConsentAction) -> Bool {
        switch action { case .reduce, .remove: return true; default: return false }
    }

    /// Identifies consent actions that cancel or decline a proposal.
    private static func isCancellation(_ action: SharingConsentAction) -> Bool {
        switch action { case .cancel, .decline: return true; default: return false }
    }

}
