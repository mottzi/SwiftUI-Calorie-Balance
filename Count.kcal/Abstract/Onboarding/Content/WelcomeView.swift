import SwiftUI

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

#Preview
{
    NavigationView
    {
        ZStack
        {
            Settings.shared.AppBackground
                .ignoresSafeArea(.all)
            
            Pager(lb: 5, tb: 1)
        }
    }
    .environmentObject(Settings.shared)
    .environment(WeightDataViewModel())
    .environment(Streak())
}
