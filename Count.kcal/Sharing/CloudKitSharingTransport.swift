import CloudKit
import Foundation

@MainActor
/// CloudKit-backed transport that uses CloudKit account identity and owner-controlled writes.
/// Setup records carry discovery URLs; each owner's read-only control hierarchy supplies consent.
final class CloudKitSharingTransport: SharingTransport {

    /// Name used in the local account identity and owner-controlled records.
    var displayName: String

    /// Invitations still waiting for recipient acceptance or inviter setup.
    private(set) var pendingInvitations: [SharingPendingInvitation] = []

    /// Optional CloudKit container supplied by a caller.
    private let injectedContainer: CKContainer?

    /// CloudKit container used by this transport.
    private lazy var container = injectedContainer ?? CKContainer(identifier: Self.containerIdentifier)

    /// Private zone that stores sharing setup, control, and publication records.
    private let zoneID = CKRecordZone.ID(zoneName: "CalorieSharing", ownerName: CKCurrentUserDefaultName)

    /// JSON encoder for encrypted CloudKit payload fields.
    private let encoder = JSONEncoder()

    /// JSON decoder for encrypted CloudKit payload fields.
    private let decoder = JSONDecoder()

    /// Account identity whose records are cached in this transport.
    private var currentIdentity: SharingIdentity?

    private var privateReader: SharingCloudReader?
    private var sharedReader: SharingCloudReader?
    private var readerAccountID: String?

    func prioritize(connectionID: UUID?) {
        sharedReader?.prioritizedZoneIDs = connectionID.flatMap { directories[$0]?.setupID.zoneID }.map { [$0] } ?? []
    }

    private func resetReaders() {
        privateReader?.invalidate()
        sharedReader?.invalidate()
        privateReader = nil
        sharedReader = nil
        readerAccountID = nil
    }

    /// Private and accepted shared setup records cached by connection ID.
    private var directories: [UUID: Directory] = [:]

    /// Resolved connection state cached by connection ID.
    private var connections: [UUID: SharingConnection] = [:]

    /// Clock used for proposal and CloudKit record timestamps.
    private var clock: () -> Date

    init(container: CKContainer? = nil, displayName: String, clock: @escaping () -> Date = Date.init) {
        self.injectedContainer = container
        self.displayName = displayName
        self.clock = clock
    }

    /// Reports iCloud account status and clears cached records after a known account change.
    func accountStatus() async throws -> SharingAccountStatus {

        switch try await container.accountStatus() {
        case .available:
            let id = try await container.userRecordID().recordName
            let identity = SharingIdentity(id: id, displayName: displayName)
            if currentIdentity?.id != id { resetReaders(); directories = [:]; connections = [:]; pendingInvitations = [] }
            currentIdentity = identity
            return .available(identity)
        case .noAccount:
            resetReaders()
            currentIdentity = nil; directories = [:]; connections = [:]; pendingInvitations = []
            return .signedOut
        default: return .uncertain
        }
    }

    /// Defers private metadata creation until the system prepares invitation delivery.
    func invitation(id: UUID, scopes: Set<SharingScope>) -> SharingCloudInvitation {
        SharingCloudInvitation(id: id, container: container) {
            try await self.prepareInvitation(id: id, scopes: scopes)
        }
    }

    /// Saves metadata for one private recipient selected in Apple's invitation sheet.
    func prepareInvitation(id: UUID, scopes: Set<SharingScope>) async throws -> CKShare {

        let account = try await authenticated()
        guard !scopes.isEmpty else { throw SharingError.invalidProposal }
        try await ensureZone()
        try await configureSubscriptions(accountID: account.id)
        let directoryID = CKRecord.ID(recordName: "directory-\(id)", zoneID: zoneID)
        if let existing = try await optionalRecord(directoryID, database: container.privateCloudDatabase) {
            let directory: Directory = try decode(existing, key: "payload")
            guard directory.ownerID == account.id, let draft = directory.invitation,
                  draft.scopes == scopes else { throw SharingError.invalidConnection }
            guard draft.expiresAt > clock() else { throw SharingError.proposalExpired }
            directories[id] = directory
            let invitation = try await invitation(for: id)
            return try await invitation.prepareShare()
        }
        let root = CKRecord(recordType: RecordType.setup, recordID: CKRecord.ID(recordName: "setup-\(id)", zoneID: zoneID))
        root["connectionID"] = id.uuidString
        let share = CKShare(rootRecord: root)
        share.publicPermission = .none
        share[CKShare.SystemFieldKey.title] = String(localized: "Invitation to share calorie cards")
        let now = clock()
        let draft = InvitationDraft(
            scopes: scopes,
            proposalID: UUID(),
            mutationID: UUID(),
            createdAt: now,
            expiresAt: now.addingTimeInterval(SharingConsent.requestLifetime)
        )
        var directory = Directory(connectionID: id, setupID: root.recordID, ownerID: account.id)
        directory.invitation = draft
        let stored = CKRecord(recordType: RecordType.directory, recordID: directoryID)
        try encode(directory, into: stored, key: "payload")
        try await require(account.id)
        let saved = try await save([root, share, stored], database: container.privateCloudDatabase)
        try await require(account.id)
        guard let result = saved.first(where: { $0.recordID == share.recordID }) as? CKShare,
              let url = result.url else { throw SharingError.unavailable }
        directories[id] = directory
        pendingInvitations.removeAll { $0.id == id }
        pendingInvitations.append(draft.presentation(id: id, url: url))
        return result
    }

    #if DEBUG
    /// Supplies a participant for SDK test tools without changing the native invitation flow.
    func prepareInvitation(id: UUID, email: String, name: String, scopes: Set<SharingScope>) async throws -> URL {

        let share = try await prepareInvitation(id: id, scopes: scopes)
        let participant = try await container.shareParticipant(forEmailAddress: email)
        participant.permission = .readWrite
        share.addParticipant(participant)
        let saved = try await container.privateCloudDatabase.save(share)
        guard let url = (saved as? CKShare)?.url else { throw SharingError.unavailable }
        return url
    }
    #endif

    /// Cancels a pending invitation and removes any connection state created from its acceptance.
    func cancelPendingInvitation(id: UUID) async throws {

        let account = try await authenticated()
        let directoryID = CKRecord.ID(recordName: "directory-\(id)", zoneID: zoneID)
        let stored = try await optionalRecord(directoryID, database: container.privateCloudDatabase)
        guard let stored else { pendingInvitations.removeAll { $0.id == id }; directories[id] = nil; return }
        var directory: Directory = try decode(stored, key: "payload")
        guard directory.ownerID == account.id, let draft = directory.invitation else { throw SharingError.wrongAccount }
        directories[id] = directory
        let setup = try await optionalRecord(directory.setupID, database: container.privateCloudDatabase)
        if setup == nil {
            guard try await optionalRecord(CKRecord.ID(recordName: "control-\(id)", zoneID: zoneID),
                database: container.privateCloudDatabase) == nil else { throw SharingError.invalidConnection }
            try await delete([directoryID], database: container.privateCloudDatabase)
            directories[id] = nil
            pendingInvitations.removeAll { $0.id == id }
            return
        }
        if let connection = try await resolve(directory, account: account) {
            guard let peer = connection.peer(of: account.id) else { throw SharingError.wrongAccount }
            var grants = connection.grants
            for scope in draft.scopes where !grants.contains(where: {
                $0.scope == scope && $0.generation == draft.proposalID
            }) {
                grants.append(SharingGrant(scope: scope, generation: draft.proposalID))
            }
            // a bootstrap can outlive a completed control write; remove its
            // initial scope permissions before forgetting grants in a tombstone
            for grant in grants {
                for direction in SharingDirection.allCases {
                    try await revoke(
                        SharingRevocation(
                            id: UUID(),
                            connectionID: id,
                            accountID: account.id,
                            peerID: peer.id,
                            scope: grant.scope,
                            generation: grant.generation,
                            direction: direction
                        )
                    )
                }
            }
            if !connection.removed {
                let mutation = SharingConsentMutation(
                    id: UUID(),
                    connection: connection,
                    actorID: account.id,
                    expectedRevision: connection.revision,
                    action: .remove,
                    createdAt: clock()
                )
                _ = try await commit(mutation, as: account)
            }
            directory.invitation = nil
            try await saveDirectory(directory)
            directories[id] = directory
        } else {
            let db = container.privateCloudDatabase
            if let setup = try await optionalRecord(directory.setupID, database: db) {
                if let shareID = setup.share?.recordID {
                    do { try await delete([shareID], database: db) }
                    catch let error as CKError where [.unknownItem, .zoneNotFound, .userDeletedZone].contains(error.code) { }
                }
                try await delete([setup.recordID], database: db)
            }
            try await delete([CKRecord.ID(recordName: "directory-\(id)", zoneID: zoneID)], database: db)
            directories[id] = nil
        }
        pendingInvitations.removeAll { $0.id == id }
    }

    /// Writes the current display name to this account's owner-controlled records.
    func updateProfileName() async throws {

        let account = try await authenticated()
        for directory in directories.values {
            guard let connection = try await resolve(directory, account: account) else { continue }
            let controls = try await controlRecords(directory: directory, connection: connection, account: account)
            if let own = controls.first(where: { $0.ownerID == account.id }) {
                try await writeControl(own.document, existing: own.record, directory: directory, account: account)
            }
        }
    }

    /// Loads the existing private setup share for Apple's invitation sheet.
    func invitation(for connectionID: UUID) async throws -> SharingCloudInvitation {

        let account = try await authenticated()
        guard let directory = directories[connectionID], directory.ownerID == account.id,
              let draft = directory.invitation else { throw SharingError.invalidConnection }
        guard draft.expiresAt > clock() else { throw SharingError.proposalExpired }
        let setup = try await container.privateCloudDatabase.record(for: directory.setupID)
        guard let shareID = setup.share?.recordID,
              let share = try await container.privateCloudDatabase.record(for: shareID) as? CKShare,
              share.publicPermission == .none else { throw SharingError.invalidConnection }
        let prepared = try await prepareInvitationShare(share, expectedID: draft.participantID)
        return SharingCloudInvitation(id: connectionID, share: prepared, container: container)
    }

    /// Returns the URL of a cached setup share for diagnostic tools.
    func invitationURL(for connectionID: UUID) async throws -> URL {

        guard let directory = directories[connectionID] else { throw SharingError.invalidConnection }
        let setup = try await database(for: directory).record(for: directory.setupID)
        guard let shareID = setup.share?.recordID,
              let share = try await database(for: directory).record(for: shareID) as? CKShare,
              let url = share.url else { throw SharingError.unavailable }
        return url
    }

    /// Opening the system invitation imports metadata only. In-app acceptance is a
    /// separate action, so no calorie scope becomes active here.
    @discardableResult
    func importInvitation(_ metadata: CKShare.Metadata) async throws -> UUID {

        guard let url = metadata.share.url else { throw SharingError.invalidConnection }
        let metadata = try await metadataWithRoot(for: url)
        guard metadata.rootRecord?.recordType == RecordType.setup,
              metadata.containerIdentifier == Self.containerIdentifier,
              metadata.share.publicPermission == .none,
              [.readOnly, .readWrite].contains(metadata.participantPermission),
              let owner = metadata.ownerIdentity.userRecordID?.recordName else { throw SharingError.invalidConnection }
        let account = try await authenticated()
        guard owner != account.id,
              isCurrentParticipant(metadata, account: account, permission: metadata.participantPermission)
        else { throw SharingError.wrongAccount }
        if metadata.participantStatus != .accepted { _ = try await container.accept(metadata) }
        guard let rootID = metadata.hierarchicalRootRecordID else { throw SharingError.invalidConnection }
        let setup = try await container.sharedCloudDatabase.record(for: rootID)
        guard setup.recordType == RecordType.setup, setup.share?.recordID == metadata.share.recordID,
              let idString = setup["connectionID"] as? String, let id = UUID(uuidString: idString)
        else { throw SharingError.invalidConnection }
        let directory = Directory(connectionID: id, setupID: setup.recordID, ownerID: owner)
        directories[id] = directory
        try await saveDirectory(directory)
        return id
    }

    /// Resolves an iCloud share URL and imports its setup metadata.
    @discardableResult
    func importInvitation(url: URL) async throws -> UUID {
        guard url.scheme == "https",
              url.host == "www.icloud.com" || url.host == "icloud.com"
        else { throw SharingError.invalidConnection }
        let metadata = try await container.shareMetadata(for: url)
        return try await importInvitation(metadata)
    }

    /// Loads owner directories and resolves each connection from verified control records.
    func fetchConnections(for account: SharingIdentity) async throws -> [SharingConnection] {

        try await require(account.id)
        try await ensureZone()
        try await configureSubscriptions(accountID: account.id)
        // Readers own discovery checkpoints, including shared-zone additions/deletions.
        try await privateReader?.fetch()
        try await sharedReader?.fetch()
        let own = try await allRecords(in: zoneID, database: container.privateCloudDatabase)
        for record in own where record.recordType == RecordType.directory {
            let directory: Directory = try decode(record, key: "payload")
            directories[directory.connectionID] = directory
        }
        // accepted metadata survives reinstall in the shared database; discover it
        // independently of the local cache, then verify its owner-controlled control
        for setup in sharedReader?.records ?? [] where setup.recordType == RecordType.setup {
            guard let raw = setup["connectionID"] as? String, let id = UUID(uuidString: raw),
                  let owner = setup.creatorUserRecordID?.recordName else { continue }
            directories[id] = Directory(connectionID: id, setupID: setup.recordID, ownerID: owner)
        }
        var result: [SharingConnection] = []
        pendingInvitations = []
        let ordered = directories.values.sorted {
            if ($0.invitation == nil) != ($1.invitation == nil) { return $0.invitation == nil }
            return $0.connectionID.uuidString < $1.connectionID.uuidString
        }
        for original in ordered {
            // a verified removal is terminal; the same connection ID cannot be accepted again
            if let removed = connections[original.connectionID], removed.removed {
                result.append(removed)
                continue
            }
            do {
                var directory = original
                if directory.invitation != nil, directory.ownerID == account.id {
                    guard let prepared = try await bindAcceptedInvitation(directory, account: account) else { continue }
                    directory = prepared
                }
                if let connection = try await resolve(directory, account: account) {
                    connections[connection.id] = connection
                    result.append(connection)
                } else if directory.ownerID != account.id {
                    pendingInvitations.append(SharingPendingInvitation(id: directory.connectionID, stage: .awaitingInviter))
                }
            } catch let error as CKError where [
                .unknownItem, .zoneNotFound, .userDeletedZone, .permissionFailure
            ].contains(error.code) {
                // the owner removed this metadata hierarchy; mark a learned loss
                // rather than keeping a cached active relationship
                if var prior = connections[original.connectionID] {
                    prior.removed = true; prior.grants = []; prior.proposal = nil
                    connections[prior.id] = prior; result.append(prior)
                }
            }
        }
        return result
    }

    /// Stores one consent mutation in this account's control record and advertises its URL.
    func commit(_ mutation: SharingConsentMutation, as account: SharingIdentity) async throws -> SharingConnection {

        try await require(account.id)
        guard mutation.actorID == account.id else { throw SharingError.wrongAccount }
        try await ensureZone()
        var directory = directories[mutation.connection.id]
        if directory == nil {
            guard mutation.connection.inviter.id == account.id,
                  case .propose = mutation.action else { throw SharingError.invalidConnection }
            directory = try await createSetup(for: mutation.connection, account: account)
            directories[mutation.connection.id] = directory
            try await saveDirectory(directory!)
        }
        guard let directory else { throw SharingError.invalidConnection }
        let existing = try await resolve(directory, account: account)
        let controls = try await controlRecords(
            directory: directory,
            connection: existing ?? mutation.connection,
            account: account
        )
        let own = controls.first { $0.ownerID == account.id }
        if let own, own.document.events.contains(where: { $0.id == mutation.id }) {
            guard let existing else { throw SharingError.invalidConnection }
            // a prior attempt may have saved the owner record but failed while
            // advertising its URL. Retry repairs discovery without replaying consent
            try await writeControl(own.document, existing: own.record, directory: directory, account: account)
            return existing
        }
        let updated = try SharingConsent.applying(mutation, to: existing, now: clock())
        var document = own?.document ?? SharingControlDocument(
            connection: mutation.connection,
            events: [],
            receipts: [],
            publisherGeneration: nil
        )
        document.events.append(mutation)
        try await writeControl(document, existing: own?.record, directory: directory, account: account)
        connections[updated.id] = updated
        return updated
    }

    /// Verifies both scope shares and records this account's provisioning receipt.
    func provision(_ request: SharingProvisionRequest) async throws -> SharingProvisionReceipt {

        let account = try await authenticated()
        guard account.id == request.accountID, let directory = directories[request.connection.id],
              let connection = try await resolve(directory, account: account), !connection.removed,
              connection.grants.contains(where: { $0.scope == request.scope && $0.generation == request.generation }),
              let peer = connection.peer(of: account.id) else { throw SharingError.staleGeneration }
        let setup = try await database(for: directory).record(for: directory.setupID)
        let field = scopeField(accountID: account.id, connection: connection, scope: request.scope)
        let rootID = scopeRootID(connectionID: connection.id, scope: request.scope, generation: request.generation)
        var root = try await optionalRecord(rootID, database: container.privateCloudDatabase)
        if root == nil {
            root = CKRecord(recordType: RecordType.scope, recordID: rootID)
            root!["connectionID"] = connection.id.uuidString
            root!["scope"] = request.scope.rawValue
            root!["generation"] = request.generation.uuidString
            root!["senderID"] = account.id
            let share = try await createShare(
                root: root!,
                peerID: peer.id,
                permission: .readOnly,
                title: String(localized: "Calorie card")
            )
            setup[field] = share.url?.absoluteString
            try await save([setup], database: database(for: directory))
        } else if let shareID = root?.share?.recordID,
                  let share = try await container.privateCloudDatabase.record(for: shareID) as? CKShare,
                  setup[field] as? String != share.url?.absoluteString {
            // a failed mailbox save can leave the previous generation's URL
            setup[field] = share.url?.absoluteString
            try await save([setup], database: database(for: directory))
        }
        let peerField = scopeField(accountID: peer.id, connection: connection, scope: request.scope)
        guard let peerSetup = setup[peerField] else { throw SharingError.peerSetupPending }
        guard let string = peerSetup as? String,
              let url = URL(string: string)
        else { throw SharingError.invalidConnection }
        let incoming = try await verifiedRoot(
            url: url,
            expectedOwner: peer.id,
            account: account,
            permission: .readOnly,
            connectionID: connection.id,
            scope: request.scope,
            generation: request.generation
        )
        guard incoming.recordType == RecordType.scope,
              incoming["connectionID"] as? String == connection.id.uuidString,
              incoming["scope"] as? String == request.scope.rawValue,
              incoming["generation"] as? String == request.generation.uuidString,
              incoming["senderID"] as? String == peer.id else { throw SharingError.invalidConnection }
        let receipt = SharingProvisionReceipt(
            connectionID: connection.id,
            accountID: account.id,
            scope: request.scope,
            generation: request.generation
        )
        let controls = try await controlRecords(directory: directory, connection: connection, account: account)
        guard let own = controls.first(where: { $0.ownerID == account.id }) else { throw SharingError.invalidConnection }
        var doc = own.document
        if !doc.receipts.contains(receipt) { doc.receipts.append(receipt) }
        try await writeControl(doc, existing: own.record, directory: directory, account: account)
        return receipt
    }

    /// Deletes the requested scope share and, for outgoing access, its card records.
    func revoke(_ operation: SharingRevocation) async throws {

        let account = try await authenticated()
        guard account.id == operation.accountID else { throw SharingError.wrongAccount }
        let db: CKDatabase
        let shareID: CKRecord.ID?
        switch operation.direction {
        case .outgoing:
            db = container.privateCloudDatabase
            let rootID = scopeRootID(
                connectionID: operation.connectionID,
                scope: operation.scope,
                generation: operation.generation
            )
            guard let root = try await optionalRecord(rootID, database: db) else { return }
            shareID = root.share?.recordID
        case .incoming:
            db = container.sharedCloudDatabase
            // the deterministic root identity survives restart and mailbox loss
            // leaving cannot depend on fetching connection metadata first
            let incomingZone = CKRecordZone.ID(zoneName: zoneID.zoneName, ownerName: operation.peerID)
            let incomingRoot = CKRecord.ID(
                recordName: scopeRootID(
                    connectionID: operation.connectionID,
                    scope: operation.scope,
                    generation: operation.generation
                ).recordName,
                zoneID: incomingZone
            )
            let root: CKRecord?
            do { root = try await optionalRecord(incomingRoot, database: db) }
            catch let error as CKError where error.code == .permissionFailure { return }
            guard let root else { return }
            guard root["connectionID"] as? String == operation.connectionID.uuidString,
                  root["scope"] as? String == operation.scope.rawValue,
                  root["generation"] as? String == operation.generation.uuidString,
                  root["senderID"] as? String == operation.peerID,
                  let id = root.share?.recordID else { throw SharingError.invalidConnection }
            // delete the CKShare, never the other owner's root or calorie record
            shareID = id
        }
        if let shareID {
            do { try await delete([shareID], database: db) }
            catch let error as CKError where [.unknownItem, .zoneNotFound, .userDeletedZone].contains(error.code) { }
        }
        if operation.direction == .outgoing {
            let records = try await allRecords(in: zoneID, database: db)
            let rootID = scopeRootID(
                connectionID: operation.connectionID,
                scope: operation.scope,
                generation: operation.generation
            )
            let children = records.filter { $0.parent?.recordID == rootID }.map(\.recordID)
            // cloudkit validates parent links during deletion; remove children
            // before their root, including retries after the CKShare is gone
            if !children.isEmpty { try await delete(children, database: db) }
            if records.contains(where: { $0.recordID == rootID }) { try await delete([rootID], database: db) }
        }
    }

    /// Returns this account's lease only if it belongs to the requested device ID.
    func publisherLease(account: SharingIdentity, deviceID: UUID) async throws -> SharingPublisherLease? {

        try await require(account.id)
        guard let record = try await optionalRecord(
            CKRecord.ID(recordName: "publisher", zoneID: zoneID),
            database: container.privateCloudDatabase
        ) else { return nil }
        let lease: SharingPublisherLease = try decode(record, key: "payload")
        return lease.accountID == account.id && lease.deviceID == deviceID ? lease : nil
    }

    /// Claims or reuses a publisher lease, then repairs its generation in accessible controls.
    func claimPublisher(account: SharingIdentity, deviceID: UUID,
                        policy: SharingPublisherClaim = .replaceExisting) async throws -> SharingPublisherLease {

        try await require(account.id)
        try await ensureZone()
        let id = CKRecord.ID(recordName: "publisher", zoneID: zoneID)
        let existing = try await optionalRecord(
            id,
            database: container.privateCloudDatabase
        )
        let old: SharingPublisherLease? = try existing.map { try decode($0, key: "payload") }
        if let old {
            guard old.accountID == account.id else { throw SharingError.wrongAccount }
            if policy == .ifUnclaimed, old.deviceID != deviceID { throw SharingError.publisherNotOwned }
        }
        let record = existing ?? CKRecord(recordType: RecordType.publisher, recordID: id)
        let lease = old.flatMap { $0.accountID == account.id && $0.deviceID == deviceID ? $0 : nil }
            ?? SharingPublisherLease(accountID: account.id, deviceID: deviceID, generation: UUID())
        try encode(lease, into: record, key: "payload")
        record["senderTimeZone"] = TimeZone.current.identifier
        record["lastClaim"] = clock()
        // the publisher record's change tag also rejects a concurrent first-device claim
        try await save([record], database: container.privateCloudDatabase)
        // retrying the same physical publisher also repairs interrupted metadata propagation
        for directory in directories.values {
            if connections[directory.connectionID]?.removed == true { continue }
            let connection: SharingConnection
            do {
                guard let resolved = try await resolve(directory, account: account) else { continue }
                connection = resolved
            } catch let error as CKError where [
                .unknownItem, .zoneNotFound, .userDeletedZone, .permissionFailure
            ].contains(error.code) {
                // An inaccessible old relationship must not block this account's
                // publisher lease or consent on another, accessible relationship.
                continue
            }
            let publisher = try await verifiedPublisher(account: account, lease: lease)
            _ = try await repairPublisherControl(
                connection: connection,
                directory: directory,
                account: account,
                lease: lease,
                publisher: publisher
            )
        }
        return lease
    }

    /// Stores a supported snapshot for a ready scope under the current publisher lease.
    func publish(_ envelope: SharedSnapshotEnvelope) async throws {

        let account = try await authenticated()
        // publication can start before foreground discovery has filled this process's directory cache
        if directories[envelope.connectionID] == nil { _ = try await fetchConnections(for: account) }
        guard account.id == envelope.senderID,
              let directory = directories[envelope.connectionID],
              let connection = try await resolve(directory, account: account),
              connection.isReady(envelope.scope),
              connection.grants.contains(where: {
                  $0.scope == envelope.scope && $0.generation == envelope.consentGeneration
              }),
              SharingDateWindow.permits(
                  envelope.snapshot,
                  scope: envelope.scope,
                  now: clock(),
                  latestSenderTimeZone: .current
              ),
              envelope.snapshot.isSupported
        else { throw SharingError.staleGeneration }
        let publisherID = CKRecord.ID(recordName: "publisher", zoneID: zoneID)
        var publisher = try await container.privateCloudDatabase.record(for: publisherID)
        let lease: SharingPublisherLease = try decode(publisher, key: "payload")
        guard lease.accountID == account.id,
              lease.generation == envelope.publisherGeneration
        else { throw SharingError.publisherNotOwned }
        publisher = try await repairPublisherControl(
            connection: connection,
            directory: directory,
            account: account,
            lease: lease,
            publisher: publisher
        )
        let rootID = scopeRootID(
            connectionID: envelope.connectionID,
            scope: envelope.scope,
            generation: envelope.consentGeneration
        )
        let root = try await container.privateCloudDatabase.record(for: rootID)
        guard root.share != nil else { throw SharingError.staleGeneration }
        let id = CKRecord.ID(
            recordName: "card-\(envelope.connectionID)-\(envelope.scope.rawValue)-"
                + "\(envelope.consentGeneration)-\(envelope.snapshot.senderLocalDate)",
            zoneID: zoneID
        )
        let record = try await optionalRecord(
            id,
            database: container.privateCloudDatabase
        ) ?? CKRecord(
            recordType: RecordType.card,
            recordID: id
        )
        if let prior: SharedSnapshotEnvelope = try? decode(record, key: "payload"),
           prior.snapshot.capturedAt > envelope.snapshot.capturedAt {
            return
        }
        record.parent = CKRecord.Reference(recordID: rootID, action: .none)
        try encode(envelope, into: record, key: "payload")
        // the publisher authority joins the same-zone atomic save
        // an old change tag cannot win after publisher takeover
        publisher["lastPublication"] = clock()
        publisher["senderTimeZone"] = TimeZone.current.identifier
        try await save([publisher, root, record], database: container.privateCloudDatabase)
    }

    /// Fetches peer cards for matching ready grants and filters them by the sender's date window.
    func fetchSnapshots(
        connection: SharingConnection,
        as account: SharingIdentity
    ) async throws -> (connection: SharingConnection?, snapshots: [SharedSnapshotEnvelope]) {

        try await require(account.id)
        guard let directory = directories[connection.id] else { return (nil, []) }
        let verified: SharingConnection
        do {
            guard let resolved = try await resolve(directory, account: account) else { return (nil, []) }
            verified = resolved
        } catch let error as CKError where [
            .unknownItem, .zoneNotFound, .userDeletedZone, .permissionFailure
        ].contains(error.code) {
            // After relaunch, discovery may have no in-memory copy to mark removed.
            // The persisted connection supplies that copy once its setup loss is verified.
            var removed = connection
            removed.removed = true
            removed.grants = []
            removed.proposal = nil
            connections[removed.id] = removed
            return (removed, [])
        }
        guard let peer = verified.peer(of: account.id) else { return (nil, []) }
        guard !verified.removed else { return (verified, []) }
        let setup = try await database(for: directory).record(for: directory.setupID)
        var result: [SharedSnapshotEnvelope] = []
        var recordsByZone: [CKRecordZone.ID: [CKRecord]] = [:]
        for grant in verified.grants where verified.isReady(grant.scope)
            && connection.grants.contains(where: { $0.scope == grant.scope && $0.generation == grant.generation }) {
            let key = scopeField(accountID: peer.id, connection: verified, scope: grant.scope)
            guard let raw = setup[key] as? String, let url = URL(string: raw) else { continue }
            let root: CKRecord
            do {
                root = try await verifiedRoot(
                    url: url,
                    expectedOwner: peer.id,
                    account: account,
                    permission: .readOnly,
                    connectionID: connection.id,
                    scope: grant.scope,
                    generation: grant.generation
                )
            } catch let error as CKError where [
                .unknownItem, .zoneNotFound, .userDeletedZone, .permissionFailure
            ].contains(error.code) {
                throw SharingError.scopeRevoked(connectionID: connection.id, scope: grant.scope)
            }
            guard root["connectionID"] as? String == connection.id.uuidString,
                  root["scope"] as? String == grant.scope.rawValue,
                  root["generation"] as? String == grant.generation.uuidString else { throw SharingError.staleGeneration }
            if recordsByZone[root.recordID.zoneID] == nil {
                recordsByZone[root.recordID.zoneID] = try await allRecords(
                    in: root.recordID.zoneID, database: container.sharedCloudDatabase
                )
            }
            for record in recordsByZone[root.recordID.zoneID] ?? []
            where record.recordType == RecordType.card && record.parent?.recordID == root.recordID {
                let envelope: SharedSnapshotEnvelope = try decode(record, key: "payload")
                guard envelope.connectionID == verified.id, envelope.senderID == peer.id,
                      envelope.scope == grant.scope, envelope.consentGeneration == grant.generation,
                      envelope.publisherGeneration == verified.publisherGenerations[peer.id] else { continue }
                guard envelope.snapshot.isSupported else { throw SharingError.unsupportedSchema }
                guard envelope.snapshot.capturedAt <= clock() else { continue }
                result.append(envelope)
            }
        }
        let latestZone = result.max(by: { $0.snapshot.capturedAt < $1.snapshot.capturedAt })
            .flatMap { TimeZone(identifier: $0.snapshot.timeZoneIdentifier) }
        let snapshots = result.filter {
            SharingDateWindow.permits(
                $0.snapshot,
                scope: $0.scope,
                now: clock(),
                latestSenderTimeZone: latestZone
            )
        }
        return (verified, snapshots)
    }

    /// Deletes expired card records in batches fenced by the current publisher record.
    func cleanup(account: SharingIdentity, lease: SharingPublisherLease, now: Date) async throws {

        try await require(account.id)
        var publisher = try await verifiedPublisher(account: account, lease: lease)
        guard let zoneName = publisher["senderTimeZone"] as? String,
              let senderZone = TimeZone(identifier: zoneName) else { throw SharingError.unavailable }
        let expired = try await allRecords(in: zoneID, database: container.privateCloudDatabase).filter { record in
            guard record.recordType == RecordType.card,
                  let envelope: SharedSnapshotEnvelope = try? decode(record, key: "payload") else { return false }
            return !SharingDateWindow.permits(
                envelope.snapshot,
                scope: envelope.scope,
                now: now,
                latestSenderTimeZone: senderZone
            )
        }.map(\.recordID)
        for start in stride(from: 0, to: expired.count, by: 100) {
            let ids = Array(expired[start..<min(start + 100, expired.count)])
            publisher["lastCleanup"] = now
            // the publisher's change tag fences its generation and sender calendar
            // a takeover or timezone change makes this batch fail atomically
            let result = try await container.privateCloudDatabase.modifyRecords(
                saving: [publisher],
                deleting: ids,
                savePolicy: .ifServerRecordUnchanged,
                atomically: true
            )
            guard let authority = result.saveResults[publisher.recordID] else { throw SharingError.unavailable }
            publisher = try authority.get()
            for id in ids {
                guard let deletion = result.deleteResults[id] else { throw SharingError.unavailable }
                try deletion.get()
            }
            try privateReader?.apply(saving: [publisher], deleting: ids)
        }
    }

    /// CloudKit container used by the app and its validation tools.
    nonisolated static let containerIdentifier = "iCloud.com.count.kcal.app"

}

extension CloudKitSharingTransport {

    /// Applies the fixed setup permission to the one recipient selected by Apple's sheet.
    private func prepareInvitationShare(_ share: CKShare, expectedID: String?) async throws -> CKShare {

        guard let recipient = try SharingCloudInvitation.recipient(
            in: share.participants,
            publicPermission: share.publicPermission,
            expectedID: expectedID
        ) else { return share }
        guard recipient.permission == .readOnly else { return share }

        // the system can save view-only access despite the sheet's edit-only setting
        // this share contains setup metadata only; calorie cards use separate read-only shares
        recipient.permission = .readWrite
        let saved = try await save([share], database: container.privateCloudDatabase)
        guard let prepared = saved.first as? CKShare else { throw SharingError.unavailable }
        guard prepared.participants.first(where: { $0.participantID == recipient.participantID })?.permission == .readWrite
            else { throw SharingError.invalidConnection }
        return prepared
    }

    /// Binds one accepted private participant to the original calorie-sharing proposal.
    private func bindAcceptedInvitation(_ original: Directory, account: SharingIdentity) async throws -> Directory? {

        guard original.ownerID == account.id, var draft = original.invitation else { throw SharingError.wrongAccount }
        if draft.expiresAt <= clock() {
            if let current = try await resolve(original, account: account), !current.grants.isEmpty {
                var completed = original
                completed.invitation = nil
                try await saveDirectory(completed)
                directories[completed.connectionID] = completed
                return completed
            }
            try await cancelPendingInvitation(id: original.connectionID)
            return nil
        }
        guard let root = try await optionalRecord(original.setupID, database: container.privateCloudDatabase),
              let shareID = root.share?.recordID,
              let share = try await optionalRecord(shareID, database: container.privateCloudDatabase) as? CKShare else {
            // a previous cancellation may have removed the share and stopped
            // before deleting the remaining metadata; finish that work
            try await cancelPendingInvitation(id: original.connectionID)
            return nil
        }
        guard root.recordType == RecordType.setup, root["connectionID"] as? String == original.connectionID.uuidString
            else { throw SharingError.invalidConnection }
        guard let url = share.url else { throw SharingError.unavailable }
        let recipient: CKShare.Participant?
        do {
            let prepared = try await prepareInvitationShare(share, expectedID: draft.participantID)
            recipient = try SharingCloudInvitation.recipient(
                in: prepared.participants,
                publicPermission: prepared.publicPermission,
                expectedID: draft.participantID
            )
        }
        catch let error as SharingError where [.invalidConnection, .multipleRecipients, .wrongAccount].contains(error) {
            // remove invalid metadata before any calorie-sharing proposal can be created
            try await cancelPendingInvitation(id: original.connectionID)
            throw error
        }
        guard let participant = recipient else {
            pendingInvitations.append(draft.presentation(id: original.connectionID, url: url))
            return nil
        }
        if draft.participantID == nil {
            // bind the recipient from the owner's server record, never from a display name or mailbox
            draft.participantID = participant.participantID
            var selected = original
            selected.invitation = draft
            try await saveDirectory(selected)
            directories[selected.connectionID] = selected
        }
        guard participant.acceptanceStatus == .accepted,
              let peerID = participant.userIdentity.userRecordID?.recordName else {
            pendingInvitations.append(draft.presentation(id: original.connectionID, url: url))
            return nil
        }
        guard peerID != account.id, peerID != CKCurrentUserDefaultName else { throw SharingError.wrongAccount }
        guard !connections.values.contains(where: {
            $0.id != original.connectionID && !$0.removed && $0.peer(of: account.id)?.id == peerID
        }) else {
            pendingInvitations.append(draft.presentation(id: original.connectionID, url: url))
            throw SharingError.invalidConnection
        }
        let peer = SharingIdentity(id: peerID, displayName: draft.name ?? String(localized: "Invited person"))
        let connection = SharingConnection(
            id: original.connectionID,
            containerIdentifier: Self.containerIdentifier,
            inviter: account,
            invitee: peer
        )
        let proposal = SharingProposal(
            id: draft.proposalID,
            proposerID: account.id,
            recipientID: peer.id,
            baseRevision: 0,
            scopes: draft.scopes,
            createdAt: draft.createdAt,
            expiresAt: draft.expiresAt
        )
        _ = try await commit(
            SharingConsentMutation(
                id: draft.mutationID,
                connection: connection,
                actorID: account.id,
                expectedRevision: 0,
                action: .propose(proposal),
                createdAt: draft.createdAt
            ),
            as: account
        )
        var completed = original
        completed.invitation = nil
        try await saveDirectory(completed)
        directories[completed.connectionID] = completed
        return completed
    }
    /// Returns the publisher record only if it still matches this account's lease.
    private func verifiedPublisher(account: SharingIdentity, lease: SharingPublisherLease) async throws -> CKRecord {

        guard lease.accountID == account.id else { throw SharingError.wrongAccount }
        let id = CKRecord.ID(recordName: "publisher", zoneID: zoneID)
        guard let record = try await optionalRecord(id, database: container.privateCloudDatabase),
              let current: SharingPublisherLease = try? decode(record, key: "payload"), current == lease else {
            throw SharingError.publisherNotOwned
        }
        return record
    }

    /// Repairs this account's control document after a publisher lease change.
    private func repairPublisherControl(connection: SharingConnection, directory: Directory, account: SharingIdentity,
                                        lease: SharingPublisherLease, publisher: CKRecord) async throws -> CKRecord {

        let controls = try await controlRecords(directory: directory, connection: connection, account: account)
        guard let own = controls.first(where: { $0.ownerID == account.id }) else {
            // an imported invitation has no recipient control until explicit acceptance
            guard connection.scopes.isEmpty else { throw SharingError.invalidConnection }
            return publisher
        }
        guard own.document.publisherGeneration != lease.generation else { return publisher }
        var document = own.document
        document.publisherGeneration = lease.generation
        try encode(document, into: own.record, key: "payload")
        publisher["lastControlUpdate"] = clock()
        let saved = try await save([publisher, own.record], database: container.privateCloudDatabase)
        guard let updated = saved.first(where: { $0.recordID == publisher.recordID })
        else { throw SharingError.unavailable }
        return updated
    }

    /// Returns the authenticated account or maps a signed-out status to an account error.
    private func authenticated() async throws -> SharingIdentity {

        do {
            guard case .available(let account) = try await accountStatus() else { throw SharingError.accountUnavailable }
            return account
        } catch let error as CKError where error.code == .notAuthenticated {
            throw SharingError.accountUnavailable
        }
    }
    /// Throws if the current CloudKit account does not match the requested ID.
    private func require(_ id: String) async throws {
        guard try await authenticated().id == id else { throw SharingError.wrongAccount }
    }

    /// Reuses the existing subscriptions with one incremental reader per database.
    private func configureSubscriptions(accountID: String) async throws {
        if readerAccountID == accountID, privateReader?.isActive == true, sharedReader?.isActive == true { return }
        resetReaders()
        let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                    appropriateFor: nil, create: true)
            .appendingPathComponent("Count/Sharing/CloudCache", isDirectory: true)
        let own = try SharingCloudReader(database: container.privateCloudDatabase, accountID: accountID,
                                        subscriptionID: "count-sharing-private", directory: directory)
        let shared = try SharingCloudReader(database: container.sharedCloudDatabase, accountID: accountID,
                                           subscriptionID: "count-sharing-shared", directory: directory)
        privateReader = own
        sharedReader = shared
        readerAccountID = accountID
    }

    private func reader(for database: CKDatabase) -> SharingCloudReader? {
        database.databaseScope == .private ? privateReader : sharedReader
    }

    /// Saves the configured private sharing zone.
    private func ensureZone() async throws {
        _ = try await container.privateCloudDatabase.save(CKRecordZone(zoneID: zoneID))
    }

    /// Selects the private database for an owned directory and the shared database for a peer.
    private func database(for directory: Directory) -> CKDatabase {
        directory.ownerID == currentIdentity?.id ? container.privateCloudDatabase : container.sharedCloudDatabase
    }

    /// Persists a directory payload in the private database.
    private func saveDirectory(_ directory: Directory) async throws {

        try await ensureZone()
        let id = CKRecord.ID(recordName: "directory-\(directory.connectionID)", zoneID: zoneID)
        let record = try await optionalRecord(
            id,
            database: container.privateCloudDatabase
        ) ?? CKRecord(
            recordType: RecordType.directory,
            recordID: id
        )
        try encode(directory, into: record, key: "payload")
        try await save([record], database: container.privateCloudDatabase)
    }
    /// Creates or reuses the read-write setup share for the invitee.
    private func createSetup(for connection: SharingConnection, account: SharingIdentity) async throws -> Directory {

        let id = CKRecord.ID(recordName: "setup-\(connection.id)", zoneID: zoneID)
        if try await optionalRecord(id, database: container.privateCloudDatabase) != nil {
            return Directory(connectionID: connection.id, setupID: id, ownerID: account.id)
        }
        let root = CKRecord(recordType: RecordType.setup, recordID: id)
        root["connectionID"] = connection.id.uuidString
        _ = try await createShare(
            root: root,
            peerID: connection.invitee.id,
            permission: .readWrite,
            title: String(localized: "Invitation to share calorie cards")
        )
        return Directory(connectionID: connection.id, setupID: id, ownerID: account.id)
    }
    /// Saves a private share with the selected permission and optional publisher authority record.
    private func createShare(root: CKRecord, peerID: String, permission: CKShare.ParticipantPermission,
                             title: String, authority: CKRecord? = nil) async throws -> CKShare {

        let share = CKShare(rootRecord: root)
        share.publicPermission = .none
        share[CKShare.SystemFieldKey.title] = title
        let participant = try await container.shareParticipant(forUserRecordID: CKRecord.ID(recordName: peerID))
        participant.permission = permission
        share.addParticipant(participant)
        let saved = try await save([root, share] + (authority.map { [$0] } ?? []), database: container.privateCloudDatabase)
        guard let result = saved.first(where: { $0.recordID == share.recordID }) as? CKShare,
              result.url != nil
        else { throw SharingError.unavailable }
        return result
    }
    /// Returns the setup field that advertises the account's control share.
    private func controlField(accountID: String, connection: SharingConnection) -> String {
        accountID == connection.inviter.id ? "inviterControl" : "inviteeControl"
    }

    /// Returns the setup field that advertises the account's share for one scope.
    private func scopeField(accountID: String, connection: SharingConnection, scope: SharingScope) -> String {
        (accountID == connection.inviter.id ? "inviter_" : "invitee_") + scope.rawValue
    }

    /// Builds the deterministic root record ID for one connection scope generation.
    private func scopeRootID(connectionID: UUID, scope: SharingScope, generation: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: "scope-\(connectionID)-\(scope.rawValue)-\(generation)", zoneID: zoneID)
    }

    /// Saves the owner's control document and advertises its share URL in setup metadata.
    private func writeControl(_ document: SharingControlDocument, existing: CKRecord?, directory: Directory,
                              account: SharingIdentity) async throws {

        let id = CKRecord.ID(recordName: "control-\(directory.connectionID)", zoneID: zoneID)
        let record = existing ?? CKRecord(recordType: RecordType.control, recordID: id)
        record["connectionID"] = directory.connectionID.uuidString
        record["ownerID"] = account.id
        var document = document
        if document.connection.inviter.id == account.id { document.connection.inviter.displayName = displayName }
        if document.connection.invitee.id == account.id { document.connection.invitee.displayName = displayName }
        var publisherAuthority: CKRecord?
        if let publisher = try await optionalRecord(
            CKRecord.ID(recordName: "publisher", zoneID: zoneID),
            database: container.privateCloudDatabase
        ),
           let lease: SharingPublisherLease = try? decode(publisher, key: "payload"), lease.accountID == account.id {
            document.publisherGeneration = lease.generation
            publisher["lastControlUpdate"] = clock()
            publisherAuthority = publisher
        }
        try encode(document, into: record, key: "payload")
        var url: URL?
        if existing == nil {
            guard let peer = document.connection.peer(of: account.id) else { throw SharingError.wrongAccount }
            url = try await createShare(
                root: record,
                peerID: peer.id,
                permission: .readOnly,
                title: String(localized: "Sharing permissions"),
                authority: publisherAuthority
            ).url
        } else {
            try await save([record] + (publisherAuthority.map { [$0] } ?? []), database: container.privateCloudDatabase)
            if let shareID = record.share?.recordID,
               let share = try await container.privateCloudDatabase.record(for: shareID) as? CKShare { url = share.url }
        }
        guard let url else { throw SharingError.unavailable }
        let setup = try await database(for: directory).record(for: directory.setupID)
        setup[controlField(accountID: account.id, connection: document.connection)] = url.absoluteString
        try await save([setup], database: database(for: directory))
    }
    /// Fetches and verifies the current participant and expected share root before returning the record.
    private func verifiedRoot(url: URL, expectedOwner: String, account: SharingIdentity,
                              permission: CKShare.ParticipantPermission, connectionID: UUID,
                              scope: SharingScope? = nil, generation: UUID? = nil) async throws -> CKRecord {

        let metadata = try await metadataWithRoot(for: url)
        guard metadata.containerIdentifier == Self.containerIdentifier,
              metadata.ownerIdentity.userRecordID?.recordName == expectedOwner,
              metadata.share.publicPermission == .none,
              isCurrentParticipant(metadata, account: account, permission: permission)
        else { throw SharingError.wrongAccount }
        guard let preview = metadata.rootRecord,
              preview["connectionID"] as? String == connectionID.uuidString else { throw SharingError.invalidConnection }
        if let scope, let generation {
            guard preview.recordType == RecordType.scope,
                  preview["scope"] as? String == scope.rawValue,
                  preview["generation"] as? String == generation.uuidString,
                  preview["senderID"] as? String == expectedOwner else { throw SharingError.staleGeneration }
        } else {
            guard preview.recordType == RecordType.control,
                  preview["ownerID"] as? String == expectedOwner else { throw SharingError.invalidConnection }
        }
        let newlyAccepted = metadata.participantStatus != .accepted
        if newlyAccepted { _ = try await container.accept(metadata) }
        guard let rootID = metadata.hierarchicalRootRecordID else { throw SharingError.invalidConnection }
        try await configureSubscriptions(accountID: account.id)
        if newlyAccepted || !(sharedReader?.records.contains(where: { $0.recordID == rootID }) ?? false) {
            try await sharedReader?.fetch()
        }
        let root = try await container.sharedCloudDatabase.record(for: rootID)
        guard root.share?.recordID == metadata.share.recordID else { throw SharingError.invalidConnection }
        return root
    }

    /// Checks the current participant's role, permission, status, and account record ID.
    private func isCurrentParticipant(_ metadata: CKShare.Metadata, account: SharingIdentity,
                                      permission: CKShare.ParticipantPermission) -> Bool {
        guard metadata.participantRole == .privateUser,
              metadata.participantPermission == permission,
              [.pending, .accepted].contains(metadata.participantStatus),
              let participant = metadata.share.currentUserParticipant,
              participant.role == .privateUser, participant.permission == permission,
              let name = participant.userIdentity.userRecordID?.recordName else { return false }
        // cloudkit may use this alias for the authenticated current participant
        // the alias does not identify an arbitrary peer
        return name == account.id || name == CKCurrentUserDefaultName
    }

    /// Fetches share metadata and the requested root fields through a checked continuation.
    private func metadataWithRoot(for url: URL) async throws -> CKShare.Metadata {

        try await withCheckedThrowingContinuation { continuation in
            let reply = MetadataReply(continuation)
            let operation = CKFetchShareMetadataOperation(shareURLs: [url])
            operation.shouldFetchRootRecord = true
            operation.rootRecordDesiredKeys = ["connectionID", "ownerID", "scope", "generation", "senderID"]
            operation.perShareMetadataResultBlock = { _, result in reply.finish(result) }
            operation.fetchShareMetadataResultBlock = { result in
                switch result {
                case .failure(let error): reply.finish(.failure(error))
                case .success: reply.finish(.failure(SharingError.unavailable))
                }
            }
            container.add(operation)
        }
    }

    /// Checks owner-controlled consent and reuses records already fetched by this resolve.
    private func controlRecords(directory: Directory, connection: SharingConnection,
                                account: SharingIdentity, setup suppliedSetup: CKRecord? = nil,
                                inviterControl: CKRecord? = nil) async throws -> [VerifiedControl] {

        let setup: CKRecord
        if let suppliedSetup { setup = suppliedSetup }
        else { setup = try await database(for: directory).record(for: directory.setupID) }
        var result: [VerifiedControl] = []
        for identity in [connection.inviter, connection.invitee] {
            let record: CKRecord
            if identity.id == connection.inviter.id, let inviterControl {
                record = inviterControl
            } else if identity.id == account.id {
                let id = CKRecord.ID(recordName: "control-\(connection.id)", zoneID: zoneID)
                guard let local = try await optionalRecord(id, database: container.privateCloudDatabase) else { continue }
                record = local
            } else {
                guard let raw = setup[controlField(accountID: identity.id, connection: connection)] as? String,
                      let url = URL(string: raw) else { continue }
                record = try await verifiedRoot(
                    url: url,
                    expectedOwner: identity.id,
                    account: account,
                    permission: .readOnly,
                    connectionID: connection.id
                )
            }
            let doc: SharingControlDocument = try decode(record, key: "payload")
            guard record.recordType == RecordType.control,
                  record["ownerID"] as? String == identity.id,
                  record["connectionID"] as? String == directory.connectionID.uuidString,
                  doc.connection.id == directory.connectionID,
                  doc.connection.inviter.id == connection.inviter.id,
                  doc.connection.invitee.id == connection.invitee.id,
                  doc.connection.containerIdentifier == Self.containerIdentifier,
                  doc.events.allSatisfy({ $0.actorID == identity.id }) else { throw SharingError.invalidConnection }
            result.append(VerifiedControl(ownerID: identity.id, record: record, document: doc))
        }
        return result
    }
    /// Reconstructs connection state from owner-attested controls and the current publisher lease.
    private func resolve(_ directory: Directory, account: SharingIdentity) async throws -> SharingConnection? {

        // recover the initial identity tuple from the inviter's owned control
        let setup = try await database(for: directory).record(for: directory.setupID)
        let seed: CKRecord
        if directory.ownerID == account.id {
            let id = CKRecord.ID(recordName: "control-\(directory.connectionID)", zoneID: zoneID)
            guard let own = try await optionalRecord(id, database: container.privateCloudDatabase) else { return nil }
            seed = own
        } else {
            guard let raw = setup["inviterControl"] as? String, let url = URL(string: raw) else { return nil }
            seed = try await verifiedRoot(
                url: url,
                expectedOwner: directory.ownerID,
                account: account,
                permission: .readOnly,
                connectionID: directory.connectionID
            )
        }
        let initial: SharingControlDocument = try decode(seed, key: "payload")
        guard initial.connection.id == directory.connectionID,
              initial.connection.inviter.id == directory.ownerID,
              initial.connection.peer(of: account.id) != nil,
              initial.connection.containerIdentifier == Self.containerIdentifier
        else { throw SharingError.invalidConnection }
        let controls = try await controlRecords(
            directory: directory,
            connection: initial.connection,
            account: account,
            setup: setup,
            inviterControl: seed
        )
        guard var connection = try SharingControlLedger.resolve(
            connectionID: directory.connectionID,
            containerIdentifier: Self.containerIdentifier,
            inviterID: directory.ownerID,
            accountID: account.id,
            controls: controls.map { SharingAttestedControl(ownerID: $0.ownerID, document: $0.document) }
        ) else { return nil }
        // a new lease is authoritative before its control update completes
        if let publisher = try await optionalRecord(
            CKRecord.ID(recordName: "publisher", zoneID: zoneID),
            database: container.privateCloudDatabase
        ),
           let lease: SharingPublisherLease = try? decode(publisher, key: "payload"), lease.accountID == account.id {
            connection.publisherGenerations[account.id] = lease.generation
        }
        connections[connection.id] = connection
        return connection
    }
    /// Returns nil for a missing item or zone and propagates other CloudKit errors.
    private func optionalRecord(_ id: CKRecord.ID, database: CKDatabase) async throws -> CKRecord? {
        do { return try await database.record(for: id) }
        catch let error as CKError where [.unknownItem, .zoneNotFound, .userDeletedZone].contains(error.code) { return nil }
    }

    @discardableResult
    /// Saves records atomically only if their server versions have not changed.
    private func save(_ records: [CKRecord], database: CKDatabase) async throws -> [CKRecord] {

        let result = try await database.modifyRecords(
            saving: records,
            deleting: [],
            savePolicy: .ifServerRecordUnchanged,
            atomically: true
        )
        let saved = try records.map { record in
            guard let result = result.saveResults[record.recordID] else { throw SharingError.unavailable }
            return try result.get()
        }
        try reader(for: database)?.apply(saving: saved)
        return saved
    }
    /// Deletes record IDs in batches of 200 and propagates CloudKit errors.
    private func delete(_ ids: [CKRecord.ID], database: CKDatabase) async throws {

        for start in stride(from: 0, to: ids.count, by: 200) {
            let batch = Array(ids[start..<min(start + 200, ids.count)])
            let result = try await database.modifyRecords(
                saving: [],
                deleting: batch,
                atomically: true
            )
            for result in result.deleteResults.values { try result.get() }
            try reader(for: database)?.apply(deleting: batch)
        }
    }
    /// Reads the incremental raw cache. Callers still verify live authority and consent.
    private func allRecords(in zone: CKRecordZone.ID, database: CKDatabase) async throws -> [CKRecord] {
        guard let account = currentIdentity else { throw SharingError.accountUnavailable }
        try await configureSubscriptions(accountID: account.id)
        guard let reader = reader(for: database) else { throw SharingError.unavailable }
        if !reader.hasFetched { try await reader.fetch() }
        return try reader.records(in: zone)
    }
    /// Encodes a value as UTF-8 JSON in an encrypted record field.
    private func encode<T: Encodable>(_ value: T, into record: CKRecord, key: String) throws {
        record.encryptedValues[key] = String(decoding: try encoder.encode(value), as: UTF8.self)
    }

    /// Decodes a UTF-8 JSON value from an encrypted record field.
    private func decode<T: Decodable>(_ record: CKRecord, key: String) throws -> T {
        guard let payload = record.encryptedValues[key] as? String else { throw SharingError.invalidConnection }
        return try decoder.decode(T.self, from: Data(payload.utf8))
    }

    /// One-shot bridge from CloudKit metadata callbacks to an async continuation.
    private final class MetadataReply: @unchecked Sendable {

        /// Lock that protects the pending continuation from duplicate callbacks.
        private let lock = NSLock()

        /// Continuation resumed by the first metadata result callback.
        private var continuation: CheckedContinuation<CKShare.Metadata, Error>?

        init(_ continuation: CheckedContinuation<CKShare.Metadata, Error>) { self.continuation = continuation }

        /// Resumes the continuation once and ignores later callback results.
        func finish(_ result: Result<CKShare.Metadata, Error>) {

            lock.lock()
            let pending = continuation
            continuation = nil
            lock.unlock()
            pending?.resume(with: result)
        }

    }
}

extension CloudKitSharingTransport {

    /// Local pointer to a setup share and its private invitation draft.
    private struct Directory: Codable {

        /// Connection identifier used by the sharing model.
        var connectionID: UUID

        /// CloudKit root record for the setup share.
        var setupID: CKRecord.ID

        /// Account that owns the setup share.
        var ownerID: String

        /// Original email invitation choices while binding is pending.
        var invitation: InvitationDraft?

        /// Field names used by the private directory payload.
        private enum CodingKeys: String, CodingKey {

            /// Connection identifier field.
            case connectionID

            /// Setup root record name field.
            case recordName

            /// Setup root zone name field.
            case zoneName

            /// Setup root zone owner field.
            case zoneOwnerName

            /// Setup share owner field.
            case ownerID

            /// Original invitation draft field.
            case invitation

        }

        init(connectionID: UUID, setupID: CKRecord.ID, ownerID: String) {
            self.connectionID = connectionID; self.setupID = setupID; self.ownerID = ownerID
        }

        /// Decodes the setup record ID from its record and zone fields.
        init(from decoder: Decoder) throws {

            let c = try decoder.container(keyedBy: CodingKeys.self)
            connectionID = try c.decode(UUID.self, forKey: .connectionID)
            ownerID = try c.decode(String.self, forKey: .ownerID)
            invitation = try c.decodeIfPresent(InvitationDraft.self, forKey: .invitation)
            setupID = CKRecord.ID(
                recordName: try c.decode(String.self, forKey: .recordName),
                zoneID: CKRecordZone.ID(
                    zoneName: try c.decode(String.self, forKey: .zoneName),
                    ownerName: try c.decode(String.self, forKey: .zoneOwnerName)
                )
            )
        }

        /// Encodes the setup record ID as separate record and zone fields.
        func encode(to encoder: Encoder) throws {

            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(connectionID, forKey: .connectionID)
            try c.encode(ownerID, forKey: .ownerID)
            try c.encode(setupID.recordName, forKey: .recordName)
            try c.encode(setupID.zoneID.zoneName, forKey: .zoneName)
            try c.encode(setupID.zoneID.ownerName, forKey: .zoneOwnerName)
            try c.encodeIfPresent(invitation, forKey: .invitation)
        }

    }

    /// Scope choices and recipient binding for a private setup invitation.
    private struct InvitationDraft: Codable {

        /// Display label retained for invitations created before native recipient selection.
        var name: String? = nil

        /// Scopes selected by the inviter.
        var scopes: Set<SharingScope>

        /// Recipient identifier verified from the owner's saved private share.
        var participantID: String? = nil

        /// Proposal ID used after the participant accepts the setup share.
        var proposalID: UUID

        /// Mutation ID used to store the initial consent proposal.
        var mutationID: UUID

        /// Time the inviter created this draft.
        var createdAt: Date

        /// Time after which the inviter can no longer bind this draft.
        var expiresAt: Date

        /// Builds the recipient-facing pending invitation value.
        func presentation(id: UUID, url: URL) -> SharingPendingInvitation {
            SharingPendingInvitation(
                id: id,
                stage: .awaitingRecipient(
                    name: name ?? String(localized: "Invitation"),
                    scopes: scopes,
                    expiresAt: expiresAt,
                    url: url
                )
            )
        }

    }

    /// CloudKit record paired with the decoded owner-controlled document.
    private struct VerifiedControl {

        /// Account that owns this control record.
        var ownerID: String

        /// CloudKit record used for writes or share verification.
        var record: CKRecord

        /// Decoded consent events and provisioning receipts.
        var document: SharingControlDocument

    }

    /// CloudKit record type names used by this transport.
    private enum RecordType {

        /// Record type for invitation discovery roots.
        static let setup = "CountSharingSetup"

        /// Record type for owner-controlled consent records.
        static let control = "CountSharingControl"

        /// Record type for scope roots that hold calorie cards.
        static let scope = "CountSharingScope"

        /// Record type for shared calorie card payloads.
        static let card = "CountSharingCard"

        /// Record type for the current device's publisher lease.
        static let publisher = "CountSharingPublisher"

        /// Record type for this account's private invitation directory.
        static let directory = "CountSharingDirectory"

    }

}

@MainActor
/// One invitation whose metadata is created once, on demand, for native delivery.
final class SharingCloudInvitation: Identifiable {

    /// Stable connection identifier for this invitation.
    let id: UUID

    /// Saved metadata share, or nil before the system requests preparation.
    private(set) var share: CKShare?

    /// CloudKit container that owns the share.
    let container: CKContainer

    private let preparation: (() async throws -> CKShare)?
    private var preparationTask: Task<CKShare, Error>?

    init(id: UUID, share: CKShare, container: CKContainer) {
        self.id = id
        self.share = share
        self.container = container
        preparation = nil
    }

    init(id: UUID, container: CKContainer, preparation: @escaping () async throws -> CKShare) {
        self.id = id
        self.container = container
        self.preparation = preparation
    }

    /// Coalesces preparation callbacks and permits retry after a failed save.
    func prepareShare() async throws -> CKShare {

        if let share { return share }
        if let preparationTask { return try await preparationTask.value }
        guard let preparation else { throw SharingError.invalidConnection }
        let task = Task { try await preparation() }
        preparationTask = task
        defer { preparationTask = nil }
        let share = try await task.value
        self.share = share
        return share
    }

    /// Checks one private recipient before the owner applies the fixed setup permission.
    static func recipient(
        in participants: [CKShare.Participant],
        publicPermission: CKShare.ParticipantPermission,
        expectedID: String?
    ) throws -> CKShare.Participant? {

        guard publicPermission == .none else { throw SharingError.invalidConnection }
        let peers = participants.filter { $0.role != .owner }
        guard peers.count <= 1 else { throw SharingError.multipleRecipients }
        guard let peer = peers.first else { return nil }
        guard peer.role == .privateUser, [.readOnly, .readWrite].contains(peer.permission)
            else { throw SharingError.wrongAccount }
        if let expectedID {
            guard peer.participantID == expectedID else { throw SharingError.wrongAccount }
        }
        return peer
    }

}
