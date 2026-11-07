import Foundation

/// A companion-device projection of already permitted data. The iPhone owns consent.
struct WatchSharingSnapshot: Codable, Equatable, Sendable {
    var accountID: String?
    var people: [Person] = []
    var hidesGoalStatus = false

    struct Person: Codable, Equatable, Sendable, Identifiable {
        let id: UUID
        var name: String
        var revision: Int
        var scopes: Set<SharingScope>
        var isReady: Bool
        var nameColor: CalorieCardSnapshot.AdaptiveColor?
        var today: CalorieCardSnapshot?
        var history: [CalorieCardSnapshot]
        var streak: CalorieCardSnapshot.StreakSummary?
        var streakExpiresAt: Date?
        var senderTimeZone: String?
        var lastSharedAt: Date?
        var isRemovingAccess = false

        var canPause: Bool { !scopes.isEmpty }

        /// A disconnected watch must expire dates without waiting for another phone update.
        func current(at date: Date) -> Self {
            var result = self
            let zone = senderTimeZone.flatMap(TimeZone.init(identifier:))
            if !scopes.contains(.today) || today.map({
                !SharingDateWindow.permits($0, scope: .today, now: date, latestSenderTimeZone: zone)
            }) == true { result.today = nil }
            result.history = scopes.contains(.history) ? history.filter {
                SharingDateWindow.permits($0, scope: .history, now: date, latestSenderTimeZone: zone)
            } : []
            if !scopes.contains(.goals) {
                result.today = result.today?.withoutGoalInformation()
                result.history = result.history.map { $0.withoutGoalInformation() }
            }
            if !scopes.contains(.goals) || streakExpiresAt.map({ date >= $0 }) != false {
                result.streak = nil
            }
            return result
        }

        var summary: CalorieCardSnapshot? {
            scopes.contains(.today) ? today : history.first
        }
    }
}

/// The revision prevents an old, delayed pause from undoing a later consent decision.
struct WatchSharingPauseRequest: Codable, Equatable, Sendable, Identifiable {
    var id = UUID()
    let accountID: String
    let connectionID: UUID
    let revision: Int
}

struct WatchSharingPauseReply: Codable, Equatable, Sendable {
    let requestID: UUID
    let result: Result

    enum Result: String, Codable, Sendable {
        case saved
        case changed
        case failed
    }
}
