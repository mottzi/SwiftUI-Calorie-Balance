#if DEBUG
import Foundation

/// Explicit simulator-only presentations. Never sent to the phone or stored with real sharing data.
enum WatchSharingFixtures {
    static var isActive: Bool {
        #if targetEnvironment(simulator)
        ProcessInfo.processInfo.arguments.contains("--watch-sharing-qa")
        #else
        false
        #endif
    }

    @MainActor
    static func makeStore() -> WatchSharingStore {
        let defaults = UserDefaults(suiteName: "watch.sharing.qa")!
        defaults.removePersistentDomain(forName: "watch.sharing.qa")
        let store = WatchSharingStore(defaults: defaults)
        let now = Date.now.addingTimeInterval(-300)
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        func color(_ r: Double, _ g: Double, _ b: Double) -> CalorieCardSnapshot.AdaptiveColor {
            let rgba = CalorieCardSnapshot.RGBA(red: r, green: g, blue: b)
            return .init(light: rgba, dark: rgba)
        }
        let blue = color(0.42, 0.69, 1)
        let orange = color(1, 0.5, 0.23)
        let purple = color(0.72, 0.54, 1)
        var card = CalorieCardSnapshot(
            senderLocalDate: CalorieCardSnapshot.localDate(for: start, calendar: calendar),
            timeZoneIdentifier: calendar.timeZone.identifier, dayStart: start, dayEnd: end, capturedAt: now,
            now: .init(energy: .init(active: 700, resting: 1610, consumed: 2120), visibleGoalReached: false),
            midnight: .init(energy: .init(active: 700, resting: 1610, restingRemaining: 410, consumed: 2120), visibleGoalReached: true),
            energyUnit: .kcal,
            appearance: .init(burned: purple, consumed: color(0.3, 0.85, 0.46),
                              cardBackground: color(0.1, 0.1, 0.1), graphEmpty: color(0.25, 0.25, 0.25), nameColor: purple)
        )
        let history = (1...6).map { offset -> CalorieCardSnapshot in
            let day = calendar.date(byAdding: .day, value: -offset, to: start)!
            return .init(senderLocalDate: CalorieCardSnapshot.localDate(for: day, calendar: calendar),
                         timeZoneIdentifier: calendar.timeZone.identifier, dayStart: day,
                         dayEnd: calendar.date(byAdding: .day, value: 1, to: day)!, capturedAt: now,
                         now: .init(energy: .init(active: 500, resting: 1800, consumed: 1740 + offset * 40), visibleGoalReached: true),
                         midnight: nil, energyUnit: .kcal, appearance: card.appearance)
        }
        var people: [WatchSharingSnapshot.Person] = [
            .init(id: UUID(), name: "Ommtzi", revision: 3, scopes: [.today, .history, .goals], isReady: true,
                  nameColor: purple, today: card, history: history, streak: .init(days: 8, color: purple),
                  streakExpiresAt: end, senderTimeZone: calendar.timeZone.identifier, lastSharedAt: now)
        ]
        card.appearance.nameColor = orange
        card.appearance = .init(burned: blue, consumed: orange, cardBackground: card.appearance.cardBackground,
                                graphEmpty: card.appearance.graphEmpty, nameColor: orange)
        card.now = .init(energy: .init(active: 500, resting: 1600, consumed: 2474), visibleGoalReached: true)
        let jonas = WatchSharingSnapshot.Person(id: UUID(), name: "Jonas", revision: 3, scopes: [.today, .goals], isReady: true,
                     nameColor: orange, today: card, history: [], streak: .init(days: 22, color: orange),
                     streakExpiresAt: end, senderTimeZone: calendar.timeZone.identifier, lastSharedAt: now)
        people.append(jonas)
        people.append(.init(id: UUID(), name: "Berken", revision: 3, scopes: [.today, .history], isReady: true,
                            nameColor: blue, today: nil, history: history.map { $0.withoutGoalInformation() },
                            streak: nil, streakExpiresAt: nil, senderTimeZone: calendar.timeZone.identifier,
                            lastSharedAt: now.addingTimeInterval(-4 * 86400)))
        people.append(.init(id: UUID(), name: "Maya", revision: 4, scopes: [], isReady: true,
                            nameColor: purple, today: nil, history: [], streak: nil, streakExpiresAt: nil,
                            senderTimeZone: nil, lastSharedAt: nil))
        let args = ProcessInfo.processInfo.arguments
        store.receive(.init(accountID: "watch-qa", people: args.contains("--watch-sharing-empty") ? [] : people,
                            hidesGoalStatus: args.contains("--watch-sharing-hide-goals")))
        return store
    }
}
#endif
