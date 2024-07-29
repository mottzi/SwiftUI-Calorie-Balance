import SwiftUI

enum OnboardingState: Int, CaseIterable
{
    case welcome = 0
    case applehealth = 1
    case maingoal = 2
    case datasource = 3
    case balancegoal = 4
    
    var buttonText: String
    {
        switch self 
        {
            case .welcome: String(localized: "Start")
            case .applehealth: String(localized: "Allow")
            case .maingoal: String(localized: "Next")
            case .datasource: String(localized: "Next")
            case .balancegoal: String(localized: "Finish")
        }
    }
}

struct Onboarding: View
{
    @EnvironmentObject private var AppSettings: Settings

    @State private var selection: OnboardingState = .welcome
    @State private var showButton = false
    
    var smallScreen: Bool { UIScreen.main.bounds.height < 700 }
    
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
                .transition(.opacity.combined(with: .scale(scale: 0.1)))
                        
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
                case .welcome:
                    WelcomeView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .padding(.top, -30)
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
        .padding(.top, 30)
    }
}

#Preview { PreviewPager }
