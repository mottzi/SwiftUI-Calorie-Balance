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
        
        // convert settings saved in phone app storage to settings-dictionary
        let d: [String: Any] =
        [
            "weightGoal": Settings.shared.weightGoal.rawValue,
            "dataSource": Settings.shared.dataSource.rawValue,
            "energyUnit": Settings.shared.energyUnit.rawValue,
            "weightUnit": Settings.shared.weightUnit.rawValue,
            "balanceGoal": Settings.shared.balanceGoal,
            "customCalPassive": Settings.shared.customCalPassive,
            "customCalActive": Settings.shared.customCalActive,
            "proteinGoal": Settings.shared.proteinGoal,
            "carbsGoal": Settings.shared.carbsGoal,
            "fatsGoal": Settings.shared.fatsGoal,
            "burnedColor": Settings.shared.burnedColor.rawValue,
            "consumedColor": Settings.shared.consumedColor.rawValue,
        ]
        
        // only send the most recently scheduled settings-directory to watch
        try? WCSession.default.updateApplicationContext(d)
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
        Task { @MainActor in
            // extract individual settings from received phone settings-dictionary
            // and persist them in watch app storage
            withAnimation(.bouncy(duration: 0.6)) {
                if let weightGoal = applicationContext["weightGoal"] as? Int,
                   let translate = Settings.WeightGoals(rawValue: weightGoal) {
                    Settings.shared.weightGoal = translate
                }
                
                if let dataSource = applicationContext["dataSource"] as? Int,
                   let translate = Settings.DataSources(rawValue: dataSource) {
                    Settings.shared.dataSource = translate
                }
                
                if let customCalPassive = applicationContext["customCalPassive"] as? Int {
                    Settings.shared.customCalPassive = customCalPassive
                }
                
                if let customCalActive = applicationContext["customCalActive"] as? Int {
                    Settings.shared.customCalActive = customCalActive
                }
                
                if let balanceGoal = applicationContext["balanceGoal"] as? Int {
                    Settings.shared.balanceGoal = balanceGoal
                }
                
                if let proteinGoal = applicationContext["proteinGoal"] as? Int {
                    Settings.shared.proteinGoal = proteinGoal
                }
                
                if let carbsGoal = applicationContext["carbsGoal"] as? Int {
                    Settings.shared.carbsGoal = carbsGoal
                }
                
                if let fatsGoal = applicationContext["fatsGoal"] as? Int {
                    Settings.shared.fatsGoal = fatsGoal
                }
                
                if let energyUnit = applicationContext["energyUnit"] as? String,
                   let translate = Settings.EnergyUnit(rawValue: energyUnit) {
                    Settings.shared.energyUnit = translate
                }
                
                if let weightUnit = applicationContext["weightUnit"] as? String,
                   let translate = Settings.WeightUnit(rawValue: weightUnit) {
                    Settings.shared.weightUnit = translate
                }
                
                if let raw = applicationContext["consumedColor"] as? String,
                   let color = Color(rawValue: raw) {
                    Settings.shared.consumedColor = color
                }

                if let raw = applicationContext["burnedColor"] as? String,
                   let color = Color(rawValue: raw) {
                    Settings.shared.burnedColor = color
                }
                
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

    private var currentSettings: SettingsValues {
        SettingsValues(
            weightGoal: weightGoal,
            dataSource: dataSource,
            energyUnit: energyUnit,
            weightUnit: weightUnit,
            balanceGoal: balanceGoal,
            customCalPassive: customCalPassive,
            customCalActive: customCalActive,
            proteinGoal: proteinGoal,
            carbsGoal: carbsGoal,
            fatsGoal: fatsGoal,
            burnedColor: burnedColor,
            consumedColor: consumedColor
        )
    }

    private struct SettingsValues: Equatable {
        let weightGoal: Settings.WeightGoals
        let dataSource: Settings.DataSources
        let energyUnit: Settings.EnergyUnit
        let weightUnit: Settings.WeightUnit
        let balanceGoal: Int
        let customCalPassive: Int
        let customCalActive: Int
        let proteinGoal: Int
        let carbsGoal: Int
        let fatsGoal: Int
        let burnedColor: Color
        let consumedColor: Color
    }

}
#endif
