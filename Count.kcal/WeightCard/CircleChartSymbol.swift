import SwiftUI

struct CircleChartSymbol: View 
{
    @EnvironmentObject private var AppSettings: Settings
    @Environment(WeightDataViewModel.self) private var WeightViewModel
    
    let index: Int
    let page: WeightPage
    
    var body: some View
    {
        if page == .weekly
        {
            if(index == WeightViewModel.validData(.weekly).count - 1)
            {
                Circle()
                    .fill(Color("SecondaryTextColor1"))
                    .frame(width: 12)
                    .overlay
                    {
                        Circle()
                            .fill(AppSettings.CardBackground)
                            .frame(width: 6)
                    }
            }
            else
            {
                Circle()
                    .fill(Color("SecondaryTextColor"))
                    .frame(width: 8)
                    .overlay
                    {
                        Circle()
                            .fill(AppSettings.CardBackground)
                            .frame(width: 4)
                    }
            }
        }
        else if page == .monthly
        {
            if(index == WeightViewModel.validData(.monthly).count - 1)
            {
                Circle()
                    .fill(Color("SecondaryTextColor1"))
                    .frame(width: 12)
                    .overlay
                    {
                        Circle()
                            .fill(AppSettings.CardBackground)
                            .frame(width: 6)
                    }
            }
            else
            {
                Circle()
                    .fill(Color("SecondaryTextColor"))
                    .frame(width: 6)
                    .overlay
                    {
                        Circle()
                            .fill(AppSettings.CardBackground)
                            .frame(width: 3)
                    }
            }
        }
    }
}
