import SwiftUI

/// Swipeable Now and Midnight graphs with one persistent mode selection.
struct CaloriesMidnightCard: View {

    @Binding var todayPageMode: PagerSelection
    
    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                CaloriesCard()
                    .padding(16)
                    .id(PagerSelection.first)
                    .containerRelativeFrame(.horizontal)

                PrognosisCard()
                    .padding(16)
                    .id(PagerSelection.second)
                    .containerRelativeFrame(.horizontal)
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: Binding(
            get: { todayPageMode },
            set: { if let mode = $0 { todayPageMode = mode } }
        ))
        .initialModeAnchor(todayPageMode)
    }

}

extension View {

    @ViewBuilder
    /// Restores the selected mode when SwiftUI recreates the lazy Today card.
    fileprivate func initialModeAnchor(_ mode: PagerSelection) -> some View {
        if #available(iOS 18, *) {
            defaultScrollAnchor(mode == .second ? .trailing : .leading, for: .initialOffset)
        } else {
            defaultScrollAnchor(mode == .second ? .trailing : .leading)
        }
    }

}

#Preview {
    NavigationView {
        ZStack {
            Settings.shared.AppBackground.ignoresSafeArea(.all)
            
            Pager(lb: 6, tb: 1)
                .environmentObject(Settings.shared)
                .environment(WeightDataViewModel())
        }
    }
}
