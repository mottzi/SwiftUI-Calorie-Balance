import CloudKit
import CryptoKit
import Foundation
import OSLog

@MainActor
/// One incremental incoming reader per database, including explicit missed-push recovery.
final class SharingCloudReader {
    private struct ZoneCheckpoint: Codable {
        var name: String
        var owner: String
        var token: Data
        var id: CKRecordZone.ID { CKRecordZone.ID(zoneName: name, ownerName: owner) }
    }
    private struct Checkpoint: Codable {
        var databaseToken: Data?
        var zones: [ZoneCheckpoint] = []
    }

    private let cache: SharingCloudCache
    private let database: CKDatabase
    private let subscriptionID: String
    private var checkpoint: Checkpoint
    private var fetchTask: Task<Void, Error>?
    private var subscribed = false
    private(set) var isActive = true
    private(set) var hasFetched = false
    private(set) var fetchCount = 0
    private(set) var receivedCount = 0
    var prioritizedZoneIDs: [CKRecordZone.ID] = []
    private let logger = Logger(subsystem: "com.count.kcal.app", category: "SharingSync")

    init(database: CKDatabase, accountID: String, subscriptionID: String, directory: URL) throws {
        self.database = database
        self.subscriptionID = subscriptionID
        let accountKey = SHA256.hash(data: Data(accountID.utf8)).map { String(format: "%02x", $0) }.joined()
        let file = directory.appendingPathComponent("\(accountKey)-\(database.databaseScope.rawValue).json")
        cache = try SharingCloudCache(file: file, accountID: accountID)
        checkpoint = try cache.checkpoint.map { try JSONDecoder().decode(Checkpoint.self, from: $0) } ?? Checkpoint()
    }

    var records: [CKRecord] { isActive ? Array(cache.records.values) : [] }

    func fetch() async throws {
        guard isActive else { throw SharingError.wrongAccount }
        if let fetchTask { return try await fetchTask.value }
        let task = Task { @MainActor in
            defer { self.fetchTask = nil }
            try await self.ensureSubscription()
            self.fetchCount += 1
            self.logger.info("fetch begin scope=\(self.database.databaseScope.rawValue) count=\(self.fetchCount)")
            do { try await self.fetchDelta() }
            catch let error as CKError where error.code == .changeTokenExpired {
                self.checkpoint = Checkpoint()
                try await self.fetchDelta()
            }
            self.hasFetched = true
            self.logger.info("fetch complete scope=\(self.database.databaseScope.rawValue) receivedTotal=\(self.receivedCount)")
        }
        fetchTask = task
        try await task.value
    }

    func records(in zone: CKRecordZone.ID) throws -> [CKRecord] {
        guard isActive else { throw SharingError.wrongAccount }
        return records.filter { $0.recordID.zoneID == zone }
    }

    /// Direct writes reconcile the same raw cache without advancing download tokens.
    func apply(saving: [CKRecord] = [], deleting: [CKRecord.ID] = []) throws {
        guard isActive else { throw SharingError.wrongAccount }
        cache.apply(saving: saving, deleting: deleting)
        try cache.persist(checkpoint: cache.checkpoint)
    }

    func invalidate() {
        isActive = false
        fetchTask?.cancel()
        try? cache.clear()
    }

    private func ensureSubscription() async throws {
        guard !subscribed else { return }
        do { _ = try await database.subscription(for: subscriptionID) }
        catch let error as CKError where error.code == .unknownItem {
            let subscription = CKDatabaseSubscription(subscriptionID: subscriptionID)
            let info = CKSubscription.NotificationInfo()
            info.shouldSendContentAvailable = true
            subscription.notificationInfo = info
            _ = try await database.save(subscription)
        }
        subscribed = true
    }

    private func fetchDelta() async throws {
        var next = checkpoint
        var token = try next.databaseToken.map(Self.decodeToken)
        var changed = Set<CKRecordZone.ID>()
        if token == nil { cache.apply(deletedZones: Array(Set(cache.records.keys.map(\.zoneID)))) }
        repeat {
            let page = try await database.databaseChanges(since: token)
            try checkActive()
            changed.formUnion(page.modifications.map(\.zoneID))
            let deleted = Set(page.deletions.map(\.zoneID))
            changed.subtract(deleted)
            cache.apply(deletedZones: Array(deleted))
            next.zones.removeAll { deleted.contains($0.id) }
            token = page.changeToken
            if !page.moreComing { break }
        } while true
        let ordered = changed.sorted { left, right in
            let a = prioritizedZoneIDs.firstIndex(of: left) ?? Int.max
            let b = prioritizedZoneIDs.firstIndex(of: right) ?? Int.max
            return a == b ? left.zoneName + left.ownerName < right.zoneName + right.ownerName : a < b
        }
        for zone in ordered {
            var zoneToken = try next.zones.first(where: { $0.id == zone }).map { try Self.decodeToken($0.token) }
            var reset = false
            do {
                repeat {
                    do {
                        let page = try await database.recordZoneChanges(inZoneWith: zone, since: zoneToken)
                        try checkActive()
                        let records = try page.modificationResultsByID.values.map { try $0.get().record }
                        cache.apply(saving: records, deleting: page.deletions.map(\.recordID))
                        receivedCount += records.count
                        zoneToken = page.changeToken
                        if !page.moreComing { break }
                    } catch let error as CKError where error.code == .changeTokenExpired && !reset {
                        reset = true
                        zoneToken = nil
                        cache.apply(deletedZones: [zone])
                    }
                } while true
                next.zones.removeAll { $0.id == zone }
                if let zoneToken {
                    next.zones.append(ZoneCheckpoint(name: zone.zoneName, owner: zone.ownerName,
                                                     token: try Self.encodeToken(zoneToken)))
                }
            } catch let error as CKError where [.zoneNotFound, .userDeletedZone].contains(error.code) {
                cache.apply(deletedZones: [zone])
                next.zones.removeAll { $0.id == zone }
            }
        }
        try checkActive()
        next.databaseToken = try token.map(Self.encodeToken)
        // No database checkpoint advances until every changed zone is durably applied.
        try cache.persist(checkpoint: JSONEncoder().encode(next))
        checkpoint = next
    }

    private func checkActive() throws {
        try Task.checkCancellation()
        guard isActive else { throw SharingError.wrongAccount }
    }

    private static func encodeToken(_ token: CKServerChangeToken) throws -> Data {
        try NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
    }

    private static func decodeToken(_ data: Data) throws -> CKServerChangeToken {
        guard let token = try NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
        else { throw SharingError.unavailable }
        return token
    }
}
