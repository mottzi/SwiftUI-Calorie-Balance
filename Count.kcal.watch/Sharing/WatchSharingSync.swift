import SwiftUI

/// Receives context for the app's lifetime, independently of navigation or HealthKit access.
struct WatchSharingReceiver: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    let store: WatchSharingStore
    let connectivity: Connectivity

    func body(content: Content) -> some View {
        content
            .onChange(of: connectivity.receivedSharingData, initial: true) {
                guard receivesLiveData else { return }
                guard let data = connectivity.receivedSharingData,
                      let snapshot = try? PropertyListDecoder().decode(WatchSharingSnapshot.self, from: data) else { return }
                store.receive(snapshot)
            }
            .onChange(of: connectivity.receivedSharingReply, initial: true) {
                guard receivesLiveData else { return }
                guard let data = connectivity.receivedSharingReply,
                      let reply = try? PropertyListDecoder().decode(WatchSharingPauseReply.self, from: data) else { return }
                store.receive(reply)
            }
            .onChange(of: store.pendingPauses) { sendPending() }
            .onChange(of: connectivity.isActivated) { sendPending() }
            .onChange(of: connectivity.isPhoneReachable) {
                if connectivity.isPhoneReachable { sendPending(); connectivity.requestSharingUpdate() }
            }
            .onChange(of: scenePhase, initial: true) {
                if scenePhase == .active { sendPending(); connectivity.requestSharingUpdate() }
            }
    }

    private func sendPending() {
        guard receivesLiveData else { return }
        for request in store.pendingPauses {
            if let data = try? PropertyListEncoder().encode(request) { connectivity.sendSharingPause(data) }
        }
    }

    private var receivesLiveData: Bool {
        #if DEBUG
        !WatchSharingFixtures.isActive
        #else
        true
        #endif
    }
}
