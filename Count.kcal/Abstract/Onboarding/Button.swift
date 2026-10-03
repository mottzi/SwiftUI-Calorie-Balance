import SwiftUI

struct OnboardingButton: View {

    @Environment(\.dynamicTypeSize) private var dynamicType
    @EnvironmentObject private var AppSettings: Settings
    
    @Binding var selection: OnboardingState
    
    var body: some View {
        Group {
            if dynamicType.isAccessibilitySize {
                VStack(spacing: 12) {
                    advanceButton
                    progressDots
                    if selection != .welcome { backButton }
                }
                .padding(.horizontal, 24)
            } else {
                advanceButton
                    .padding(.horizontal, 55)
                    .overlay(alignment: .top) {
                        progressDots.offset(y: -20)
                    }
                    .overlay(alignment: .bottom) {
                        if selection != .welcome {
                            backButton.offset(y: 40)
                        }
                    }
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }

    private var advanceButton: some View {
        Button {
            if selection == .applehealth {
                Task { @MainActor in
                    _ = await HealthRepository.shared.requestPermission()
                    // keep a later navigation choice if permission completed after the user moved back
                    guard selection == .applehealth else { return }
                    withAnimation {
                        selection = .maingoal
                    }
                }
                
                return
            }
            
            if let new = OnboardingState(rawValue: selection.rawValue + 1) {
                withAnimation {
                    selection = new
                }
            } else {
                withAnimation(.smooth(duration: 4)) {
                    AppSettings.showWelcome = false
                }
            }
        } label: {
            Text(selection.buttonText)
                .font(.title3)
                .fontWeight(.medium)
                .fontDesign(.rounded)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(selection == .balancegoal ? Color("ConsumedDefault") : .blue)
        .foregroundStyle(Color("TextColor"))
    }

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(1..<OnboardingState.allCases.count, id: \.self) { i in
                Circle()
                    .fill(Color("TextColor"))
                    .frame(width: 8, height: 8)
                    .opacity(selection.rawValue >= i ? 1 : 0.25)
            }
        }
    }

    private var backButton: some View {
        Button {
            if let new = OnboardingState(rawValue: selection.rawValue - 1) {
                withAnimation(.bouncy) {
                    selection = new
                }
            }
        } label: {
            Text("Back")
                .tint(selection == .balancegoal ? Color("ConsumedDefault").brighten(0.1) : .blue)
        }
    }

}

#Preview {
    NavigationView {
        ZStack {
            Settings.shared.AppBackground
                .ignoresSafeArea(.all)
            
            Pager(lb: 5, tb: 1)
        }
    }
    .environmentObject(Settings.shared)
    .environment(WeightHistory())
    .environment(Streak())
}
