import SwiftUI

extension Settings
{
    var isSettingsInputValid: Bool
    {
        if self.balanceGoal < 0 { return false }
        if self.dataSource == .custom && (self.customCalActive + self.customCalPassive <= 0) { return false }
        if self.maxEatingEnergy() <= 0 { return false }
        
        return true
    }
    
    var isPassiveValid: Bool
    {
        if self.dataSource == .apple
        {
            if self.showResting <= 0 { return false }
        }
        else
        {
            if self.customCalPassive <= 0 { return false }
        }
        
        return true
    }
    
    var isActiveValid: Bool
    {
        if self.dataSource == .apple
        {
            if self.showActive <= 0 { return false }
        }
        else
        {
            if self.customCalActive <= 0 { return false }
        }
        
        return true
    }
    
    var isBurnedValid: Bool
    {
        if self.dataSource == .apple
        {
            if self.showActive + self.showResting <= 0 { return false }
        }
        else
        {
            if self.customCalActive + self.customCalPassive <= 0 { return false }
        }
        
        return true
    }
}

extension Settings
{
    func setDefaultWeightUnit()
    {
        switch Locale.current.measurementSystem
        {
            case .metric:
                self.weightUnit = .kg
            case .us, .uk:
                self.weightUnit = .lbs
            default:
                break
        }
    }
}

extension Settings
{
    func maxEatingEnergy(/*_ showActive: Int, _ showResting: Int*/) -> Int
    {
        var activeCalories: Int = 0
        var balanceAdjustment: Int = 0

        if self.dataSource == .apple
        {
//            if let showActive, let showResting
//            {
            activeCalories = self.showActive + self.showResting
//            }
//            else
//            {
//                activeCalories = 0
//            }
        }
        else
        {
            activeCalories = self.customCalActive + self.customCalPassive
        }
        
        balanceAdjustment = self.weightGoal == .lose ? -self.balanceGoal : self.balanceGoal
        
        return max(0, activeCalories + balanceAdjustment)
    }
}

extension Settings
{
    enum WeightGoals: Int
    {
        case lose = 0
        case gain
    }
    
    enum DataSources: Int
    {
        case apple = 0
        case custom
    }
    
    enum EnergyUnit: String, CaseIterable, Identifiable
    {
        case kcal
        case kJ
        
        public var id: Self { self }
    }

    enum WeightUnit: String, CaseIterable, Identifiable
    {
        case kg
        case lbs
        
        public var id: Self { self }
    }
}

extension Settings
{
    enum AppBackgrounds: Int
    {
        case black = 0
        case dark
        case light
    }
    
    var AppBackground: Color
    {
        switch self.appBackground
        {
            case AppBackgrounds.black:
                Color.backGroundColorBlack

            case AppBackgrounds.dark:
                Color.backGround
            
            case AppBackgrounds.light:
                Color.backGroundColorLight
        }
    }
    
    var CardBackground: Color
    {
        switch self.appBackground
        {
            case Settings.AppBackgrounds.black:
                return Color.cardColorBlack
            
            case Settings.AppBackgrounds.dark:
                return Color.cardColorDark
            
            case Settings.AppBackgrounds.light:
                return Color.cardColorLight
        }
    }
    
    func getGraphEmptyColor(_ scheme: ColorScheme) -> Color
    {
        if scheme == .light
        {
            return Color(white: 0.75)
        }
        
        switch self.appBackground
        {
            case Settings.AppBackgrounds.black:
                return Color(white: 0.22)
            
            case Settings.AppBackgrounds.dark:
                return Color(white: 0.27)
            
            case Settings.AppBackgrounds.light:
                return Color(white: 0.32)
        }
    }
}

extension Settings
{
    struct Theme: Identifiable
    {
        var id = UUID()
        let burned: Color
        let consumed: Color
    }
    
    static let Themes: [Theme] =
    [
        Theme(burned: Color("ActiveDefault"), consumed: Color("ConsumedDefault")),
        Theme(burned: .indigo, consumed: .green),
        Theme(burned: Color(red: 250/255, green: 17/255, blue: 79/255).brighten(-0.1), consumed: Color(red: 0/255, green: 255/255, blue: 246/255).brighten(-0.3)),
        Theme(burned: Color(red: 91_/255, green: 158/255, blue: 219/255), consumed: Color(red: 244/255, green: 181/255, blue: 93_/255)),
        Theme(burned: Color(red: 166/255, green: 255/255, blue: 0/255).brighten(-0.3), consumed: Color(red: 177/255, green: 177/255, blue: 177/255)),
        Theme(burned: Color(red: 243/255, green: 175/255, blue: 61/255), consumed: Color(red: 120/255, green: 211/255, blue: 248/255)),
        
        Theme(burned: Color(white: 0.4), consumed: Color(white: 0.9))

    ]
}

//enum Keys: String, CaseIterable
//{
//    case setting
//    case context
//    case date
//    case colors
//    case burnedColor
//    case consumedColor
//    
//    case weightGoal
//    case dataSource
//    case customCalPassive
//    case customCalActive
//    case balanceGoal
//    case proteinGoal
//    case carbsGoal
//    case fatsGoal
//    case energyUnit
//    case weightUnit
//}

final class Settings: ObservableObject
{
    private init() {}
    static public let shared = Settings()
    
    static public let baseSaturation: Double = 0.8
    
    @Published var showResting: Int = 0
    @Published var showActive: Int = 0
    
    @MainActor
    public func updateShow() async
    {
        self.showResting = await HKRepository.shared.cumDataWeek(fetch: .basalEnergyBurned, for: .now)
        self.showActive = await HKRepository.shared.cumDataWeek(fetch: .activeEnergyBurned, for: .now)
    }

    @AppStorage("showWelcome", store: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app")) public var showWelcome: Bool = true
    @AppStorage("closedSettings", store: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app")) public var closedSettings: Int = 0

    @AppStorage("weightGoal", store: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app")) public var weightGoal: WeightGoals = .lose
    @AppStorage("dataSource", store: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app")) public var dataSource: DataSources = .apple
    
    @AppStorage("customCalPassive", store: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app")) public var customCalPassive: Int = 0
    @AppStorage("customCalActive", store: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app")) public var customCalActive: Int = 0
    @AppStorage("balanceGoal", store: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app")) public var balanceGoal: Int = 0
    
    @AppStorage("proteinGoal", store: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app")) public var proteinGoal: Int = 0
    @AppStorage("carbsGoal", store: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app")) public var carbsGoal: Int = 0
    @AppStorage("fatsGoal", store: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app")) public var fatsGoal: Int = 0
    
    @AppStorage("proteinRatio", store: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app")) public var proteinRatio: Double = 0
    @AppStorage("carbsRatio", store: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app")) public var carbsRatio: Double = 0
    @AppStorage("fatsRatio", store: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app")) public var fatsRatio: Double = 0
    
    @AppStorage("appBackground", store: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app")) public var appBackground: AppBackgrounds = .dark
    @AppStorage("burnedColor", store: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app")) public var burnedColor: Color = Color("ActiveDefault")
    @AppStorage("consumedColor", store: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app")) public var consumedColor: Color = Color("ConsumedDefault")
    
    @AppStorage("energyUnit", store: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app")) public var energyUnit: EnergyUnit = .kcal
    @AppStorage("weightUnit", store: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app")) public var weightUnit: WeightUnit = .kg
    
    @AppStorage("stepsGoal", store: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app")) public var stepsGoal: Int = 10000
}

extension Date: @retroactive RawRepresentable 
{
    public var rawValue: String 
    {
        self.timeIntervalSinceReferenceDate.description
    }
    
    public init?(rawValue: String) 
    {
        self = Date(timeIntervalSinceReferenceDate: Double(rawValue) ?? 0.0)
    }
}

enum BrightnessLevel
{
    case none
    case primary
    case secondary
    case tertiary
}

enum BrightnessContext 
{
    case bargraph
    case circlegraphNow
    case circlegraphMidnight
}

extension View
{    
    @ViewBuilder
    func brightness(level: BrightnessLevel, to: BrightnessContext = .bargraph) -> some View
    {
        switch to 
        {
            case .bargraph:
                switch level
                {
                    case .primary:
                        self.brightness(0.1)
                    case .secondary:
                        self.brightness(0.2)
                    case .tertiary:
                        self.brightness(0.3)
                    case .none:
                        self
                }
            case .circlegraphNow:
                switch level
                {
                    case .primary:
                        self.brightness(0.0)
                    case .secondary:
                        self.brightness(0.2)
                    case .tertiary:
                        self.brightness(0.3)
                    case .none:
                        self
                }
            case .circlegraphMidnight:
                switch level
                {
                    case .primary:
                        self.brightness(0.0)
                    case .secondary:
                        self.brightness(0.15)
                    case .tertiary:
                        self.brightness(0.35)
                    case .none:
                        self
                }
        }
    }
}

extension Color: @retroactive RawRepresentable
{
    public init?(rawValue: String)
    {
        guard let data = Data(base64Encoded: rawValue) else
        {
            self = Color.black
            
            return
        }
        
        do
        {
            self = Color(try NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: data) ?? UIColor.black)
        }
        catch
        {
            self = Color.black
        }
    }

    public var rawValue: String
    {
        do
        {
            return (try NSKeyedArchiver.archivedData(withRootObject: UIColor(self), requiringSecureCoding: false) as Data).base64EncodedString()
        }
        catch
        {
            return ""
        }
    }
}
