import SwiftUI
import Observation
import WatchConnectivity
import WidgetKit

/// Phone and watch settings transfer through the active connectivity session.
@MainActor
@Observable
final class Connectivity: NSObject {

    // used to notify watch view when settings were changed on phone
    private(set) var lastReceivedSettingsContext: Date? = nil
    private(set) var receivedWeightHistory: WeightHistorySnapshot?
    private var latestWeightHistory: WeightHistorySnapshot?
    private(set) var receivedSharingData: Data?
    private(set) var receivedSharingReply: Data?
    private(set) var isPhoneReachable = false
    private(set) var isActivated = false

    private override init() {
        super.init()
        
        // WC is availiable in watchOS
        #if !os(watchOS)
        guard WCSession.isSupported() else { return }
        #endif
        
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

}

// sender
#if os(iOS)
extension Connectivity: WCSessionDelegate {

    /// Sends weight history together with settings in the latest application context.
    func sendWeightHistory(_ snapshot: WeightHistorySnapshot?) {
        latestWeightHistory = snapshot
        sendSettingsContext()
    }

    @MainActor
    /// Sends the latest phone settings after a local change or session activation.
    func sendSettingsContext() {
        #if !WIDGET_EXTENSION
        // Apply consent changes before deriving any outgoing presentation.
        WatchSharingPhone.shared.processPending(runtime: .shared)
        #endif
        guard WCSession.default.activationState == .activated,
              WCSession.default.isWatchAppInstalled else { return }
        var snapshot = WatchSettingsSnapshot(settings: .shared, weightHistory: latestWeightHistory)
        #if !WIDGET_EXTENSION
        if let sharing = WatchSharingSnapshot(runtime: .shared, hidesGoalStatus: Settings.shared.hideCalorieStatusIcons) {
            snapshot.sharing = try? PropertyListEncoder().encode(sharing)
        } else {
            snapshot.sharing = WatchSettingsSnapshot(context: WCSession.default.applicationContext)?.sharing
        }
        #endif
        guard let context = snapshot.context else { return }

        try? WCSession.default.updateApplicationContext(context)
    }
    
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) { session.activate() }
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in sendSettingsContext() }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        receiveWatchMessage(userInfo)
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        receiveWatchMessage(message)
    }

    private nonisolated func receiveWatchMessage(_ message: [String: Any]) {
        #if !WIDGET_EXTENSION
        let request = (message["sharingPause"] as? Data).flatMap {
            try? PropertyListDecoder().decode(WatchSharingPauseRequest.self, from: $0)
        }
        let refresh = message["sharingRefresh"] as? Bool == true
        Task { @MainActor in
            if let request { WatchSharingPhone.shared.receive(request) }
            if refresh {
                await SharingRuntime.shared.refresh()
                sendSettingsContext()
            }
        }
        #endif
    }
    
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }
        Task { @MainActor in sendSettingsContext() }
    }

}
#endif

// receiver
#if os(watchOS)
extension Connectivity: WCSessionDelegate {

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        guard let snapshot = WatchSettingsSnapshot(context: applicationContext) else { return }

        Task { @MainActor in
            withAnimation(.bouncy(duration: 0.6)) {
                snapshot.apply(to: .shared)
                self.receivedWeightHistory = snapshot.weightHistory
                if let sharing = snapshot.sharing { self.receivedSharingData = sharing }
                self.lastReceivedSettingsContext = .now
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }
    
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }
        Task { @MainActor in
            self.isActivated = true
            self.isPhoneReachable = session.isReachable
        }
        let context = session.receivedApplicationContext
        guard !context.isEmpty else { return }
        self.session(session, didReceiveApplicationContext: context)
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in self.isPhoneReachable = reachable }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        receivePhoneMessage(userInfo)
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        receivePhoneMessage(message)
    }

    private nonisolated func receivePhoneMessage(_ message: [String: Any]) {
        guard let reply = message["sharingPauseReply"] as? Data else { return }
        Task { @MainActor in self.receivedSharingReply = reply }
    }

    func requestSharingUpdate() {
        guard WCSession.default.activationState == .activated, WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["sharingRefresh": true], replyHandler: nil, errorHandler: nil)
    }

    /// Background delivery survives disconnection; reachable phones also get the request immediately.
    func sendSharingPause(_ data: Data) {
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        let message: [String: Any] = ["sharingPause": data]
        if !session.outstandingUserInfoTransfers.contains(where: { ($0.userInfo["sharingPause"] as? Data) == data }) {
            session.transferUserInfo(message)
        }
        if session.isReachable { session.sendMessage(message, replyHandler: nil, errorHandler: nil) }
    }

}
#endif

extension Connectivity {

    // only one interface per device needed
    static let shared = Connectivity()

}

#if os(iOS)
/// Observes phone settings for the app's lifetime and sends changes to the watch.
struct SettingsContextSync: ViewModifier {

    @AppStorage("weightGoal", store: settingsSyncDefaults) private var weightGoal: Settings.WeightGoals = .lose
    @AppStorage("dataSource", store: settingsSyncDefaults) private var dataSource: Settings.DataSources = .apple
    @AppStorage("energyUnit", store: settingsSyncDefaults) private var energyUnit: Settings.EnergyUnit = .kcal
    @AppStorage("weightUnit", store: settingsSyncDefaults) private var weightUnit: Settings.WeightUnit = .kg
    @AppStorage("balanceGoal", store: settingsSyncDefaults) private var balanceGoal = 0
    @AppStorage("customCalPassive", store: settingsSyncDefaults) private var customCalPassive = 0
    @AppStorage("customCalActive", store: settingsSyncDefaults) private var customCalActive = 0
    @AppStorage("stepsGoal", store: settingsSyncDefaults) private var stepsGoal = 10000
    @AppStorage("proteinGoal", store: settingsSyncDefaults) private var proteinGoal = 0
    @AppStorage("carbsGoal", store: settingsSyncDefaults) private var carbsGoal = 0
    @AppStorage("fatsGoal", store: settingsSyncDefaults) private var fatsGoal = 0
    @AppStorage("burnedColor", store: settingsSyncDefaults) private var burnedColor = Color("ActiveDefault")
    @AppStorage("consumedColor", store: settingsSyncDefaults) private var consumedColor = Color("ConsumedDefault")

    let weightHistory: WeightHistory

    func body(content: Content) -> some View {
        content
            .onAppear { Connectivity.shared.sendSettingsContext() }
            .onChange(of: currentSettings) { Connectivity.shared.sendSettingsContext() }
            .onChange(of: HealthDataMode.shared.revision) { Connectivity.shared.sendSettingsContext() }
            .onChange(of: weightHistory.snapshot, initial: true) { _, snapshot in
                Connectivity.shared.sendWeightHistory(snapshot)
            }
    }

}

extension SettingsContextSync {

    private var currentSettings: WatchSettingsSnapshot {
        WatchSettingsSnapshot(
            weightGoal: weightGoal.rawValue,
            dataSource: dataSource.rawValue,
            energyUnit: energyUnit.rawValue,
            weightUnit: weightUnit.rawValue,
            balanceGoal: balanceGoal,
            customCalPassive: customCalPassive,
            customCalActive: customCalActive,
            stepsGoal: stepsGoal,
            proteinGoal: proteinGoal,
            carbsGoal: carbsGoal,
            fatsGoal: fatsGoal,
            burnedColor: burnedColor.rawValue,
            consumedColor: consumedColor.rawValue
        )
    }

}

private let settingsSyncDefaults = UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app")
#endif
