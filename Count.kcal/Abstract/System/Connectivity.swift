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
    
    func sessionDidBecomeInactive(_ session: WCSession) { WCSession.default.activate() }
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }
    
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) { }

}
#endif
    
// receiver
#if os(watchOS)
extension Connectivity: WCSessionDelegate {

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        DispatchQueue.main.async {
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
                
                if let strC = applicationContext["consumedColor"] as? String,
                   let dataC = Data(base64Encoded: strC),
                   let colorC = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: dataC) {
                    Settings.shared.consumedColor = Color(colorC)
                }

                if let strB = applicationContext["burnedColor"] as? String,
                   let dataB = Data(base64Encoded: strB),
                   let colorB = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: dataB) {
                    Settings.shared.burnedColor = Color(colorB)
                }
                
                self.lastReceivedSettingsContext = .now
            }
        }
    }
    
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) { }

}
#endif

extension Connectivity {

    // only one interface per device needed
    static let shared = Connectivity()

}

#if os(iOS)
// use View.sendContextOnChange(of:) to send settings-dictionary to
// watch when a setting was changed on the phone
struct SendContextOnChange<V: Equatable>: ViewModifier {

    var value: V

    func body(content: Content) -> some View {
        content
            .onChange(of: value) {
                Connectivity.shared.sendSettingsContext()
            }
    }

}

extension View {

    func sendContextOnChange<V: Equatable>(of value: V) -> some View {
        self.modifier(SendContextOnChange(value: value))
    }

}
#endif
