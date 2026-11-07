import Foundation
import SwiftUI
import WatchConnectivity

extension WatchSharingSnapshot {
    @MainActor
    init?(runtime: SharingRuntime, hidesGoalStatus: Bool) {
        guard let coordinator = runtime.coordinator else { return nil }
        // An unverified cold launch must not replace the watch's last known data with an empty list.
        guard coordinator.identity != nil || coordinator.accountStatus == .signedOut else { return nil }
        accountID = coordinator.identity?.id
        self.hidesGoalStatus = hidesGoalStatus
        people = runtime.people.map { person in
            let connection = person.connection
            let coordinator = person.coordinator
            let metadata = coordinator.senderMetadata(connectionID: person.id)
            let today = coordinator.snapshots(connectionID: person.id, scope: .today).first?.snapshot
            let history = coordinator.snapshots(connectionID: person.id, scope: .history).map(\.snapshot)
            let timeZone = metadata?.timeZoneIdentifier ?? today?.timeZoneIdentifier ?? history.first?.timeZoneIdentifier
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone.flatMap(TimeZone.init(identifier:)) ?? .current
            return Person(
                id: person.id, name: person.name, revision: connection.revision,
                scopes: connection.scopes, isReady: connection.scopes.allSatisfy(connection.isReady),
                nameColor: coordinator.senderNameColor(connectionID: person.id)
                    ?? today?.appearance.resolvedNameColor ?? history.first?.appearance.resolvedNameColor,
                today: today, history: history,
                streak: coordinator.streak(connectionID: person.id),
                streakExpiresAt: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now)),
                senderTimeZone: timeZone, lastSharedAt: metadata?.capturedAt,
                isRemovingAccess: coordinator.pendingRevocations.contains { $0.connectionID == person.id }
            )
        }
    }
}

/// Pauses use the iPhone's existing durable consent queue, including after background delivery.
@MainActor
final class WatchSharingPhone {
    static let shared = WatchSharingPhone()
    private let defaults: UserDefaults
    private var requests: [WatchSharingPauseRequest]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        requests = defaults.data(forKey: "sharing.watchPauses").flatMap {
            try? PropertyListDecoder().decode([WatchSharingPauseRequest].self, from: $0)
        } ?? []
    }

    func receive(_ request: WatchSharingPauseRequest) {
        if !requests.contains(where: { $0.id == request.id }) {
            requests.append(request)
            save()
        }
        Connectivity.shared.sendSettingsContext()
        Task {
            await SharingRuntime.shared.refresh()
            Connectivity.shared.sendSettingsContext()
        }
    }

    func processPending(runtime: SharingRuntime) {
        guard !requests.isEmpty, let coordinator = runtime.coordinator else { return }
        guard case .available = coordinator.accountStatus else {
            if coordinator.accountStatus == .signedOut {
                for request in requests { reply(to: request, result: .changed) }
                requests = []
                save()
            }
            return
        }
        for request in requests {
            let result = Self.apply(request, runtime: runtime)
            reply(to: request, result: result)
        }
        requests = []
        save()
    }

    /// Account and revision checks make duplicate foreground/background delivery harmless.
    static func apply(_ request: WatchSharingPauseRequest, runtime: SharingRuntime) -> WatchSharingPauseReply.Result {
        guard runtime.coordinator?.identity?.id == request.accountID,
              let person = runtime.people.first(where: { $0.id == request.connectionID }) else { return .changed }
        let connection = person.connection
        if connection.scopes.isEmpty { return .saved }
        guard connection.revision == request.revision else { return .changed }
        return runtime.applyPermissionChange(on: person.coordinator) {
            try person.coordinator.enqueueScopeChange(connectionID: connection.id, to: [])
        } ? .saved : .failed
    }

    private func reply(to request: WatchSharingPauseRequest, result: WatchSharingPauseReply.Result) {
        guard WCSession.default.activationState == .activated,
              let data = try? PropertyListEncoder().encode(WatchSharingPauseReply(requestID: request.id, result: result))
        else { return }
        let message: [String: Any] = ["sharingPauseReply": data]
        WCSession.default.transferUserInfo(message)
        if WCSession.default.isReachable { WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: nil) }
    }

    private func save() {
        defaults.set(try? PropertyListEncoder().encode(requests), forKey: "sharing.watchPauses")
    }
}

/// Observe consent and cached cards even when the iPhone Sharing screen is not open.
struct WatchSharingSync: ViewModifier {
    @AppStorage("hideCalorieStatusIcons", store: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app"))
    private var hidesGoalStatus = false
    let runtime: SharingRuntime

    func body(content: Content) -> some View {
        content
            .onChange(of: sources, initial: true) { Connectivity.shared.sendSettingsContext() }
            .onChange(of: hidesGoalStatus) { Connectivity.shared.sendSettingsContext() }
    }

    // Observe value inputs only. Validation, calendar work, and encoding belong
    // to the send operation, after pending consent changes have been applied.
    private var sources: [WatchSharingSource] {
        var sources = runtime.coordinator.map { [WatchSharingSource($0)] } ?? []
        #if DEBUG
        if runtime.samplePeopleEnabled, let samples = runtime.samplePeople {
            sources.append(WatchSharingSource(samples.coordinator))
        }
        #endif
        return sources
    }
}

/// Inputs that affect the watch presentation; publishing bookkeeping is excluded.
struct WatchSharingSource: Equatable {
    let identity: SharingIdentity?
    let accountStatus: SharingAccountStatus
    let connections: [SharingConnection]
    let snapshots: [SharedSnapshotEnvelope]
    let senderCalendars: [String: SharingSenderCalendar]
    let senderNameColors: [String: CalorieCardSnapshot.AdaptiveColor]
    let pendingRevocations: [SharingRevocation]

    @MainActor
    init(_ coordinator: SharingCoordinator) {
        identity = coordinator.identity
        accountStatus = coordinator.accountStatus
        let state = coordinator.state
        connections = state.connections
        snapshots = state.snapshots
        senderCalendars = state.senderCalendars
        senderNameColors = state.senderNameColors
        pendingRevocations = state.pendingRevocations
    }
}
