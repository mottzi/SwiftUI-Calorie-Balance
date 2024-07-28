import SwiftUI

enum OnboardingState: Int, RawRepresentable, CaseIterable
{
    case welcome = 0
    case applehealth = 1
    case maingoal = 2
    case datasource = 3
    case balancegoal = 4
}

let ButtonText =
[
    "Start",
    "Allow",
    "Next",
    "Next",
    "Finish",
]

struct Onboarding: View
{
    @State private var selection: OnboardingState = .welcome
    @State private var showButton = false
    
    @ViewBuilder
    var Pages: some View
    {
        Group
        {
            switch selection
            {
                case .welcome:
                    WelcomeView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .padding(.top, -60)
                        .padding(.horizontal, -40)
                        .offset(y: -20)
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
        .padding(.top, 60)
        .transition(.scale(scale: 0.1).combined(with: .opacity))
    }
    
    var body: some View
    {
        VStack(spacing: 0)
        {
            WelcomeIconText()
            
            Spacer()
            
            Pages
            
            Spacer()
            
            ContinueButton(selection: $selection)
                .offset(y: showButton ? 0 : 300)
                .onAppear
                {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6)
                    {
                        withAnimation(.smooth(duration: 1.5))
                        {
                            showButton = true
                        }
                    }
                }
        }
        .onAppear
        {
            selection = .welcome
        }
        .padding(.vertical, 60)
    }
}

struct OnboardingCenterView: View
{
    @Binding var selection: OnboardingState
    
    var body: some View
    {
        TabView(selection: $selection)
        {
            Group
            {
                WelcomeView()
                    .tag(OnboardingState.welcome)
                
                AppleHealthView()
                    .tag(OnboardingState.applehealth)
                
                MaingoalView()
                    .tag(OnboardingState.maingoal)
                
                DataSourceView()
                    .tag(OnboardingState.datasource)
                
                BalanceGoalView()
                    .tag(OnboardingState.balancegoal)
            }
            .padding(.horizontal, 30)
            
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .scrollDisabled(true)
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
                Text("What is your \(String(localized: AppSettings.weightGoal == .lose ? "Calorie Deficit" : "Calorie Surplus")) goal?")
                    .font(.title)
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)
                    .foregroundStyle(Color("TextColor"))

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
                        .sensoryFeedback(.selection, trigger: balanceSlider)
                }
//                .padding(.top, 40)
                
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
                "This deficit equates to a weight loss of \(weightChange7) per week or \(weightChange30) per month."
            case .gain:
                "This surplus equates to a weight gain of \(weightChange7) per week or \(weightChange30) per month."
        }
    }
    
    var weightChange7: String
    {
        let weightChangeInKg = Double(AppSettings.balanceGoal) * 7 / 7700.0
            
        return String(format: "%.2f kg", weightChangeInKg)
    }
    
    var weightChange30: String
    {
        let weightChangeInKg = Double(AppSettings.balanceGoal) * 30 / 7700.0
            
        return String(format: "%.2f kg", weightChangeInKg)
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
                        .foregroundStyle(Color("TextColor").opacity(0.6))
                    +
                    Text(verbatim: " ")
                    +
                    Text("burned calories")
                    +
                    Text(", use...")
                        .foregroundStyle(Color("TextColor").opacity(0.6))
                )
                .font(.title)
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                .foregroundStyle(Color("TextColor"))
                
                IconPicker(firstIcon: "heart.fill", secondIcon: "pencil.and.list.clipboard", selection: $AppSettings.dataSource.animation(.bouncy))
                    .frame(width: 120, height: 40)
                    .scaleEffect(1.4)
                    .sensoryFeedback(.selection, trigger: AppSettings.dataSource)
                
                Text(AppSettings.dataSource == .apple ? "Apple Health" : "Custom Data")
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
                        
                        Slider(value: $passiveSlider, in: 0...4000, step: 50 )
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
                        
                        Slider(value: $activeSlider, in: 0...4000, step: 50 )
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
//                .onAppear
//                {
//                    Task
//                    {
//                        await AppSettings.updateShow()
//                    }
//                }
//                .onChange(of: AppSettings.dataSource)
//                {
//                    Task
//                    {
//                        await AppSettings.updateShow()
//                    }
//                }
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
            Text("My goal is to...")
                .font(.title)
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                .foregroundStyle(Color("TextColor"))
                .lineLimit(2, reservesSpace: true)
            
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
                    .opacity(0.8)
                
                Text(verbatim: "Apple Health")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(Color("TextColor"))
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
            
            withAnimation(.bouncy(duration: 0.6))
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

struct WelcomeIconText: View
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

struct ContinueButton: View
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
            Text(ButtonText[selection.rawValue])
                .font(.title3)
                .fontWeight(.medium)
                .fontDesign(.rounded)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
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
                }
                .offset(y: 40)
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

#Preview { PreviewPager }
