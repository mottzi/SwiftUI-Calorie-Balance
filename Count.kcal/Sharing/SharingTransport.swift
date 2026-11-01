import Foundation

@MainActor
/// Service-verified identity and owner-controlled consent contract.
/// Consent writes use compare-and-swap revisions; duplicate mutation IDs return their original result.
/// The contract does not allow old grants to be recreated.
protocol SharingTransport {

    /// Reports the service account state and its verified identity.
    func accountStatus() async throws -> SharingAccountStatus

    /// Loads the connections visible to the supplied account.
    func fetchConnections(for account: SharingIdentity) async throws -> [SharingConnection]

    /// Commits one consent event under the supplied account's authority.
    func commit(_ mutation: SharingConsentMutation, as account: SharingIdentity) async throws -> SharingConnection

    /// Records this account's readiness for a granted scope generation.
    func provision(_ request: SharingProvisionRequest) async throws -> SharingProvisionReceipt

    /// Removes access described by one durable revocation operation.
    func revoke(_ operation: SharingRevocation) async throws

    /// Returns this device's current publisher lease, if it has one.
    func publisherLease(account: SharingIdentity, deviceID: UUID) async throws -> SharingPublisherLease?

    /// Claims publisher authority for this device and returns its new lease.
    func claimPublisher(account: SharingIdentity, deviceID: UUID,
                        policy: SharingPublisherClaim) async throws -> SharingPublisherLease

    /// Stores an authorized snapshot for its sender, connection, and scope.
    func publish(_ envelope: SharedSnapshotEnvelope) async throws

    /// Returns freshly verified consent with the snapshots the account may read.
    func fetchSnapshots(
        connection: SharingConnection,
        as account: SharingIdentity
    ) async throws -> (connection: SharingConnection?, snapshots: [SharedSnapshotEnvelope])

    /// Removes expired outgoing payloads, with no assumption of a server TTL.
    /// The adapter must fence every deletion against this exact publisher lease.
    func cleanup(account: SharingIdentity, lease: SharingPublisherLease, now: Date) async throws

}

/// Authority required to select the iPhone that sends card updates.
enum SharingPublisherClaim: Equatable {

    /// Select this device only if no other device owns publication.
    case ifUnclaimed

    /// Replace an existing publisher after the user confirms the change.
    case replaceExisting

}
