import SwiftUI
import WatchConnectivity
import WidgetKit

final class Connectivity: NSObject, ObservableObject
{
    // only one interface per device needed
    static let shared = Connectivity()
    
    // used to limit transmissions from phone to watch
    // private var lastSentBalanceContext: Date? = nil
    
    // used to notify watch view when settings were changed on phone
    @Published var lastReceivedSettingsContext: Date? = nil

    private override init()
    {
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
extension Connectivity: WCSessionDelegate
{
    func sendSettingsContext()
    {
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
    
//    func sendBalanceContext(sample: HealthData)
//    {
//        guard WCSession.default.activationState == .activated else { return }
//        guard WCSession.default.isWatchAppInstalled else { return }
//        
//        // rate limitat transmissions
//        guard self.lastSentBalanceContext == nil || abs(Date.now.timeIntervalSince(self.lastSentBalanceContext!)) > 10
//        else { return }
//        
//        if WCSession.default.remainingComplicationUserInfoTransfers > 0
//        {
//            WCSession.default.transferCurrentComplicationUserInfo([
//                "context": "balance",
//                "date": sample.date,
//                "burnedActive": sample.burnedActive,
//                "burnedActive7": sample.burnedActive7,
//                "burnedPassive": sample.burnedPassive,
//                "burnedPassive7": sample.burnedPassive7,
//                "consumed": sample.consumed,
//                "protein": sample.protein,
//                "carbs": sample.carbs,
//                "fats": sample.fats
//            ])
//            
//            self.lastSentBalanceContext = .now
//        }
//    }
    
    func sessionDidBecomeInactive(_ session: WCSession) { WCSession.default.activate() }
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) { }
}
#endif
    
// receiver
#if os(watchOS)
extension Connectivity: WCSessionDelegate
{
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) 
    {
        DispatchQueue.main.async
        {
            // extract individual settings from received phone settings-dictionary
            // and persist them in watch app storage
            withAnimation(.bouncy(duration: 0.6))
            {
                if let weightGoal = applicationContext["weightGoal"] as? Int,
                   let translate = Settings.WeightGoals(rawValue: weightGoal)
                {
                    Settings.shared.weightGoal = translate
                }
                
                if let dataSource = applicationContext["dataSource"] as? Int,
                   let translate = Settings.DataSources(rawValue: dataSource)
                {
                    Settings.shared.dataSource = translate
                }
                
                if let customCalPassive = applicationContext["customCalPassive"] as? Int
                {
                    Settings.shared.customCalPassive = customCalPassive
                }
                
                if let customCalActive = applicationContext["customCalActive"] as? Int
                {
                    Settings.shared.customCalActive = customCalActive
                }
                
                if let balanceGoal = applicationContext["balanceGoal"] as? Int
                {
                    Settings.shared.balanceGoal = balanceGoal
                }
                
                if let proteinGoal = applicationContext["proteinGoal"] as? Int
                {
                    Settings.shared.proteinGoal = proteinGoal
                }
                
                if let carbsGoal = applicationContext["carbsGoal"] as? Int
                {
                    Settings.shared.carbsGoal = carbsGoal
                }
                
                if let fatsGoal = applicationContext["fatsGoal"] as? Int
                {
                    Settings.shared.fatsGoal = fatsGoal
                }
                
                if let energyUnit = applicationContext["energyUnit"] as? String,
                   let translate = Settings.EnergyUnit(rawValue: energyUnit)
                {
                    Settings.shared.energyUnit = translate
                }
                
                if let weightUnit = applicationContext["weightUnit"] as? String,
                   let translate = Settings.WeightUnit(rawValue: weightUnit)
                {
                    Settings.shared.weightUnit = translate
                }
                
                if let strC = applicationContext["consumedColor"] as? String,
                   let dataC = Data(base64Encoded: strC),
                   let colorC = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: dataC)
                {
                    Settings.shared.consumedColor = Color(colorC)
                }

                if let strB = applicationContext["burnedColor"] as? String,
                   let dataB = Data(base64Encoded: strB),
                   let colorB = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: dataB)
                {
                    Settings.shared.burnedColor = Color(colorB)
                }
                
                self.lastReceivedSettingsContext = .now
            }
        }
    }
    
//    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) 
//    {
//        guard let context = userInfo["context"] as? String,
//              context == "balance"
//        else { return }
//                       
//        guard let date = userInfo["date"] as? Date,
//              let burnedActive = userInfo["burnedActive"] as? Int,
//              let burnedActive7 = userInfo["burnedActive7"] as? Int,
//              let burnedPassive = userInfo["burnedPassive"] as? Int,
//              let burnedPassive7 = userInfo["burnedPassive7"] as? Int,
//              let consumed = userInfo["consumed"] as? Int,
//              let protein = userInfo["protein"] as? Int,
//              let carbs = userInfo["carbs"] as? Int,
//              let fats = userInfo["fats"] as? Int
//        else { return }
//        
//        guard let SharedDefaults = UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app")
//        else { return }
//        
//        // TimelineProvider uses this to determine wether to use this data or fetch data on its own
//        SharedDefaults.set(Date.now, forKey: "lastReceivedBalanceContext")
//        
//        SharedDefaults.set(date, forKey: "date")
//        SharedDefaults.set(burnedActive, forKey: "burnedActive")
//        SharedDefaults.set(burnedActive7, forKey: "burnedActive7")
//        SharedDefaults.set(burnedPassive, forKey: "burnedPassive")
//        SharedDefaults.set(burnedPassive7, forKey: "burnedPassive7")
//        SharedDefaults.set(consumed, forKey: "consumed")
//        SharedDefaults.set(protein, forKey: "protein")
//        SharedDefaults.set(carbs, forKey: "carbs")
//        SharedDefaults.set(fats, forKey: "fats")
//        
//        WidgetCenter.shared.reloadAllTimelines()
//    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) { }
}
#endif

#if os(iOS)
// use View.sendContextOnChange(of:) to send settings-dictionary to
// watch when a setting was changed on the phone
struct SendContextOnChange<V: Equatable>: ViewModifier
{
    var value: V

    func body(content: Content) -> some View
    {
        content
            .onChange(of: value)
            {
                Connectivity.shared.sendSettingsContext()
            }
    }
}

extension View
{
    func sendContextOnChange<V: Equatable>(of value: V) -> some View
    {
        self.modifier(SendContextOnChange(value: value))
    }
}
#endif
