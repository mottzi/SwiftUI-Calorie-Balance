import SwiftUI

struct WelcomeView: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @EnvironmentObject private var AppSettings: Settings
    
    @State private var onboardingInterface = HealthInterface(.empty(for: .now))
    
    @State private var welcomeScale: CGFloat = 3.5
    
    var body: some View {
        VStack(spacing: 0) {
            CircleBalanceGraph(lineWidth: 20, mode: .now)
                .frame(width: 255, height: 255)
                .overlay {
                VStack(spacing: 0) {
                    Text("\(abs(onboardingInterface.sample.balanceNow))")
                        .font(.system(size: 30))
                        .fontWeight(.semibold)
                        .foregroundStyle(Color("TextColor"))
                        .contentTransition(.numericText(value: Double(abs(onboardingInterface.sample.balanceNow))))
                    
                    Text(
                        onboardingInterface.sample.balanceNow > 0
                            ? String(localized: "Deficit")
                            : onboardingInterface.sample.balanceNow == 0 ? String("") : String(localized: "Surplus")
                    )
                        .font(.subheadline)
                        .fontWeight(.light)
                        .foregroundStyle(Color("SecondaryTextColor"))
                        .offset(y: -2)
                }
                .opacity(onboardingInterface.sample.balanceNow == 0 ? 0 : 1)
                .fontDesign(.rounded)
            }
            
            BarBalanceGraph(mode: .now, labels: false)
                .frame(height: 58)
                .padding(.horizontal, 40)
        }
        .scaleEffect(welcomeScale)
        .geometryGroup()
        .environmentObject(AppSettings)
        .environment(onboardingInterface)
        .task(id: reduceMotion) { await animateWelcome() }
    }

}

extension WelcomeView {

    /// The view task owns the animation cycle and cancels it when onboarding leaves.
    private func animateWelcome() async {

        onboardingInterface.randomizeHealthData()
        guard !reduceMotion else {
            welcomeScale = 1
            return
        }
        welcomeScale = 3.5
        withAnimation(.smooth(duration: 2)) { welcomeScale = 1 }

        while !Task.isCancelled {
            do { try await Task.sleep(for: .seconds(2)) }
            catch { return }
            withAnimation(.bouncy(duration: 1)) { onboardingInterface.randomizeHealthData() }
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
