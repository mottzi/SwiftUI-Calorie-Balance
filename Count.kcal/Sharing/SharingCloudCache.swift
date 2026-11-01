import CloudKit
import Foundation

@MainActor
/// Raw records and their download checkpoint share one atomic, account-scoped file.
/// This cache is never a source of consent or publisher authority by itself.
final class SharingCloudCache {
    private struct Archive: Codable {
        var accountID: String
        var records: [Data]
        var checkpoint: Data?
    }

    let file: URL
    let accountID: String
    private(set) var records: [CKRecord.ID: CKRecord] = [:]
    private(set) var checkpoint: Data?

    init(file: URL, accountID: String) throws {
        self.file = file
        self.accountID = accountID
        guard FileManager.default.fileExists(atPath: file.path) else { return }
        let archive = try JSONDecoder().decode(Archive.self, from: Data(contentsOf: file))
        guard archive.accountID == accountID else { throw SharingError.wrongAccount }
        var decoded: [CKRecord.ID: CKRecord] = [:]
        for data in archive.records {
            guard let record = try NSKeyedUnarchiver.unarchivedObject(ofClass: CKRecord.self, from: data)
                else { throw SharingError.unavailable }
            decoded[record.recordID] = record
        }
        records = decoded
        checkpoint = archive.checkpoint
    }

    func apply(saving: [CKRecord] = [], deleting: [CKRecord.ID] = [], deletedZones: [CKRecordZone.ID] = []) {
        for zone in deletedZones { records = records.filter { $0.key.zoneID != zone } }
        for id in deleting { records[id] = nil }
        for record in saving { records[record.recordID] = record }
    }

    /// A failed write never advances the durable checkpoint past its durable records.
    func persist(checkpoint proposedState: Data?) throws {
        let archive = Archive(
            accountID: accountID,
            records: try records.values.map { try NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: true) },
            checkpoint: proposedState
        )
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(archive).write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        checkpoint = proposedState
    }

    func clear() throws {
        records = [:]
        checkpoint = nil
        if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
    }
}
