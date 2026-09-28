import SwiftUI
import Charts

/// Weight history with weekly and monthly chart pages.
struct WeightCard: View {


    @State private var pageSelection: PagerSelection? = .first
    
    var body: some View {
        VStack(spacing: 0) {
            Card("Weight", innerPadding: 0) {
                VStack(spacing: 0) {
                    WeightTopBar(pageSelection: $pageSelection)
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                    
                    ScrollView(.horizontal) {
                        HStack(spacing: 0) {
                            WeeklyChart()
                                .padding(.horizontal, 16)
                                .id(PagerSelection.first)
                                .containerRelativeFrame(.horizontal)
                            
                            MonthlyChart()
                                .padding(.horizontal, 16)
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
                    .padding(.bottom, 18)
                }
            }
        }
    }

}

#Preview {
    NavigationView {
        ZStack {
            Settings.shared.AppBackground.ignoresSafeArea(.all)
            
            Pager(lb: 6, tb: 1)
                .environmentObject(Settings.shared)                
                .environment(WeightHistory())
                .environment(Streak())
        }
    }
}
