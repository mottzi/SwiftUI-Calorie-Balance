import Foundation
import Testing
@testable import Count_kcal

@Suite(.serialized)
@MainActor
struct WatchSharingTests {
    @Test
    func watchContextRoundTripsWithoutChangingSettings() throws {
        let sharing = WatchSharingSnapshot(accountID: "alice", people: [person()], hidesGoalStatus: true)
        let data = try PropertyListEncoder().encode(sharing)
        var settings = WatchSettingsSnapshot(weightGoal: nil, dataSource: nil, energyUnit: "kJ", weightUnit: "kg",
                                            balanceGoal: nil, customCalPassive: nil, customCalActive: nil,
                                            proteinGoal: nil, carbsGoal: nil, fatsGoal: nil,
                                            burnedColor: nil, consumedColor: nil)
        settings.sharing = data
        let context = try #require(settings.context)
        let received = try #require(WatchSettingsSnapshot(context: context))
        #expect(received.energyUnit == "kJ")
        let receivedData = try #require(received.sharing)
        #expect(try PropertyListDecoder().decode(WatchSharingSnapshot.self, from: receivedData) == sharing)
    }

    @Test
    func disconnectedWatchExpiresTodayAndStreakAtSenderMidnight() {
        var person = person()
        let card = person.today!
        person.streak = .init(days: 9, color: card.appearance.burned)
        person.streakExpiresAt = card.dayEnd
        let before = person.current(at: card.dayEnd.addingTimeInterval(-1))
        let after = person.current(at: card.dayEnd)
        #expect(before.today != nil)
        #expect(before.streak?.days == 9)
        #expect(after.today == nil)
        #expect(after.streak == nil)
        // Today-only permission must never turn an expired card into shared history.
        #expect(after.history.isEmpty)
    }

    @Test
    func latestSenderTimeZoneControlsTodayExpiry() {
        var person = person()
        person.senderTimeZone = "Asia/Tokyo"
        #expect(person.current(at: now).today != nil)
        #expect(person.current(at: now.addingTimeInterval(4 * 3600)).today == nil)
    }

    @Test
    func noGoalsPermissionRemovesGoalResultsAndStreak() {
        var person = person()
        person.scopes = [.today]
        person.streak = .init(days: 10, color: person.today!.appearance.burned)
        person.streakExpiresAt = person.today!.dayEnd
        let visible = person.current(at: now)
        #expect(visible.today?.now.visibleGoalReached == nil)
        #expect(visible.today?.midnight?.visibleGoalReached == nil)
        #expect(visible.streak == nil)
        #expect(visible.nameColor == person.nameColor)
    }

    @Test
    func expiredHistoryDoesNotRemainOnOfflineWatch() {
        var person = person()
        person.scopes = [.history]
        person.today = nil
        var card = SharingFixtures.snapshot(day: now.addingTimeInterval(-6 * 86400), capturedAt: now)
        card.midnight = nil
        person.history = [card]
        #expect(person.current(at: now).history.count == 1)
        #expect(person.current(at: now.addingTimeInterval(86400)).history.isEmpty)
    }

    @Test
    func pauseOutboxSurvivesRelaunchAndDeduplicatesTaps() throws {
        let defaults = defaults()
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        let store = WatchSharingStore(defaults: defaults)
        let person = person()
        store.receive(.init(accountID: "alice", people: [person]))
        let first = try #require(store.requestPause(for: person))
        #expect(store.requestPause(for: person)?.id == first.id)
        let restored = WatchSharingStore(defaults: defaults)
        #expect(restored.pendingPauses == [first])
        #expect(restored.snapshot == store.snapshot)
    }

    @Test
    func pauseOnlyCompletesWhenPhoneContextConfirmsIt() throws {
        let defaults = defaults()
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        let store = WatchSharingStore(defaults: defaults)
        var person = person()
        store.receive(.init(accountID: "alice", people: [person]))
        let request = try #require(store.requestPause(for: person))
        store.receive(WatchSharingPauseReply(requestID: request.id, result: .saved))
        #expect(store.pendingPauses.count == 1)
        person.scopes = []
        person.today = nil
        person.isRemovingAccess = true
        store.receive(.init(accountID: "alice", people: [person]))
        #expect(store.pendingPauses.isEmpty)
        #expect(store.snapshot?.people.first?.isRemovingAccess == true)
    }

    @Test
    func accountChangeClearsOldDataAndRequests() {
        let defaults = defaults()
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        let store = WatchSharingStore(defaults: defaults)
        let person = person()
        store.receive(.init(accountID: "alice", people: [person]))
        store.requestPause(for: person)
        store.receive(.init(accountID: "different-account"))
        #expect(store.snapshot?.people.isEmpty == true)
        #expect(store.pendingPauses.isEmpty)
        #expect(WatchSharingStore(defaults: defaults).snapshot?.people.isEmpty == true)
    }

    @Test
    func newerConsentClearsAnObsoleteQueuedPause() {
        let defaults = defaults()
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        let store = WatchSharingStore(defaults: defaults)
        var person = person()
        store.receive(.init(accountID: "alice", people: [person]))
        store.requestPause(for: person)
        person.revision += 2
        store.receive(.init(accountID: "alice", people: [person]))
        #expect(store.pendingPauses.isEmpty)
        #expect(store.failedPauses.contains(person.id))
    }

    @Test
    func rejectedPauseAllowsRetryWithoutAStuckWaitingState() throws {
        let defaults = defaults()
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        let store = WatchSharingStore(defaults: defaults)
        let person = person()
        store.receive(.init(accountID: "alice", people: [person]))
        let request = try #require(store.requestPause(for: person))
        store.receive(WatchSharingPauseReply(requestID: request.id, result: .changed))
        #expect(store.pendingPauses.isEmpty)
        #expect(store.failedPauses.contains(person.id))
        let next = try #require(store.requestPause(for: person))
        #expect(next.id != request.id)
        #expect(store.failedPauses.isEmpty)
        store.receive(WatchSharingPauseReply(requestID: request.id, result: .failed))
        #expect(store.pendingPauses == [next])
    }

    private let now = ISO8601DateFormatter().date(from: "2026-11-07T12:00:00Z")!
    private let defaultsName = "WatchSharingTests.\(UUID())"
    private func defaults() -> UserDefaults { UserDefaults(suiteName: defaultsName)! }

    private func person() -> WatchSharingSnapshot.Person {
        let snapshot = SharingFixtures.snapshot(day: now, capturedAt: now, timeZone: .gmt, goalReached: true)
        return .init(id: UUID(), name: "Alice", revision: 3, scopes: [.today, .goals], isReady: true,
                     nameColor: snapshot.appearance.burned, today: snapshot, history: [],
                     streak: nil, streakExpiresAt: nil, senderTimeZone: "GMT", lastSharedAt: now)
    }
}
