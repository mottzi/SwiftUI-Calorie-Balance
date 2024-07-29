import SwiftUI

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
            Text(selection.buttonText)
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
