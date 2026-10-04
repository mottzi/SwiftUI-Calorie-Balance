import SwiftUI

/// Reads the selected date independently of the other toolbar controls.
struct SelectedDateToolbarLabel: View {

    let navigation: DayPager
    let controlsDisabled: Bool

    var body: some View {
        #if DEBUG
        Button(action: randomizeSelectedDay) {
            dateText
        }
        .buttonStyle(.plain)
        .accessibilityHint("Randomize this day's health data")
        .disabled(controlsDisabled)
        #else
        dateText
        #endif
    }

    private var dateText: some View {
        Text(navigation.page(for: navigation.selectedDay)?.id.relative ?? "")
            .fontWeight(.semibold)
            .fontDesign(.rounded)
            .foregroundStyle(Color("TextColor"))
            .lineLimit(1)
            // Keep the date from compressing to a symbol-sized item.
            .fixedSize(horizontal: true, vertical: false)
            .transaction { transaction in
                transaction.animation = nil
            }
    }

    #if DEBUG
    private func randomizeSelectedDay() {
        withAnimation(.snappy) {
            navigation.page(for: navigation.selectedDay)?.randomizeHealthData()
        }
    }
    #endif

}
