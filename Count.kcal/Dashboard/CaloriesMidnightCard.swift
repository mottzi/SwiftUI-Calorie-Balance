import SwiftUI

private struct MyTransactionKey: TransactionKey 
{
    static let defaultValue = false
}

extension Transaction 
{
    var scrollToToday: Bool 
    {
        get { self[MyTransactionKey.self] }
        set { self[MyTransactionKey.self] = newValue }
    }
}

struct CaloriesMidnightCard: View
{
    @EnvironmentObject private var AppSettings: Settings
    @Environment(HealthInterface.self) private var DataViewModel
    
    @Binding var todayPageMode: PagerSelection?
    
    var body: some View
    {
        ScrollView(.horizontal)
        {
            HStack(spacing: 0)
            {
                CaloriesCard()
                    .id(PagerSelection.first)
                    .containerRelativeFrame(.horizontal)

                PrognosisCard()
                    .id(PagerSelection.second)
                    .containerRelativeFrame(.horizontal)
            }
            .scrollTargetLayout()
        }
//        .scrollDisabled(true)
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $todayPageMode)
        .transaction 
        {
            if $0.scrollToToday
            {
                $0.animation = .none
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
        }
    }
}

