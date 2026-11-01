import Foundation
import SQLiteData

@Table("sharingAccounts")
/// Row that stores one account's local sharing state.
struct StoredSharingAccount: Identifiable, Equatable, Sendable {
    /// Apple Account record name used as the row key.
    let id: String

    /// Encoded local sharing state for this account.
    var payload: String
}

@MainActor
/// A separate database. No HealthKit samples, day choices, or app settings enter it.
final class SharingStore {

    /// Database writer for sharing state and request alert claims.
    private let database: any DatabaseWriter

    /// Opens the database at the given path, or a temporary database, then runs its migrations.
    init(path: String? = nil) throws {

        let database = try path.map { try DatabaseQueue(path: $0) } ?? DatabaseQueue()
        var migrator = DatabaseMigrator()
        migrator.registerMigration("Create account-scoped sharing state") { db in
            try db.execute(
                sql: """
                CREATE TABLE sharingAccounts (
                    id TEXT PRIMARY KEY NOT NULL,
                    payload TEXT NOT NULL
                ) STRICT
                """
            )
        }
        migrator.registerMigration("Remember sharing request alerts") { db in
            try db.execute(
                sql: """
                CREATE TABLE sharingRequestAlerts (
                    accountID TEXT NOT NULL,
                    proposalID TEXT NOT NULL,
                    expiresAt REAL NOT NULL,
                    PRIMARY KEY (accountID, proposalID)
                ) STRICT
                """
            )
        }
        try migrator.migrate(database)
        self.database = database
    }

    /// Claims a valid incoming proposal before the runtime schedules its notification.
    /// A failed delivery is not retried automatically, and account changes retain claims until expiry.
    func claimRequestAlert(_ proposal: SharingProposal, verifiedAccountID: String, now: Date) throws -> Bool {

        try database.write { db in
            try db.execute(
                sql: "DELETE FROM sharingRequestAlerts WHERE expiresAt <= ?",
                arguments: [now.timeIntervalSince1970]
            )
            guard !verifiedAccountID.isEmpty, proposal.recipientID == verifiedAccountID,
                  proposal.createdAt <= now, proposal.expiresAt > now,
                  proposal.expiresAt <= proposal.createdAt.addingTimeInterval(7 * 24 * 60 * 60) else { return false }
            try db.execute(
                sql: """
                INSERT OR IGNORE INTO sharingRequestAlerts (accountID, proposalID, expiresAt)
                VALUES (?, ?, ?)
                """,
                arguments: [
                    verifiedAccountID,
                    proposal.id.uuidString,
                    proposal.expiresAt.timeIntervalSince1970
                ]
            )
            return db.changesCount == 1
        }
    }

    /// Removes request alert claims whose proposals have expired.
    func expireRequestAlerts(now: Date) throws {

        try database.write { db in
            try db.execute(
                sql: "DELETE FROM sharingRequestAlerts WHERE expiresAt <= ?",
                arguments: [now.timeIntervalSince1970]
            )
        }
    }

    /// Loads one account's local state, or an empty state if no row exists.
    func load(accountID: String) throws -> SharingLocalState {

        let record = try database.read { db in
            try StoredSharingAccount.where { $0.id.eq(accountID) }.fetchOne(db)
        }
        guard let record else { return SharingLocalState() }
        return try JSONDecoder().decode(SharingLocalState.self, from: Data(record.payload.utf8))
    }

    /// Stores the encoded local state for one account.
    func save(_ state: SharingLocalState, accountID: String) throws {

        let payload = String(decoding: try JSONEncoder().encode(state), as: UTF8.self)
        try database.write { db in
            try StoredSharingAccount.upsert { StoredSharingAccount(id: accountID, payload: payload) }.execute(db)
        }
    }

    /// Keeps only pending access-removal work for other accounts during startup.
    func clearOtherAccounts(keeping accountID: String?) throws {

        try database.write { db in
            for record in try StoredSharingAccount.fetchAll(db) where record.id != accountID {
                guard let state = try? JSONDecoder().decode(SharingLocalState.self, from: Data(record.payload.utf8)),
                      let restrictive = Self.restrictiveState(state, accountID: record.id) else {
                    try StoredSharingAccount.where { $0.id.eq(record.id) }.delete().execute(db)
                    continue
                }
                let payload = String(decoding: try JSONEncoder().encode(restrictive), as: UTF8.self)
                try StoredSharingAccount.upsert { StoredSharingAccount(id: record.id, payload: payload) }.execute(db)
            }
        }
    }

    /// Deletes one account's stored sharing state.
    func clear(accountID: String) throws {

        try database.write { db in
            try StoredSharingAccount.where { $0.id.eq(accountID) }.delete().execute(db)
        }
    }

}

extension SharingStore {

    /// Retains account-bound access-removal work without cards or publisher authority.
    nonisolated private static func restrictiveState(_ state: SharingLocalState, accountID: String) -> SharingLocalState? {

        let mutations = state.pendingMutations.filter { mutation in
            guard mutation.actorID == accountID else { return false }
            switch mutation.action { case .reduce, .remove: return true; default: return false }
        }
        let revocations = state.pendingRevocations.filter { $0.accountID == accountID }
        guard !mutations.isEmpty || !revocations.isEmpty else { return nil }
        let connectionIDs = Set(mutations.map { $0.connection.id }).union(revocations.map(\.connectionID))
        var restrictive = SharingLocalState()
        restrictive.pendingRevocations = revocations
        restrictive.confirmedRevocations = state.confirmedRevocations.filter {
            $0.accountID == accountID && connectionIDs.contains($0.connectionID)
        }
        restrictive.pendingMutations = mutations.map { mutation in
            var mutation = mutation
            mutation.connection = restrictionMetadata(mutation.connection)
            return mutation
        }
        for id in connectionIDs {
            if let connection = state.connections.first(where: { $0.id == id })
                ?? mutations.first(where: { $0.connection.id == id })?.connection {
                restrictive.connections.append(restrictionMetadata(connection))
            }
        }
        return restrictive
    }

    /// Removes private names and active authority while retaining grant IDs for retries.
    nonisolated private static func restrictionMetadata(_ connection: SharingConnection) -> SharingConnection {

        var connection = connection
        connection.inviter.displayName = ""
        connection.invitee.displayName = ""
        connection.proposal = nil
        connection.publisherGenerations = [:]
        // scope and generation IDs let a later Pause revoke the rest of the hierarchy
        // before an earlier reduction is confirmed; readiness does not survive
        connection.grants = connection.grants.map { SharingGrant(scope: $0.scope, generation: $0.generation) }
        return connection
    }

}

extension SharingStore {

    /// Creates the protected sharing database in Application Support.
    static func persistent() throws -> SharingStore {

        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("Count/Sharing", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )
        let file = directory.appendingPathComponent("sharing.sqlite")
        let store = try SharingStore(path: file.path)
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: file.path
        )
        return store
    }

}
