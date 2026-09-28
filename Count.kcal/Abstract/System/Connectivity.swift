import SwiftUI
import WatchConnectivity

/// Phone and watch settings transfer through the active connectivity session.
final class Connectivity: NSObject, ObservableObject {

    // used to notify watch view when settings were changed on phone
    @Published var lastReceivedSettingsContext: Date? = nil

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

    @MainActor
    /// Sends the latest phone settings after a local change or session activation.
    func sendSettingsContext() {
        guard WCSession.default.activationState == .activated else { return }
        guard WCSession.default.isWatchAppInstalled else { return }
        guard let context = WatchSettingsSnapshot(settings: .shared).context else { return }

        try? WCSession.default.updateApplicationContext(context)
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) { session.activate() }
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in sendSettingsContext() }
    }
    
    func session(
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

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        guard let snapshot = WatchSettingsSnapshot(context: applicationContext) else { return }

        Task { @MainActor in
            withAnimation(.bouncy(duration: 0.6)) {
                snapshot.apply(to: .shared)
                self.lastReceivedSettingsContext = .now
            }
        }
    }
    
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }
        let context = session.receivedApplicationContext
        guard !context.isEmpty else { return }
        self.session(session, didReceiveApplicationContext: context)
    }

}
#endif

extension Connectivity {

    // only one interface per device needed
    static let shared = Connectivity()

}

#if os(iOS)
private let settingsSyncDefaults = UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app")

/// Observes phone settings for the app's lifetime and sends changes to the watch.
struct SettingsContextSync: ViewModifier {

    @AppStorage("weightGoal", store: settingsSyncDefaults) private var weightGoal: Settings.WeightGoals = .lose
    @AppStorage("dataSource", store: settingsSyncDefaults) private var dataSource: Settings.DataSources = .apple
    @AppStorage("energyUnit", store: settingsSyncDefaults) private var energyUnit: Settings.EnergyUnit = .kcal
    @AppStorage("weightUnit", store: settingsSyncDefaults) private var weightUnit: Settings.WeightUnit = .kg
    @AppStorage("balanceGoal", store: settingsSyncDefaults) private var balanceGoal = 0
    @AppStorage("customCalPassive", store: settingsSyncDefaults) private var customCalPassive = 0
    @AppStorage("customCalActive", store: settingsSyncDefaults) private var customCalActive = 0
    @AppStorage("proteinGoal", store: settingsSyncDefaults) private var proteinGoal = 0
    @AppStorage("carbsGoal", store: settingsSyncDefaults) private var carbsGoal = 0
    @AppStorage("fatsGoal", store: settingsSyncDefaults) private var fatsGoal = 0
    @AppStorage("burnedColor", store: settingsSyncDefaults) private var burnedColor = Color("ActiveDefault")
    @AppStorage("consumedColor", store: settingsSyncDefaults) private var consumedColor = Color("ConsumedDefault")

    func body(content: Content) -> some View {
        content
            .onAppear { Connectivity.shared.sendSettingsContext() }
            .onChange(of: currentSettings) { Connectivity.shared.sendSettingsContext() }
    }

    private var currentSettings: WatchSettingsSnapshot {
        WatchSettingsSnapshot(
            weightGoal: weightGoal.rawValue,
            dataSource: dataSource.rawValue,
            energyUnit: energyUnit.rawValue,
            weightUnit: weightUnit.rawValue,
            balanceGoal: balanceGoal,
            customCalPassive: customCalPassive,
            customCalActive: customCalActive,
            proteinGoal: proteinGoal,
            carbsGoal: carbsGoal,
            fatsGoal: fatsGoal,
            burnedColor: burnedColor.rawValue,
            consumedColor: consumedColor.rawValue
        )
    }

}
#endif

/// Settings values exchanged with the Watch through a property-list context.
private struct WatchSettingsSnapshot: Codable, Equatable {

    let weightGoal: Int?
    let dataSource: Int?
    let energyUnit: String?
    let weightUnit: String?
    let balanceGoal: Int?
    let customCalPassive: Int?
    let customCalActive: Int?
    let proteinGoal: Int?
    let carbsGoal: Int?
    let fatsGoal: Int?
    let burnedColor: String?
    let consumedColor: String?

    var context: [String: Any]? {
        guard let data = try? PropertyListEncoder().encode(self) else { return nil }
        guard let propertyList = try? PropertyListSerialization.propertyList(from: data, format: nil) else { return nil }
        return propertyList as? [String: Any]
    }

}

extension WatchSettingsSnapshot {

    init?(context: [String: Any]) {
        guard let data = try? PropertyListSerialization.data(
            fromPropertyList: context,
            format: .binary,
            options: 0
        ) else { return nil }
        guard let snapshot = try? PropertyListDecoder().decode(Self.self, from: data) else { return nil }
        self = snapshot
    }

    @MainActor
    init(settings: Settings) {

        self.init(
            weightGoal: settings.weightGoal.rawValue,
            dataSource: settings.dataSource.rawValue,
            energyUnit: settings.energyUnit.rawValue,
            weightUnit: settings.weightUnit.rawValue,
            balanceGoal: settings.balanceGoal,
            customCalPassive: settings.customCalPassive,
            customCalActive: settings.customCalActive,
            proteinGoal: settings.proteinGoal,
            carbsGoal: settings.carbsGoal,
            fatsGoal: settings.fatsGoal,
            burnedColor: settings.burnedColor.rawValue,
            consumedColor: settings.consumedColor.rawValue
        )
    }

    @MainActor
    func apply(to settings: Settings) {

        if let weightGoal, let value = Settings.WeightGoals(rawValue: weightGoal) {
            settings.weightGoal = value
        }
        if let dataSource, let value = Settings.DataSources(rawValue: dataSource) {
            settings.dataSource = value
        }
        if let energyUnit, let value = Settings.EnergyUnit(rawValue: energyUnit) {
            settings.energyUnit = value
        }
        if let weightUnit, let value = Settings.WeightUnit(rawValue: weightUnit) {
            settings.weightUnit = value
        }
        if let balanceGoal { settings.balanceGoal = balanceGoal }
        if let customCalPassive { settings.customCalPassive = customCalPassive }
        if let customCalActive { settings.customCalActive = customCalActive }
        if let proteinGoal { settings.proteinGoal = proteinGoal }
        if let carbsGoal { settings.carbsGoal = carbsGoal }
        if let fatsGoal { settings.fatsGoal = fatsGoal }
        if let burnedColor, let color = Color(rawValue: burnedColor) {
            settings.burnedColor = color
        }
        if let consumedColor, let color = Color(rawValue: consumedColor) {
            settings.consumedColor = color
        }
    }

}
