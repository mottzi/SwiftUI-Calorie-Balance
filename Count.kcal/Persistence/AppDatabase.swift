import Foundation
import Dependencies
import SQLiteData

@Table("dayChoices")
/// Explicit choices only; automatic handling has no stored record.
struct StoredDayChoice: Identifiable, Equatable, Sendable {
    let id: String
    var choice: String
}

/// Local SQLite storage, shared with future iPhone extensions through the App Group.
enum AppDatabase {

    static func open() throws -> any DatabaseWriter {

        @Dependency(\.context) var context
        if context != .live { return try makeDatabase(path: nil) }
        let directory = try storageDirectory()
        let file = directory.appending(path: "count.sqlite")
        let database = try makeDatabase(path: file.path)
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: file.path
        )
        return database
    }

    static func makeDatabase(path: String?) throws -> any DatabaseWriter {

        let database = try path.map { try DatabaseQueue(path: $0) } ?? DatabaseQueue()
        var migrator = DatabaseMigrator()
        migrator.registerMigration("Create day choices") { db in
            try db.execute(sql: """
                CREATE TABLE dayChoices (
                    id TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE,
                    choice TEXT NOT NULL CHECK (choice IN ('excluded', 'fasting'))
                ) STRICT
                """)
        }
        try migrator.migrate(database)
        return database
    }

    static func setChoice(_ choice: DayChoice, for date: Date, sampleData: Bool) throws {

        @Dependency(\.defaultDatabase) var database
        let id = recordID(for: date, sampleData: sampleData)
        try database.write { db in
            if choice == .automatic {
                try StoredDayChoice.where { $0.id.eq(id) }.delete().execute(db)
            } else {
                try StoredDayChoice.upsert { StoredDayChoice(id: id, choice: choice.rawValue) }.execute(db)
            }
        }
    }

    static func recordID(for date: Date, sampleData: Bool) -> String {
        (sampleData ? "sample:" : "") + DayKey.make(date)
    }

    static func choices(_ records: [StoredDayChoice], sampleData: Bool) -> [String: DayChoice] {
        Dictionary(uniqueKeysWithValues: records.compactMap { record in
            let isSample = record.id.hasPrefix("sample:")
            guard isSample == sampleData, let choice = DayChoice(rawValue: record.choice) else { return nil }
            return (isSample ? String(record.id.dropFirst(7)) : record.id, choice)
        })
    }

    private static func storageDirectory() throws -> URL {

        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.4DXABR577J.com.count.kcal.app"
        ) else { throw CocoaError(.fileNoSuchFile) }
        let directory = container.appending(path: "Library/Application Support/Count", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )
        return directory
    }

}
