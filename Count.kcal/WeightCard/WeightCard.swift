import SwiftUI
import Charts

struct WeightCard: View
{
    @EnvironmentObject private var AppSettings: Settings

    @State private var pageSelection: PagerSelection? = .first
    
    var body: some View
    {
        VStack(spacing: 0)
        {
            Card("Weight") 
            {
                VStack(spacing: 0)
                {
                    WeightTopBar(pageSelection: $pageSelection)
                        .padding(.top, 4)
                    
                    ScrollView(.horizontal)
                    {
                        HStack(spacing: 0)
                        {
                            WeeklyChart()
                                .id(PagerSelection.first)
                                .containerRelativeFrame(.horizontal)
                            
                            MonthlyChart()
                                .id(PagerSelection.second)
                                .containerRelativeFrame(.horizontal)
                        }
                        .frame(height: 130)
                        .scrollTargetLayout()
                    }
                    .scrollPosition(id: $pageSelection)
                    .scrollTargetBehavior(.paging)
                    .scrollIndicators(.hidden)
                    .animation(.snappy, value: pageSelection)
                    .padding(.bottom, 2)
                }
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
