#if DEBUG
import HealthKit

@MainActor
/// Local people for manual testing. Every store and transport is in memory.
final class SharingSamplePeople {
    let coordinator: SharingCoordinator
    private let peers: [SharingCoordinator]
    private var nextPersonIndex = 0

    private struct Persona {
        let name: String
        let profile: SampleHealthProfile
        let themeNumber: Int
        let background: Settings.AppBackgrounds
        let goal: Int
        let isLoss: Bool
    }

    private static let personas: [Persona] = [
        .init(name: "Lea", profile: .maintenance, themeNumber: 3, background: .dark, goal: 0, isLoss: false),
        .init(name: "Jonas", profile: .lowActivity, themeNumber: 1, background: .black, goal: 100, isLoss: false),
        .init(name: "Maya", profile: .active, themeNumber: 8, background: .light, goal: 300, isLoss: true),
        .init(name: "Noah", profile: .irregularLogging, themeNumber: 5, background: .dark, goal: 300, isLoss: true)
    ]
    private static let identity = SharingIdentity(id: "debug-sharing-me", displayName: "Me")

    var people: [SharingPerson] {
        coordinator.connections.map {
            SharingPerson(connection: $0, coordinator: coordinator, isSample: true)
        }.sorted { first, second in
            (Self.personas.firstIndex(where: { $0.name == first.name }) ?? Self.personas.count)
                < (Self.personas.firstIndex(where: { $0.name == second.name }) ?? Self.personas.count)
        }
    }

    init() throws {
        let server = SharingFakeServer()
        coordinator = SharingCoordinator(store: try SharingStore(), transport: server.transport(for: Self.identity))
        peers = try Self.personas.map { persona in
            SharingCoordinator(
                store: try SharingStore(),
                transport: server.transport(for: SharingIdentity(id: "debug-sharing-person-\(persona.profile.rawValue)", displayName: persona.name))
            )
        }
    }

    /// Keeps four sample people alongside live connections and simulates peer responses.
    func refresh(now: Date = .now) async throws {
        await coordinator.refresh()
        while coordinator.connections.count < Self.personas.count {
            let index = nextPersonIndex % peers.count
            nextPersonIndex += 1
            let peer = peers[index]
            await peer.refresh()
            guard let identity = peer.identity,
                  !coordinator.connections.contains(where: { $0.peer(of: Self.identity.id)?.id == identity.id })
            else { continue }
            _ = try await coordinator.propose(to: identity, scopes: [.today, .history, .streaks])
        }
        for (index, peer) in peers.enumerated() {
            await peer.refresh()
            for connection in peer.connections {
                if let proposal = connection.proposal, proposal.recipientID == peer.identity?.id {
                    try await peer.accept(connectionID: connection.id, proposalID: proposal.id)
                }
            }
            await coordinator.refresh()
            await peer.refresh()
            guard !peer.connections.isEmpty else { continue }
            if !peer.isPublisher { try await peer.takeOverPublisher() }
            try await peer.publish(snapshots: Self.snapshots(profile: Self.personas[index].profile, now: now))
        }
        await coordinator.refresh()
    }

    /// Uses the same repeatable daily measurements as the Debug sample profiles.
    static func snapshots(profile: SampleHealthProfile, now: Date, calendar: Calendar = .current) -> [CalorieCardSnapshot] {
        let profileIndex = SampleHealthProfile.allCases.firstIndex(of: profile) ?? 0
        guard let persona = personas.first(where: { $0.profile == profile }) else { return [] }
        let theme = Settings.Themes[persona.themeNumber - 1]
        let base = CalorieCardSnapshotBuilder.appearance(settings: .shared, background: persona.background)
        let appearance = CalorieCardSnapshot.Appearance(
            burned: CalorieCardSnapshotBuilder.adaptive(theme.burned),
            consumed: CalorieCardSnapshotBuilder.adaptive(theme.consumed),
            cardBackground: base.cardBackground, graphEmpty: base.graphEmpty,
            labelBackground: base.labelBackground, pageBackground: base.pageBackground
        )
        let completed = (1..<SampleHealthDay.historyDays).compactMap { daysAgo -> SampleHealthDay? in
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: now) else { return nil }
            return SampleHealthDay(date: date, now: now, calendar: calendar, profile: profile)
        }
        let count = completed.prefix {
            let values = energy($0)
            return values.consumed > 0 && values.meetsGoal(persona.goal, isLoss: persona.isLoss)
        }.count
        let summary = CalorieCardSnapshot.StreakSummary(
            days: count, color: persona.isLoss ? appearance.burned : appearance.consumed
        )
        return (0...SharingDateWindow.historyDayCount).compactMap { daysAgo in
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: now),
                  let day = SampleHealthDay(date: date, now: now, calendar: calendar, profile: profile),
                  let end = calendar.date(byAdding: .day, value: 1, to: day.date),
                  let complete = SampleHealthDay(date: date, now: max(now, end), calendar: calendar, profile: profile)
            else { return nil }
            let current = energy(day)
            let projected = energy(day, remaining: max(0, energy(complete).resting - current.resting))
            let ordinal = calendar.ordinality(of: .day, in: .era, for: day.date) ?? 0
            var snapshot = CalorieCardSnapshot(
                id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", ordinal * 4 + profileIndex))!,
                senderLocalDate: CalorieCardSnapshot.localDate(for: day.date, calendar: calendar),
                timeZoneIdentifier: calendar.timeZone.identifier,
                dayStart: day.date, dayEnd: end, capturedAt: now,
                now: .init(energy: current, visibleGoalReached: current.meetsGoal(persona.goal, isLoss: persona.isLoss)),
                midnight: daysAgo == 0 ? .init(energy: projected, visibleGoalReached: projected.meetsGoal(persona.goal, isLoss: persona.isLoss)) : nil,
                energyUnit: .kcal, appearance: appearance
            )
            if daysAgo == 0 { snapshot.streak = summary }
            return snapshot
        }
    }

    private static func energy(_ sample: SampleHealthDay, remaining: Int = 0) -> EnergyBalance {
        func kcal(_ type: HKQuantityTypeIdentifier) -> Int {
            Int((sample.quantity(type)?.doubleValue(for: .kilocalorie()) ?? 0).rounded())
        }
        return EnergyBalance(active: kcal(.activeEnergyBurned), resting: kcal(.basalEnergyBurned),
                             restingRemaining: remaining, consumed: kcal(.dietaryEnergyConsumed))
    }
}
#endif
