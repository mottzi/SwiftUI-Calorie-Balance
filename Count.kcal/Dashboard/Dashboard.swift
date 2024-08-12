import SwiftUI
import WidgetKit

struct Dashboard: View
{
    @EnvironmentObject private var AppSettings: Settings
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(HealthInterface.self) private var DataViewModel

    @Binding var todayPageMode: PagerSelection?
    
    var sTitle: String 
    {
        if DataViewModel.isTodayPage
        {
            if let todayPageMode, todayPageMode == .second
            {
                return String(localized: "Midnight")
            }
            else
            {
                return String(localized: "Now, \((DataViewModel.CacheDate ?? .now).shortTime)")
            }
        }
        
        return String("")
    }
    
    var body: some View
    {
        VStack(spacing: 20)
        {
            Card("Calories", secondaryTitle: sTitle)
            {
                VStack
                {
                    if !DataViewModel.isTodayPage
                    {
                        CaloriesCard()
                    }
                    else
                    {
                        CaloriesMidnightCard(todayPageMode: $todayPageMode)
                    }
                }
            }
            .overlay(alignment: .init(horizontal: .center, vertical: .top))
            {
                if DataViewModel.isTodayPage
                {
                    HStack
                    {
                        Circle()
                            .fill(Color("TextColor"))
                            .frame(width: 8)
                            .opacity(todayPageMode == .first ? 0.8 : 0.2)
                        
                        Circle()
                            .fill(Color("TextColor"))
                            .frame(width: 8)
                            .opacity(todayPageMode == .second ? 0.8 : 0.2)
                    }
                    .offset(y: dynamicType <= DynamicTypeSize.xxLarge ? 5 : 10)
                }
            }
            .contentShape(.rect)
            .onTapGesture 
            {
                withAnimation(.snappy)
                {
                    if (todayPageMode ?? .first) == .first
                    {
                        todayPageMode = .second
                    }
                    else
                    {
                        todayPageMode = .first
                    }
                }
            }

            MacroCard()
            
            Card("Steps")
            {
                ReachableView("Steps", context: .app, consumedValue: DataViewModel.sample.steps, goalValue: AppSettings.stepsGoal, unit: "", color: AppSettings.burnedColor, graphHeight: 10)
                    .padding(.horizontal, 11)
//                    .padding(.top, 4)
                    .padding(.bottom, 6)
            }
        }
    }
    
}

#Preview
{
    NavigationView
    {
        ZStack
        {
            Settings.shared.AppBackground.ignoresSafeArea(.all)
            
            Pager(lb: 6, tb: 1)
                .environmentObject(Settings.shared)
                .environment(WeightDataViewModel())
                .environment(Streak())
        }
    }
}
