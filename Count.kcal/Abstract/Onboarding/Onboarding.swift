import SwiftUI

/// Setup flow for Health access, goals, and the energy data source.
struct Onboarding: View {
    @State private var selection: OnboardingState = .welcome
    @State private var showButton = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                if selection == .welcome {
                    OnboardingWelcome()
                        .transition(.opacity.combined(with: .offset(y: -200)))
                }

                OnboardingContent(selection: selection)
                    .transition(.opacity.combined(with: .scale(scale: 0.1)))

                OnboardingButton(selection: $selection)
                    .offset(y: showButton ? 0 : 300)
            }
            .padding(.top, geometry.size.height < 700 ? 30 : 60)
            .padding(.bottom, 60)
        }
        .task {
            // stop the delayed entrance if the setup view leaves the hierarchy
            do { try await Task.sleep(for: .seconds(1.6)) }
            catch { return }
            withAnimation(.smooth(duration: 1.5)) {
                showButton = true
            }
        }
    }
}

struct OnboardingContent: View {
    let selection: OnboardingState

    var body: some View {
        Group {
            switch selection {
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

enum OnboardingState: Int, CaseIterable {
    case welcome = 0
    case applehealth = 1
    case maingoal = 2
    case datasource = 3
    case balancegoal = 4
    
    var buttonText: String {
        switch self {
            case .welcome: String(localized: "Start")
            case .applehealth: String(localized: "Allow")
            case .maingoal: String(localized: "Next")
            case .datasource: String(localized: "Next")
            case .balancegoal: String(localized: "Finish")
        }
    }
}

#Preview { PreviewPager }
