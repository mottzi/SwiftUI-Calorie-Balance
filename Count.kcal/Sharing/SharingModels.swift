import Foundation

/// Verified account identity used by the sharing protocol.
struct SharingIdentity: Codable, Equatable, Hashable, Sendable, Identifiable {
    /// Account identifier supplied by the sharing transport.
    var id: String

    /// User-visible name that does not identify the account.
    var displayName: String
}

/// Metadata invitation state without calorie authority.
struct SharingPendingInvitation: Equatable, Identifiable, Sendable {
    /// Connection identifier for the invitation.
    var id: UUID

    /// Metadata handoff state shown to the user.
    var stage: Stage

    /// Current metadata handoff stage.
    enum Stage: Equatable, Sendable {

        /// An invitation waits for the named recipient to accept it.
        case awaitingRecipient(name: String, scopes: Set<SharingScope>, expiresAt: Date, url: URL)

        /// The inviter must bind accepted metadata to a verified account.
        case awaitingInviter

    }
}

/// Verified state of the current iCloud account.
enum SharingAccountStatus: Equatable, Sendable {

    /// The transport verified this account as available.
    case available(SharingIdentity)

    /// The transport confirmed that no account is signed in.
    case signedOut

    /// The transport cannot verify the current account state.
    case uncertain

}

/// Calorie data range that a connection may share.
enum SharingScope: String, Codable, CaseIterable, Sendable, Identifiable {

    /// Snapshots for the sender's current local calendar day.
    case today

    /// Recorded snapshots for the six prior sender-local days.
    case history

    /// Decoded only to revoke obsolete development grants and replay their control history.
    case retiredStreak = "streaks"

    /// Goal results for permitted calorie days and the full streak summary.
    case goals

    static let allCases: [Self] = [.today, .history, .goals]

    /// String identity used by scope controls.
    var id: String { rawValue }

}

/// Direction of one account's share revocation.
enum SharingDirection: String, Codable, CaseIterable, Sendable {

    /// Delete the share this account owns.
    case outgoing

    /// Leave the peer's shared zone.
    case incoming

}

/// One consent request between the two accounts.
struct SharingProposal: Codable, Equatable, Sendable, Identifiable {
    /// Proposal identifier used for idempotency and grant generation.
    var id: UUID

    /// Account that created the proposal.
    var proposerID: String

    /// Account that can accept or decline the proposal.
    var recipientID: String

    /// Connection revision on which the proposal was based.
    var baseRevision: Int

    /// Scopes requested by the proposer.
    var scopes: Set<SharingScope>

    /// Time at which the proposal was created.
    var createdAt: Date

    /// Time after which the proposal cannot be accepted.
    var expiresAt: Date
}

/// Accepted scope and the accounts that completed reciprocal setup.
struct SharingGrant: Codable, Equatable, Sendable {
    /// Scope enabled by this grant.
    var scope: SharingScope

    /// Consent generation used to identify the scope's share hierarchy.
    var generation: UUID

    /// Accounts that verified both share directions for this generation.
    var readyAccountIDs: Set<String> = []
}

/// Current publishing device authority for one account.
struct SharingPublisherLease: Codable, Equatable, Sendable {
    /// Account that owns the publishing authority.
    var accountID: String

    /// Device that may publish for the account.
    var deviceID: UUID

    /// Generation that fences writes from prior publishers.
    var generation: UUID
}

/// Consent and publication state for two accounts.
struct SharingConnection: Codable, Equatable, Sendable, Identifiable {

    /// Identifier shared by both accounts.
    var id: UUID

    /// CloudKit container that owns the connection.
    var containerIdentifier: String

    /// Account that created the first proposal.
    var inviter: SharingIdentity

    /// Account that received the first proposal.
    var invitee: SharingIdentity

    /// Revision that the next consent mutation must match.
    var revision: Int = 0

    /// Scopes that have a consent grant.
    var grants: [SharingGrant] = []

    /// Consent proposal that is waiting for a response.
    var proposal: SharingProposal?

    /// Acceptance time for the current uninterrupted period with at least one shared scope.
    var sharingStartedAt: Date?

    /// First accepted consent, retained across pauses and reconstructed by ledger replay.
    var firstAcceptedAt: Date?

    var hasAcceptedSharing: Bool { firstAcceptedAt != nil || sharingStartedAt != nil || !grants.isEmpty }

    /// Established relationships and unanswered requests must use their existing connection.
    var blocksNewInvitation: Bool { !removed && (hasAcceptedSharing || proposal != nil) }

    /// Whether consent has ended for this connection.
    var removed = false

    /// Current publisher generation recorded for each account.
    var publisherGenerations: [String: UUID] = [:]

    /// Scopes with a consent grant.
    var scopes: Set<SharingScope> { Set(grants.map(\.scope)) }

    /// Peer identity if the account belongs to this connection.
    func peer(of accountID: String) -> SharingIdentity? {
        if inviter.id == accountID { return invitee }
        if invitee.id == accountID { return inviter }
        return nil
    }

    /// Whether both accounts recorded setup for this scope.
    func isReady(_ scope: SharingScope) -> Bool {
        guard !removed, let grant = grants.first(where: { $0.scope == scope }) else { return false }
        return grant.readyAccountIDs == Set([inviter.id, invitee.id])
    }

}

/// Consent action applied to a connection revision.
enum SharingConsentAction: Codable, Equatable, Sendable {

    /// Propose a new connection or request more scopes.
    case propose(SharingProposal)

    /// Accept the named proposal.
    case accept(proposalID: UUID)

    /// Decline the named proposal.
    case decline(proposalID: UUID)

    /// Cancel the named proposal.
    case cancel(proposalID: UUID)

    /// Reduce the connection to the listed scopes.
    case reduce(to: Set<SharingScope>)

    /// End consent and remove the connection.
    case remove

}

/// Durable consent operation with an expected revision.
struct SharingConsentMutation: Codable, Equatable, Sendable, Identifiable {
    /// Idempotency identifier for the operation.
    var id: UUID

    /// Connection state used to apply the action.
    var connection: SharingConnection

    /// Account that requested the action.
    var actorID: String

    /// Server revision required before the action can apply.
    var expectedRevision: Int

    /// Consent change to apply.
    var action: SharingConsentAction

    /// Time at which the operation was queued.
    var createdAt: Date
}

/// Request to verify one account's reciprocal share setup.
struct SharingProvisionRequest: Codable, Equatable, Sendable {
    /// Connection being provisioned.
    var connection: SharingConnection

    /// Account that owns this setup request.
    var accountID: String

    /// Scope to provision.
    var scope: SharingScope

    /// Consent generation that must remain current.
    var generation: UUID
}

/// Receipt for verified outgoing and incoming share setup.
struct SharingProvisionReceipt: Codable, Equatable, Sendable {
    /// Connection whose setup was verified.
    var connectionID: UUID

    /// Account that completed the setup check.
    var accountID: String

    /// Scope that was provisioned.
    var scope: SharingScope

    /// Consent generation that was verified.
    var generation: UUID
}

/// Durable request to revoke one direction of one scope.
struct SharingRevocation: Codable, Equatable, Hashable, Sendable, Identifiable {
    /// Identifier for this revocation operation.
    var id: UUID

    /// Connection whose scope is being revoked.
    var connectionID: UUID

    /// Account that must perform the operation.
    var accountID: String

    /// Peer account named by the connection.
    var peerID: String

    /// Scope to revoke.
    var scope: SharingScope

    /// Consent generation whose share must be removed.
    var generation: UUID

    /// Share direction to revoke.
    var direction: SharingDirection
}

/// Sender snapshot tied to one connection, scope, and consent generation.
struct SharedSnapshotEnvelope: Codable, Equatable, Sendable, Identifiable {
    /// Connection that grants access to this snapshot.
    var connectionID: UUID

    /// Account that captured the snapshot.
    var senderID: String

    /// Scope that permits the snapshot.
    var scope: SharingScope

    /// Consent generation that authorizes this record.
    var consentGeneration: UUID

    /// Publisher generation that wrote this record.
    var publisherGeneration: UUID

    /// Immutable calorie values and sender presentation data.
    var snapshot: CalorieCardSnapshot

    /// Stable record identity for this sender-local day.
    var id: String { "\(connectionID)/\(senderID)/\(scope.rawValue)/\(snapshot.senderLocalDate)" }

    /// New publications cannot smuggle goal results through calorie-only scopes.
    var hasValidPublicationPayload: Bool {
        scope != .today && scope != .history || snapshot == snapshot.withoutGoalInformation()
    }

    /// Goal-day permission cannot outlive the calorie grant that authorized its date.
    func hasPermittedGoalDate(in connection: SharingConnection) -> Bool {
        guard scope == .goals, let result = snapshot.goalResult else { return true }
        return connection.isReady(result.calorieScope) && connection.grants.contains {
            $0.scope == result.calorieScope && $0.generation == result.calorieGeneration
        }
    }

}

/// Latest trusted sender metadata, retained without expired calorie values.
struct SharingSenderCalendar: Codable, Equatable, Sendable {
    /// Sender time zone used to label snapshots.
    var timeZoneIdentifier: String

    /// Capture time of the snapshot that supplied this calendar.
    var capturedAt: Date

    /// Snapshot identifier that supplied this calendar.
    var snapshotID: UUID

    /// Name color retained when today's calorie card has expired.
    var nameColor: CalorieCardSnapshot.AdaptiveColor? = nil
}

/// Account-scoped cache and durable sharing work.
struct SharingLocalState: Codable, Equatable, Sendable {
    /// Known connections for this account.
    var connections: [SharingConnection] = []

    /// Consent operations waiting to reach the transport.
    var pendingMutations: [SharingConsentMutation] = []

    /// Share removals waiting to reach the transport.
    var pendingRevocations: [SharingRevocation] = []

    /// Share removals already confirmed by the transport.
    var confirmedRevocations: [SharingRevocation] = []

    /// Received snapshots that still pass current consent and date checks.
    var snapshots: [SharedSnapshotEnvelope] = []

    /// Locally known publishing authority for this account.
    var publisherLease: SharingPublisherLease?

    /// Whether retention cleanup is waiting to finish.
    var cleanupPending = false

    /// Last trusted time zone observed for each sender.
    var senderCalendars: [String: SharingSenderCalendar] = [:]

    /// Identity appearance survives a pause without retaining calorie data or update times.
    var senderNameColors: [String: CalorieCardSnapshot.AdaptiveColor] = [:]

    /// Property names used by the persisted account record.
    private enum CodingKeys: String, CodingKey {

        /// Stored connections.
        case connections

        /// Queued consent operations.
        case pendingMutations

        /// Queued share removals.
        case pendingRevocations

        /// Confirmed share removals.
        case confirmedRevocations

        /// Cached received snapshots.
        case snapshots

        /// Local publisher authority state.
        case publisherLease

        /// Retention cleanup status.
        case cleanupPending

        /// Trusted sender calendar state.
        case senderCalendars

        case senderNameColors

    }
}

extension SharingLocalState {

    /// Decodes older records with empty defaults for fields added later.
    init(from decoder: Decoder) throws {

        let values = try decoder.container(keyedBy: CodingKeys.self)
        connections = try values.decodeIfPresent([SharingConnection].self, forKey: .connections) ?? []
        pendingMutations = try values.decodeIfPresent([SharingConsentMutation].self, forKey: .pendingMutations) ?? []
        pendingRevocations = try values.decodeIfPresent([SharingRevocation].self, forKey: .pendingRevocations) ?? []
        confirmedRevocations = try values.decodeIfPresent([SharingRevocation].self, forKey: .confirmedRevocations) ?? []
        snapshots = try values.decodeIfPresent([SharedSnapshotEnvelope].self, forKey: .snapshots) ?? []
        publisherLease = try values.decodeIfPresent(SharingPublisherLease.self, forKey: .publisherLease)
        cleanupPending = try values.decodeIfPresent(Bool.self, forKey: .cleanupPending) ?? false
        senderCalendars = try values.decodeIfPresent([String: SharingSenderCalendar].self, forKey: .senderCalendars) ?? [:]
        senderNameColors = try values.decodeIfPresent([String: CalorieCardSnapshot.AdaptiveColor].self, forKey: .senderNameColors) ?? [:]
    }

}

/// Errors returned by account, consent, publication, and transport checks.
enum SharingError: Error, Equatable {

    /// No verified account is available for the operation.
    case accountUnavailable

    /// The current account does not match the operation's account.
    case wrongAccount

    /// Connection or consent data failed validation.
    case invalidConnection

    /// The connection revision changed before the operation applied.
    case staleRevision

    /// The proposal does not match the connection or actor.
    case invalidProposal

    /// The proposal expired before acceptance.
    case proposalExpired

    /// The consent generation is no longer current.
    case staleGeneration

    /// A shared scope hierarchy no longer exists.
    case scopeRevoked(connectionID: UUID, scope: SharingScope)

    /// This device does not own the publisher lease.
    case publisherNotOwned

    /// The snapshot uses a schema this app cannot display.
    case unsupportedSchema

    /// A transport operation failed without a more specific error.
    case unavailable

    /// The native sheet added more than one recipient to an invitation.
    case multipleRecipients

    /// The peer has not published its scope setup URL.
    case peerSetupPending

    /// Localized message for a sharing error.
    static func message(for error: Error) -> String {

        guard let error = error as? SharingError else {
            return String(localized: "Sharing couldn't update. Try again.")
        }
        switch error {
        case .accountUnavailable:
            return String(localized: "iCloud is unavailable. Sharing will retry when your account is available.")
        case .wrongAccount:
            return String(localized: "This invitation belongs to a different iCloud account.")
        case .invalidProposal, .staleRevision, .staleGeneration, .scopeRevoked:
            return String(localized: "This sharing request has changed. Refresh to see the current permissions.")
        case .proposalExpired:
            return String(localized: "This invitation has expired. Ask for a new invitation.")
        case .publisherNotOwned:
            return String(localized: "Another iPhone is sharing your card. Choose this iPhone to share from it.")
        case .unsupportedSchema:
            return String(localized: "This card can't be displayed. Check for an app update.")
        case .invalidConnection, .unavailable:
            return String(localized: "Sharing couldn't update. Try again.")
        case .multipleRecipients:
            return String(localized: "Invite one person at a time. Create a new invitation to try again.")
        case .peerSetupPending:
            return String(localized: "Connecting")
        }
    }

}

/// Consent transitions used by the CloudKit adapter and fake server.
enum SharingConsent {

    /// Applies one consent action to a connection and advances its revision.
    static func applying(
        _ mutation: SharingConsentMutation,
        to existing: SharingConnection?,
        now: Date
    ) throws -> SharingConnection {

        if existing == nil {
            guard case .propose = mutation.action,
                  mutation.expectedRevision == 0, mutation.connection.revision == 0,
                  mutation.connection.inviter.id == mutation.actorID,
                  mutation.connection.grants.isEmpty, mutation.connection.proposal == nil,
                  mutation.connection.publisherGenerations.isEmpty else { throw SharingError.invalidConnection }
        }
        var connection = existing ?? mutation.connection
        // Only accepted consent events establish a sharing start, never invitation metadata.
        if existing == nil { connection.sharingStartedAt = nil; connection.firstAcceptedAt = nil }
        guard connection.id == mutation.connection.id,
              connection.containerIdentifier == mutation.connection.containerIdentifier,
              connection.inviter.id == mutation.connection.inviter.id,
              connection.invitee.id == mutation.connection.invitee.id,
              connection.inviter.id != connection.invitee.id,
              connection.peer(of: mutation.actorID) != nil,
              !connection.removed else { throw SharingError.invalidConnection }
        guard connection.revision == mutation.expectedRevision else { throw SharingError.staleRevision }
        switch mutation.action {
        case .propose(let proposal):
            guard proposal.proposerID == mutation.actorID,
                  proposal.recipientID == connection.peer(of: mutation.actorID)?.id,
                  proposal.baseRevision == connection.revision,
                  proposal.createdAt <= now, proposal.expiresAt > proposal.createdAt,
                  proposal.expiresAt > now,
                  proposal.expiresAt <= proposal.createdAt.addingTimeInterval(requestLifetime),
                  !proposal.scopes.isEmpty,
                  proposal.scopes.isSuperset(of: connection.scopes),
                  proposal.scopes != connection.scopes else { throw SharingError.invalidProposal }
            connection.proposal = proposal
        case .accept(let id):
            guard let proposal = connection.proposal, proposal.id == id,
                  proposal.recipientID == mutation.actorID,
                  proposal.baseRevision + 1 == connection.revision else { throw SharingError.invalidProposal }
            guard proposal.expiresAt > now else { throw SharingError.proposalExpired }
            if connection.firstAcceptedAt == nil { connection.firstAcceptedAt = mutation.createdAt }
            if connection.scopes.isEmpty { connection.sharingStartedAt = mutation.createdAt }
            for scope in proposal.scopes.subtracting(connection.scopes) {
                connection.grants.append(SharingGrant(scope: scope, generation: proposal.id))
            }
            connection.proposal = nil
        case .decline(let id), .cancel(let id):
            guard let proposal = connection.proposal, proposal.id == id else { throw SharingError.invalidProposal }
            switch mutation.action {
            case .decline: guard proposal.recipientID == mutation.actorID else { throw SharingError.wrongAccount }
            default: guard proposal.proposerID == mutation.actorID else { throw SharingError.wrongAccount }
            }
            connection.proposal = nil
        case .reduce(let scopes):
            guard scopes.isSubset(of: connection.scopes) else { throw SharingError.invalidProposal }
            connection.grants.removeAll { !scopes.contains($0.scope) }
            if connection.grants.isEmpty { connection.sharingStartedAt = nil }
            connection.proposal = nil
        case .remove:
            connection.grants = []
            connection.proposal = nil
            connection.removed = true
            connection.sharingStartedAt = nil
        }
        connection.revision += 1
        return connection
    }

    /// Maximum age of a consent proposal.
    static let requestLifetime: TimeInterval = 7 * 24 * 60 * 60

}

/// Sender-local calendar dates allowed by each sharing scope.
enum SharingDateWindow {

    static let historyDayCount = 6

    /// Checks whether a snapshot falls within the sender-local scope window.
    static func permits(_ snapshot: CalorieCardSnapshot, scope: SharingScope, now: Date,
                        latestSenderTimeZone: TimeZone? = nil) -> Bool {

        guard let capturedZone = TimeZone(identifier: snapshot.timeZoneIdentifier),
              snapshot.capturedAt <= now, snapshot.isSupported else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = latestSenderTimeZone ?? capturedZone
        let today = calendar.startOfDay(for: now)
        let todayLabel = CalorieCardSnapshot.localDate(for: today, calendar: calendar)
        // compare captured labels instead of regrouping old values after sender travel
        switch scope {
        case .today:
            return snapshot.streak == nil && snapshot.goalResult == nil && snapshot.senderLocalDate == todayLabel
        case .history:
            guard snapshot.streak == nil, snapshot.goalResult == nil, snapshot.midnight == nil,
                  let oldest = calendar.date(byAdding: .day, value: -historyDayCount, to: today) else { return false }
            let oldestLabel = CalorieCardSnapshot.localDate(for: oldest, calendar: calendar)
            return snapshot.senderLocalDate >= oldestLabel && snapshot.senderLocalDate < todayLabel
        case .retiredStreak:
            return false
        case .goals:
            guard snapshot.now.energy.isEmpty, snapshot.now.visibleGoalReached == nil,
                  snapshot.midnight == nil, snapshot.isExcluded == nil else { return false }
            if snapshot.senderLocalDate == todayLabel {
                return snapshot.goalResult == nil || snapshot.goalResult?.calorieScope == .today
            }
            guard snapshot.streak == nil, snapshot.goalResult?.calorieScope == .history,
                  let oldest = calendar.date(byAdding: .day, value: -historyDayCount, to: today) else { return false }
            return snapshot.senderLocalDate >= CalorieCardSnapshot.localDate(for: oldest, calendar: calendar)
                && snapshot.senderLocalDate < todayLabel
        }
    }

}
