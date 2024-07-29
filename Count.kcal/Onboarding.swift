import SwiftUI

enum OnboardingState: Int, CaseIterable
{
    case welcome = 0
    case applehealth = 1
    case maingoal = 2
    case datasource = 3
    case balancegoal = 4
}

let OnboardingButtonText =
[
    String(localized: "Start"),
    String(localized: "Allow"),
    String(localized: "Next"),
    String(localized: "Next"),
    String(localized: "Finish"),
]

struct Onboarding: View
{
    @EnvironmentObject private var AppSettings: Settings

    @State private var selection: OnboardingState = .welcome
    @State private var showButton = false
    
    var smallScreen: Bool
    {
        UIScreen.main.bounds.height < 700
    }
    
    var body: some View
    {
        VStack(spacing: 0)
        {
            if selection == .welcome
            {
                OnboardingWelcome()
                    .transition(.opacity.combined(with: .offset(y: -200)))
            }
                        
            OnboardingContent(selection: selection)
                        
            OnboardingButton(selection: $selection)
                .offset(y: showButton ? 0 : 300)
        }
        .onAppear
        {
            selection = .welcome
            AppSettings.setDefaultWeightUnit()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6)
            {
                withAnimation(.smooth(duration: 1.5))
                {
                    showButton = true
                }
            }
        }
        .padding(.top, smallScreen ? 30 : 60)
        .padding(.bottom, 60)
    }
}

struct OnboardingContent: View 
{
    let selection: OnboardingState

    var body: some View
    {
        Group
        {
            switch selection
            {
                case .welcome: do
                {
                    WelcomeView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .padding(.top, -30)
                        .padding(.horizontal, -40)
                        .offset(y: -20)
                }
                    
                case .applehealth:
                    AppleHealthView()
                    
                case .maingoal:
                    MaingoalView()
                    
                case .datasource:
                    DataSourceView()
                    
                case .balancegoal:
                    BalanceGoalView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 40)
        .padding(.top, 30)
        .transition(.scale(scale: 0.1).combined(with: .opacity))
    }
}

struct BalanceGoalView: View
{
    @EnvironmentObject private var AppSettings: Settings
    @Environment(HSlider.self) private var SliderData
    
    @State private var balanceSlider = 0.0
    
    var body: some View
    {
        VStack(spacing: 30)
        {
            VStack(spacing: 30)
            {
                (
                    Text("What is your")
                        .foregroundStyle(Color("TextColor").opacity(0.8))
                        .fontWeight(.light)
                    +
                    Text(verbatim: " ")
                    +
                    Text((String(localized: AppSettings.weightGoal == .lose ? "Calorie Deficit" : "Calorie Surplus")))
                    +
                    Text(verbatim: " ")
                    +
                    Text("goal")
                        .foregroundStyle(Color("TextColor").opacity(0.8))
                        .fontWeight(.light)
                    +
                    Text(verbatim: "?")
                        .foregroundStyle(Color("TextColor").opacity(0.8))
                        .fontWeight(.light)
                )
                .font(.title)
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                .foregroundStyle(Color("TextColor").gradient)

                VStack(spacing: 10)
                {
                    HStack(alignment: .lastTextBaseline, spacing: 8)
                    {
                        Text("\(AppSettings.balanceGoal)")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color("TextColor"))
                            .opacity(0.8)
                            .fixedSize()
                    
                        Text(verbatim: AppSettings.energyUnit == .kJ ? "kJ" : "kcal")
                            .font(.callout)
                            .fontWeight(.regular)
                            .fontDesign(.rounded)
                            .foregroundStyle(Color("TextColor"))
                            .opacity(0.8)
                    }
                    
                    Slider(value: $balanceSlider, in: 0...2000, step: 50)
                        .onChange(of: balanceSlider)
                        { _, n in
                            AppSettings.balanceGoal = Int(n)
                        }
                        .onAppear
                        {
                            balanceSlider = Double(AppSettings.balanceGoal)
                        }
                        .tint(Color("ConsumedDefault"))
                        .sensoryFeedback(.selection, trigger: balanceSlider)
                }
                
                Text("\(balanceGoalDescription)")
                    .font(.headline)
                    .foregroundStyle(Color("TextColor"))
                    .fontWeight(.regular)
                    .fontDesign(.rounded)
                    .padding(.top, 25)
            }
        }
    }
    
    var balanceGoalDescription: String
    {
        switch AppSettings.weightGoal
        {
            case .lose:
                String(localized: "This deficit equates to a weight loss of \(weightChange7) per week or \(weightChange30) per month.")
            case .gain:
                String(localized: "This surplus equates to a weight gain of \(weightChange7) per week or \(weightChange30) per month.")
        }
    }
    
    var weightChange7: String
    {
        let unit = AppSettings.weightUnit
        let conversionFactor = unit == .kg ? 1.0 : 2.20462
        
        let weightChange = Double(AppSettings.balanceGoal) * 7 / 7700.0 * conversionFactor
            
        return String(format: "%.2f \(unit.rawValue)", weightChange)
    }
    
    var weightChange30: String
    {
        let unit = AppSettings.weightUnit
        let conversionFactor = unit == .kg ? 1.0 : 2.20462
        
        let weightChange = Double(AppSettings.balanceGoal) * 30 / 7700.0 * conversionFactor
            
        return String(format: "%.2f \(unit.rawValue)", weightChange)
    }
}


struct DataSourceView: View
{
    @EnvironmentObject private var AppSettings: Settings
    @Environment(HSlider.self) private var SliderData
    @Environment(\.colorScheme) private var scheme: ColorScheme
        
    @State private var activeSlider = 0.0
    @State private var passiveSlider = 0.0

    var body: some View
    {
        VStack(spacing: 30)
        {
            VStack(spacing: 30)
            {
                (
                    Text("For")
                        .foregroundStyle(Color("TextColor").opacity(0.8))
                        .fontWeight(.light)
                    +
                    Text(verbatim: " ")
                    +
                    Text("burned calories")
                    +
                    Text(", use ...")
                        .foregroundStyle(Color("TextColor").opacity(0.8))
                        .fontWeight(.light)
                )
                .font(.title)
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                .foregroundStyle(Color("TextColor").gradient)
                
                IconPicker(firstIcon: "heart.fill", secondIcon: "pencil.and.list.clipboard", selection: $AppSettings.dataSource.animation(.bouncy))
                    .frame(width: 120, height: 40)
                    .scaleEffect(1.4)
                    .sensoryFeedback(.selection, trigger: AppSettings.dataSource)
                
                Text(AppSettings.dataSource == .apple ? String("Apple Health") : String(localized: "Custom Data"))
                    .font(.title)
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)
                    .animation(.linear, value: AppSettings.dataSource)
                    .foregroundStyle(Color("TextColor"))
            }
            
            if AppSettings.dataSource == .custom
            {
                VStack(spacing: 20)
                {
                    VStack(spacing: 10)
                    {
                        HStack(alignment: .lastTextBaseline, spacing: 8)
                        {
                            Text("Resting Calories")
                                .foregroundStyle(Color("TextColor"))
                            
                            if !AppSettings.isPassiveValid
                            {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(Color.red.gradient)
                                    .offset(y: -1)
                            }
                            
                            Spacer()
                            
                            Text("\(AppSettings.customCalPassive)")
                                .foregroundStyle(Color("TextColor"))
                                .opacity(0.8)
                                .fixedSize()
                        
                            Text(verbatim: AppSettings.energyUnit == .kJ ? "kJ" : "kcal")
                                .font(.callout)
                                .fontWeight(.regular)
                                .fontDesign(.rounded)
                                .foregroundStyle(Color("TextColor"))
                                .opacity(0.8)
                        }
                        .font(.title2)
                        .fontWeight(.semibold)
                        
                        Slider(value: $passiveSlider, in: 1000...4000, step: 50)
                            .onChange(of: passiveSlider)
                            { _, n in
                                AppSettings.customCalPassive = Int(n)
                            }
                            .onAppear
                            {
                                passiveSlider = Double(AppSettings.customCalPassive)
                            }
                            .sensoryFeedback(.selection, trigger: passiveSlider)
                    }
                    
                    VStack(spacing: 10)
                    {
                        HStack(alignment: .lastTextBaseline, spacing: 8)
                        {
                            Text("Active Calories")
                                .foregroundStyle(Color("TextColor"))
                            
                            if !AppSettings.isActiveValid
                            {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(Color.red.gradient)
                                    .offset(y: -1)
                            }
                            
                            Spacer()
                            
                            Text("\(AppSettings.customCalActive)")
                                .foregroundStyle(Color("TextColor"))
                                .opacity(0.8)
                                .fixedSize()
                        
                            Text(verbatim: AppSettings.energyUnit == .kJ ? "kJ" : "kcal")
                                .font(.callout)
                                .fontWeight(.regular)
                                .fontDesign(.rounded)
                                .foregroundStyle(Color("TextColor"))
                                .opacity(0.8)
                        }
                        .font(.title2)
                        .fontWeight(.semibold)
                        
                        Slider(value: $activeSlider, in: 100...2000, step: 50)
                            .onChange(of: activeSlider)
                            { _, n in
                                AppSettings.customCalActive = Int(n)
                            }
                            .onAppear
                            {
                                activeSlider = Double(AppSettings.customCalActive)
                            }
                            .sensoryFeedback(.selection, trigger: activeSlider)
                    }
                }
                .geometryGroup()
                .transition(.slide.combined(with: .opacity))
                .animation(.snappy, value: AppSettings.dataSource)
            }
        }
    }
}

struct MaingoalView: View
{
    @EnvironmentObject private var AppSettings: Settings
    @Environment(\.colorScheme) private var scheme: ColorScheme
    
    var body: some View
    {
        VStack(spacing: 30)
        {
            (
                Text("My")
                    .foregroundStyle(Color("TextColor").opacity(0.8))
                    .fontWeight(.light)
                +
                Text(verbatim: " ")
                +
                Text("goal")
                +
                Text(verbatim: " ")
                +
                Text("is to ...")
                    .foregroundStyle(Color("TextColor").opacity(0.8))
                    .fontWeight(.light)
            )
            .font(.title)
            .fontWeight(.semibold)
            .fontDesign(.rounded)
            .foregroundStyle(Color("TextColor").gradient)
            
            IconPicker(firstIcon: "arrowshape.down.fill", secondIcon: "arrowshape.up.fill", selection: $AppSettings.weightGoal)
                .frame(width: 120, height: 40)
                .scaleEffect(1.4)
                .sensoryFeedback(.selection, trigger: AppSettings.weightGoal)
            
            Text(AppSettings.weightGoal == .lose ? "Lose Weight" : "Gain Weight")
                .font(.title)
                .fontWeight(.semibold)
                .animation(.linear, value: AppSettings.weightGoal)
                .fontDesign(.rounded)
                .foregroundStyle(Color("TextColor"))
        }
    }
}

struct AppleHealthView: View
{
    @EnvironmentObject private var AppSettings: Settings
    
    var body: some View
    {
        VStack(spacing: 16)
        {
            Image("Health")
                .resizable()
                .frame(width: 90, height: 90)
            
            VStack(spacing: -4)
            {
                Text("Allow access to")
                    .font(.title)
                    .fontWeight(.light)
                    .foregroundStyle(Color("TextColor").opacity(0.8))
                
                Text(verbatim: "Apple Health")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color("TextColor").gradient)
            }
            .fontDesign(.rounded)
        }
    }
}

struct WelcomeView: View
{
    @EnvironmentObject private var AppSettings: Settings
        
    @State private var onboardingInterface = HealthInterface(.empty(for: .now))
    
    @State private var welcomeScale: CGFloat = 3.5
    @State private var welcomeAnimating = false
    @State private var welcomeAnimationWorkItem: DispatchWorkItem?
    
    var body: some View
    {
        VStack(spacing: 0)
        {
            CircleBalanceGraph(lineWidth: 20, mode: .now)
                .frame(width: 255, height: 255)
                .overlay
                {
                    VStack(spacing: 0)
                    {
                        Text("\(abs(onboardingInterface.sample.balanceNow))")
                            .font(.system(size: 30))
                            .fontWeight(.semibold)
                            .foregroundColor(Color("TextColor"))
                            .contentTransition(.numericText(value: Double(abs(onboardingInterface.sample.balanceNow))))
                        
                        Text(onboardingInterface.sample.balanceNow > 0 ? String(localized: "Deficit") : onboardingInterface.sample.balanceNow == 0 ? String("") : String(localized: "Surplus"))
                            .font(.subheadline)
                            .fontWeight(.light)
                            .foregroundColor(Color("SecondaryTextColor"))
                            .offset(y: -2)
                    }
                    .opacity(onboardingInterface.sample.balanceNow == 0 ? 0 : 1)
                    .fontDesign(.rounded)
                }
            
            BarBalanceGraph(labels: false)
                .frame(height: 58)
                .padding(.horizontal, 40)
        }
        .scaleEffect(welcomeScale)
        .geometryGroup()
        .environmentObject(AppSettings)
        .environment(onboardingInterface)
        .onAppear
        {
            welcomeScale = 3.5
            onboardingInterface.randomizeHealthData()
            
            startAnimationCycle()
            
            withAnimation(.smooth(duration: 2))
            {
                welcomeScale = 1
            }
        }
        .onDisappear
        {
            stopAnimationCycle()
        }
    }
    
    private func startAnimationCycle()
    {
        welcomeAnimationWorkItem?.cancel()
        welcomeAnimationWorkItem = nil
                
        welcomeAnimating = true
        tickWelcomeAnimation()
    }
    
    private func stopAnimationCycle()
    {
        welcomeAnimating = false
        welcomeAnimationWorkItem?.cancel()
        welcomeAnimationWorkItem = nil
    }
    
    private func tickWelcomeAnimation()
    {
        guard welcomeAnimating else { return }
        
        // prepare delayed refresk
        welcomeAnimationWorkItem = DispatchWorkItem
        {
            guard welcomeAnimating else { return }
            
            withAnimation(.bouncy(duration: 1))
            {
                onboardingInterface.randomizeHealthData()
            }
            completion:
            {
                guard welcomeAnimating else { return }
                
                // restart the animation cycle
                tickWelcomeAnimation()
            }
        }
        
        // Schedule the work item after a delay of 0.5 seconds
        if let workItem = welcomeAnimationWorkItem
        {
            guard welcomeAnimating else { return }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: workItem)
        }
    }
}

struct OnboardingWelcome: View
{
    var body: some View
    {
        HStack(alignment: .bottom, spacing: 16)
        {
            Image(uiImage: UIImage(named: "AppIcon") ?? UIImage())
                .resizable()
                .frame(width: 70, height: 70)
                .clipShape(.rect(cornerRadius: 13))
            
            VStack(alignment: .leading, spacing: -6)
            {
                Text("Welcome to")
                    .font(.title)
                    .fontWeight(.light)
                    .opacity(0.8)
                
                Text(verbatim: "Count.kcal")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(Color("TextColor"))
            .fontDesign(.rounded)
        }
    }
}

struct OnboardingButton: View
{
    @EnvironmentObject private var AppSettings: Settings
    
    @Binding var selection: OnboardingState
    
    @State private var showButton = false
    
    var body: some View
    {
        Button
        {
            if selection == .applehealth
            {
                HKRepository.shared.store.requestAuthorization(toShare: Set(), read: HKRepository.shared.dataTypesToRead)
                { success, error in
                    withAnimation
                    {
                        selection = .maingoal
                    }
                }
                
                return
            }
            
            if let new = OnboardingState(rawValue: selection.rawValue + 1)
            {
                withAnimation
                {
                    selection = new
                }
            }
            else
            {
                withAnimation(.smooth(duration: 4))
                {
                    AppSettings.showWelcome = false
                }
            }
        }
        label:
        {
            Text(OnboardingButtonText[selection.rawValue])
                .font(.title3)
                .fontWeight(.medium)
                .fontDesign(.rounded)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(selection == .balancegoal ? Color("ConsumedDefault") : .blue)
        .padding(.horizontal, 55)
        .overlay(alignment: .top)
        {
            VStack
            {
                HStack(spacing: 8)
                {
                    ForEach(1..<OnboardingState.allCases.count, id: \.self)
                    { i in
                        Circle()
                            .fill(Color("TextColor"))
                            .frame(width: 8, height: 8)
                            .opacity(selection.rawValue >= i ? 1 : 0.25)
                    }
                }
            }
            .offset(y: -20)
        }
        .foregroundStyle(Color("TextColor"))
        .overlay(alignment: .bottom)
        {
            if selection != .welcome
            {
                Button
                {
                    if let new = OnboardingState(rawValue: selection.rawValue - 1)
                    {
                        withAnimation(.bouncy)
                        {
                            selection = new
                        }
                    }
                }
                label:
                {
                    Text("Back")
                        .tint(selection == .balancegoal ? Color("ConsumedDefault").brighten(0.1) : .blue)
                }
                .offset(y: 40)
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

#Preview { PreviewPager }
