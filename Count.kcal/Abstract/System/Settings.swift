import SwiftUI

@MainActor
/// Shared goals, units, data source, and appearance preferences.
final class Settings: ObservableObject {

    @Published private var energyEstimates: EnergyEstimates?

    var showResting: Int { currentEnergyEstimates?.resting ?? 0 }
    var showActive: Int { currentEnergyEstimates?.active ?? 0 }

    @AppStorage("showWelcome", store: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app"))
    public var showWelcome: Bool = true
    @AppStorage("closedSettings", store: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app"))
    public var closedSettings: Int = 0

    @AppStorage("hideCalorieStatusIcons", store: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app"))
    public var hideCalorieStatusIcons: Bool = false

    @AppStorage("dailyCardOrder", store: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app"))
    var dailyCardOrder: String = "calories,nutrients,steps"

    @AppStorage("macroOrder", store: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app"))
    var macroOrder: String = "carbs,fats,protein"

    @AppStorage("progressPosition", store: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app"))
    var progressPosition: String = "below"

    @AppStorage("weightGoal", store: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app"))
    public var weightGoal: WeightGoals = .lose {
        didSet {
            if weightGoal != oldValue { updateNutrientGoals() }
        }
    }
    @AppStorage("dataSource", store: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app"))
    public var dataSource: DataSources = .apple {
        didSet {
            if dataSource != oldValue { updateNutrientGoals() }
        }
    }
    
    @AppStorage("customCalPassive", store: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app"))
    public var customCalPassive: Int = 0 {
        didSet {
            if customCalPassive != oldValue { updateNutrientGoals() }
        }
    }
    @AppStorage("customCalActive", store: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app"))
    public var customCalActive: Int = 0 {
        didSet {
            if customCalActive != oldValue { updateNutrientGoals() }
        }
    }
    @AppStorage("balanceGoal", store: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app"))
    public var balanceGoal: Int = 0 {
        didSet {
            if balanceGoal != oldValue { updateNutrientGoals() }
        }
    }
    
    @AppStorage("proteinGoal", store: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app"))
    public var proteinGoal: Int = 0
    @AppStorage("carbsGoal", store: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app"))
    public var carbsGoal: Int = 0
    @AppStorage("fatsGoal", store: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app"))
    public var fatsGoal: Int = 0
    
    @AppStorage("proteinRatio", store: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app"))
    public var proteinRatio: Double = 0 {
        didSet {
            if proteinRatio != oldValue { updateNutrientGoals() }
        }
    }
    @AppStorage("carbsRatio", store: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app"))
    public var carbsRatio: Double = 0 {
        didSet {
            if carbsRatio != oldValue { updateNutrientGoals() }
        }
    }
    @AppStorage("fatsRatio", store: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app"))
    public var fatsRatio: Double = 0 {
        didSet {
            if fatsRatio != oldValue { updateNutrientGoals() }
        }
    }
    
    @AppStorage("appBackground", store: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app"))
    public var appBackground: AppBackgrounds = .dark
    @AppStorage("burnedColor", store: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app"))
    public var burnedColor: Color = Color("ActiveDefault")
    @AppStorage("consumedColor", store: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app"))
    public var consumedColor: Color = Color("ConsumedDefault")
    
    @AppStorage("energyUnit", store: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app"))
    public var energyUnit: EnergyUnit = .kcal {
        didSet {
            if energyUnit != oldValue { updateNutrientGoals() }
        }
    }
    @AppStorage("weightUnit", store: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app"))
    public var weightUnit: WeightUnit = .kg
    
    @AppStorage("stepsGoal", store: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app"))
    public var stepsGoal: Int = 10000

    private var nutrientGoalsReady = false

    private init() {

        // apply the locale default only before the user has saved a weight unit
        if UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app")?.object(forKey: "weightUnit") == nil {
            setDefaultWeightUnit()
        }
        // set default ratios if the saved values are below the slider minimum
        if carbsRatio < 0.1 || fatsRatio < 0.1 || proteinRatio < 0.1 {
            carbsRatio = 0.4
            fatsRatio = 0.35
            proteinRatio = 0.25
        }
        nutrientGoalsReady = true
        // keep saved HealthKit goals until the estimates are loaded
        if usesCustomEnergy { updateNutrientGoals() }
    }

    @MainActor
    /// Updates active and resting estimates from the selected health measurements.
    public func updateShow(repository: HealthRepository? = nil) async {

        let repository = repository ?? .shared

        let revision = repository.revision
        let unit = energyUnit
        let date = Date.now
        async let resting = repository.cumDataWeek(fetch: .basalEnergyBurned, for: date, energyUnit: unit)
        async let active = repository.cumDataWeek(fetch: .activeEnergyBurned, for: date, energyUnit: unit)
        let estimates = await (resting, active)

        // Discard estimates if the user changed units or health mode during the queries.
        guard !Task.isCancelled,
              energyUnit == unit, repository.revision == revision else { return }
        // Publish the complete pair together, including a confirmed empty result.
        energyEstimates = EnergyEstimates(resting: estimates.0, active: estimates.1, unit: unit, revision: revision)
        updateNutrientGoals()
    }

    private var currentEnergyEstimates: EnergyEstimates? {
        guard let energyEstimates,
              energyEstimates.unit == energyUnit,
              energyEstimates.revision == HealthDataMode.currentRevision else { return nil }
        return energyEstimates
    }

    private struct EnergyEstimates {
        let resting: Int
        let active: Int
        let unit: EnergyUnit
        let revision: String
    }

}

@MainActor
extension Settings {

    /// Sample mode uses measured sample energy without changing the saved source preference.
    var usesCustomEnergy: Bool {
        Self.usesCustomEnergy(for: dataSource)
    }

    /// Persists derived goals so widgets and Watch can use the latest phone budget.
    private func updateNutrientGoals() {
        #if !os(watchOS)
        guard nutrientGoalsReady else { return }
        let energy = Double(maxEatingEnergy())
        let unitFactor = energyUnit == .kcal ? 1.0 : 4.184
        let carbs = Int((energy * carbsRatio / (4 * unitFactor)).rounded())
        let fats = Int((energy * fatsRatio / (9 * unitFactor)).rounded())
        let protein = Int((energy * proteinRatio / (4 * unitFactor)).rounded())
        if carbsGoal != carbs { carbsGoal = carbs }
        if fatsGoal != fats { fatsGoal = fats }
        if proteinGoal != protein { proteinGoal = protein }
        #endif
    }

    /// Returns the eating goal after the weight goal adjusts the selected energy source.
    func maxEatingEnergy() -> Int {
        var activeCalories: Int = 0
        var balanceAdjustment: Int = 0

        if !usesCustomEnergy {
            activeCalories = self.showActive + self.showResting
        } else {
            activeCalories = self.customCalActive + self.customCalPassive
        }

        balanceAdjustment = self.weightGoal == .lose ? -self.balanceGoal : self.balanceGoal

        return max(0, activeCalories + balanceAdjustment)
    }

}

@MainActor
extension Settings {

    var isSettingsInputValid: Bool {
        calorieDataState == .ready
    }

    /// Custom budgets resolve immediately; measured budgets wait for their first query.
    var calorieDataState: CalorieDataState {
        CalorieDataState(
            energy: usesCustomEnergy
                ? customCalActive + customCalPassive
                : currentEnergyEstimates.map { $0.resting + $0.active },
            balanceGoal: balanceGoal,
            isLoss: weightGoal == .lose
        )
    }
    
    var isPassiveValid: Bool {
        if !usesCustomEnergy {
            if self.showResting <= 0 { return false }
        } else {
            if self.customCalPassive <= 0 { return false }
        }
                
        return true
    }
    
    var isActiveValid: Bool {
        if !usesCustomEnergy {
            if self.showActive <= 0 { return false }
        } else {
            if self.customCalActive <= 0 { return false }
        }
        
        return true
    }
    
    var isBurnedValid: Bool {
        if !usesCustomEnergy {
            if self.showActive + self.showResting <= 0 { return false }
        } else {
            if self.customCalActive + self.customCalPassive <= 0 { return false }
        }
        
        return true
    }

}

@MainActor
extension Settings {

    /// Uses custom energy if sample mode is off and the saved source is custom.
    static func usesCustomEnergy(for source: DataSources) -> Bool {
        source == .custom && !HealthDataMode.isSampleDataEnabled
    }

}

extension Settings {

    var AppBackground: Color {
        switch self.appBackground {
            case AppBackgrounds.black: return Color.backGroundColorBlack
            case AppBackgrounds.dark: return Color.backGround
            case AppBackgrounds.light: return Color.backGroundColorLight
        }
    }

    var CardBackground: Color {
        switch self.appBackground {
            case Settings.AppBackgrounds.black: return Color.cardColorBlack
            case Settings.AppBackgrounds.dark: return Color.cardColorDark
            case Settings.AppBackgrounds.light: return Color.cardColorLight
        }
    }

    func getGraphEmptyColor(_ scheme: ColorScheme) -> Color {
        if scheme == .light {
            return Color(white: 0.75)
        }
        
        switch self.appBackground {
            case Settings.AppBackgrounds.black: return Color(white: 0.22)
            case Settings.AppBackgrounds.dark: return Color(white: 0.27)
            case Settings.AppBackgrounds.light: return Color(white: 0.32)
        }
    }

}

extension Settings {

    func setDefaultWeightUnit() {
        switch Locale.current.measurementSystem {
            case .metric: self.weightUnit = .kg
            case .us, .uk: self.weightUnit = .lbs
            default: break
        }
    }

}

extension Settings {

    enum WeightGoals: Int {

        case lose = 0
        case gain

    }
    
    enum DataSources: Int {

        case apple = 0
        case custom

    }
    
    enum EnergyUnit: String, CaseIterable, Identifiable {

        case kcal
        case kJ
        
        public var id: Self { self }

    }

    enum WeightUnit: String, CaseIterable, Identifiable {

        case kg
        case lbs
        
        public var id: Self { self }

    }

    enum AppBackgrounds: Int {

        case black = 0
        case dark
        case light

    }

}

extension Settings {

    struct Theme: Identifiable {

        var id = UUID()
        
        let burned: Color
        let consumed: Color

    }

}

extension Settings {

    static let Themes: [Theme] =
    [
        Theme(burned: Color("ActiveDefault"), consumed: Color("ConsumedDefault")),
        Theme(burned: .indigo, consumed: .green),
        Theme(
            burned: Color(red: 250/255, green: 17/255, blue: 79/255).brighten(-0.1),
            consumed: Color(red: 0/255, green: 255/255, blue: 246/255).brighten(-0.3)
        ),
        Theme(
            burned: Color(red: 91_/255, green: 158/255, blue: 219/255),
            consumed: Color(red: 244/255, green: 181/255, blue: 93_/255)
        ),
        Theme(
            burned: Color(red: 166/255, green: 255/255, blue: 0/255).brighten(-0.3),
            consumed: Color(red: 177/255, green: 177/255, blue: 177/255)
        ),
        Theme(
            burned: Color(red: 243/255, green: 175/255, blue: 61/255),
            consumed: Color(red: 120/255, green: 211/255, blue: 248/255)
        ),
        
        Theme(burned: Color(white: 0.4), consumed: Color(white: 0.9)),
        Theme(
            burned: Color(red: 155/255, green: 114/255, blue: 221/255),
            consumed: Color(red: 244/255, green: 199/255, blue: 95/255)
        ),
        Theme(
            burned: Color(red: 55/255, green: 181/255, blue: 160/255),
            consumed: Color(red: 244/255, green: 128/255, blue: 133/255)
        )

    ]

    static public let baseSaturation: Double = 0.8

}

extension Settings {

    static public let shared = Settings()

}

extension Date: @retroactive RawRepresentable {

    public var rawValue: String {
        self.timeIntervalSinceReferenceDate.description
    }
    
    public init?(rawValue: String) {
        self = Date(timeIntervalSinceReferenceDate: Double(rawValue) ?? 0.0)
    }

}

extension View {

    func graphColorAppearance() -> some View {
        modifier(GraphColorAppearance())
    }

    @ViewBuilder
    func brightness(level: BrightnessLevel, to: BrightnessContext = .bargraph) -> some View {
        if level == .none {
            self
        } else {
            self.brightness(level.amount(in: to))
        }
    }

}

/// Finishes graph colors before a bar's clipping or compositing can limit their channels.
private struct GraphColorAppearance: ViewModifier {

    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .saturation(Settings.baseSaturation)
            .brightness(scheme == .dark ? -0.1 : 0)
    }

}

/// Resolves calorie icon colors before drawing to avoid WidgetKit's animated brightness filter.
struct GraphColorStyle: ShapeStyle {

    let color: Color
    let brightness: Double

    init(color: Color, level: BrightnessLevel, context: BrightnessContext = .bargraph) {
        self.init(color: color, brightness: level.amount(in: context))
    }

    init(color: Color, brightness: Double) {
        self.color = color
        self.brightness = brightness
    }

    func resolve(in environment: EnvironmentValues) -> Color {

        guard brightness != 0 else { return color }
        let resolved = color.resolve(in: environment)
        // Keep bright and Display P3 colors in range for WidgetKit's color rendering.
        return Color(
            .sRGB,
            red: min(max(Double(resolved.red) + brightness, 0), 1),
            green: min(max(Double(resolved.green) + brightness, 0), 1),
            blue: min(max(Double(resolved.blue) + brightness, 0), 1),
            opacity: Double(resolved.opacity)
        )
    }

    var gradient: some ShapeStyle { GradientStyle(color: self) }

    private struct GradientStyle: ShapeStyle {

        let color: GraphColorStyle

        func resolve(in environment: EnvironmentValues) -> AnyGradient {
            color.resolve(in: environment).gradient
        }

    }

}

extension Color: @retroactive RawRepresentable {

    public init?(rawValue: String) {
        guard let data = Data(base64Encoded: rawValue) else {
            self = Color.black
            
            return
        }
        
        do {
            self = Color(try NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: data) ?? UIColor.black)
        } catch {
            self = Color.black
        }
    }

    public var rawValue: String {
        do {
            return (try NSKeyedArchiver.archivedData(
                withRootObject: UIColor(self),
                requiringSecureCoding: false
            ) as Data).base64EncodedString()
        } catch {
            return ""
        }
    }

}

enum BrightnessLevel {

    case none
    case primary
    case secondary
    case tertiary

    func amount(in context: BrightnessContext) -> Double {
        switch (context, self) {
            case (_, .none): 0
            case (.bargraph, .primary): 0.1
            case (.circlegraphNow, .primary), (.circlegraphMidnight, .primary): 0
            case (.bargraph, .secondary), (.circlegraphNow, .secondary): 0.2
            case (.circlegraphMidnight, .secondary): 0.15
            case (.bargraph, .tertiary), (.circlegraphNow, .tertiary): 0.3
            case (.circlegraphMidnight, .tertiary): 0.25
        }
    }

}

enum BrightnessContext {

    case bargraph
    case circlegraphNow
    case circlegraphMidnight

}
