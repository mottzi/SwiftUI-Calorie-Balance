import Foundation
import Observation

/// Cached watch presentation and the small outbox of pause requests awaiting the iPhone.
@MainActor @Observable
final class WatchSharingStore {
    private(set) var snapshot: WatchSharingSnapshot?
    private(set) var pendingPauses: [WatchSharingPauseRequest]
    private(set) var failedPauses: Set<UUID> = []
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        snapshot = defaults.data(forKey: "watch.sharing.snapshot").flatMap {
            try? PropertyListDecoder().decode(WatchSharingSnapshot.self, from: $0)
        }
        pendingPauses = defaults.data(forKey: "watch.sharing.pauses").flatMap {
            try? PropertyListDecoder().decode([WatchSharingPauseRequest].self, from: $0)
        } ?? []
    }

    func receive(_ snapshot: WatchSharingSnapshot) {
        if self.snapshot?.accountID != snapshot.accountID { failedPauses = [] }
        self.snapshot = snapshot
        pendingPauses.removeAll { request in
            guard request.accountID == snapshot.accountID,
                  let person = snapshot.people.first(where: { $0.id == request.connectionID }), person.canPause else { return true }
            if request.revision != person.revision {
                failedPauses.insert(person.id)
                return true
            }
            return false
        }
        defaults.set(try? PropertyListEncoder().encode(snapshot), forKey: "watch.sharing.snapshot")
        saveOutbox()
    }

    @discardableResult
    func requestPause(for person: WatchSharingSnapshot.Person) -> WatchSharingPauseRequest? {
        guard let accountID = snapshot?.accountID, person.canPause else { return nil }
        if let pending = pendingPauses.first(where: { $0.connectionID == person.id }) { return pending }
        let request = WatchSharingPauseRequest(accountID: accountID, connectionID: person.id, revision: person.revision)
        pendingPauses.append(request)
        failedPauses.remove(person.id)
        saveOutbox()
        return request
    }

    func receive(_ reply: WatchSharingPauseReply) {
        guard let request = pendingPauses.first(where: { $0.id == reply.requestID }) else { return }
        // A saved reply is followed by the authoritative context, including pending revocations.
        guard reply.result != .saved else { return }
        pendingPauses.removeAll { $0.id == reply.requestID }
        failedPauses.insert(request.connectionID)
        saveOutbox()
    }

    private func saveOutbox() {
        defaults.set(try? PropertyListEncoder().encode(pendingPauses), forKey: "watch.sharing.pauses")
    }
}
