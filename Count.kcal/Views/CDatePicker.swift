import SwiftUI

/// Calendar that browses months without extending the dashboard's swipe range.
struct CDatePicker: View {

    @EnvironmentObject private var AppSettings: Settings

    @Environment(\.colorScheme) private var scheme: ColorScheme

    @Binding var currentMonth: Date

    @State private var days: [HealthInterface] = []

    let navigation: DayPager
    let sceneActive: Bool
    let refreshRevision: Int
    let selectDay: (Date) -> Void
    
    var body: some View {
        let columns = Array(repeating: GridItem(.flexible()), count: 7)
        let width = 43.0
        let spacing = 2.0
            
        VStack(spacing: 8) {
            HStack(spacing: 20) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(verbatim: "\(currentMonth.monthString)")
                        .fontWeight(.medium)
                        .dynamicTypeSize(...DynamicTypeSize.xxLarge)

                    Text(verbatim: "\(currentMonth.year)")
                        .font(.caption)
                        .fontWeight(.regular)
                        .foregroundColor(Color("SecondaryTextColor"))
                        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                }
                .foregroundColor(Color("TextColor"))
                
                Spacer()
                
                Button {
                    currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth)!
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                        .foregroundColor(Color("TextColor"))
                        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                }
                .padding(.trailing, 12)
                
                Button {
                    currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth)!
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                        .foregroundColor(Color("TextColor"))
                        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                }
            }
            .padding(.horizontal, 5)
            .padding(.trailing, 4)
            
            LazyVGrid(columns: columns, spacing: spacing + 1) {
                ForEach(0..<weekdays.count, id: \.self) { index in
                    Text(verbatim: weekdays[index])
                        .font(.callout)
                        .fontWeight(.medium)
                        .fontDesign(.rounded)
                        .padding(.bottom, 6)
                        .foregroundStyle(Color("TextColor"))
                        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                }
                
                ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                    Button {
                        selectDay(day.id)
                    } label: {
                        CalendarDayLabel(day: day, isCurrentMonth: day.id.isSameMonth(as: currentMonth))
                            .offset(y: -1)
                            .frame(width: width, height: width)
                            .background { dayBackground(day.id, index: index, count: days.count) }
                    }
                    .buttonStyle(.plain)
                }
            }
            .transaction { $0.animation = nil }
        }
        .frame(width: width * 7 + spacing * 6)
        .padding(.bottom, 20)
        .padding(.top, 0)
        .foregroundStyle(Color("TextColor"))
        .fontDesign(.rounded)
        .geometryGroup()
        .onChange(of: navigation.selectedDay) { _, day in
            guard let first = days.first?.id, let last = days.last?.id else { return }
            if day < first || day > last {
                currentMonth = day
            }
        }
        .task(id: calendarRefreshKey) {
            let cells = navigation.calendarPages(for: currentMonth)
            days = cells
            guard sceneActive else { return }
            let sharedDays = Set(navigation.weekPages.map(\.id) + [navigation.selectedDay])
            let pending = cells.filter { !sharedDays.contains($0.id) }
            // limit concurrent requests for calendar days outside the visible summaries
            for start in stride(from: 0, to: pending.count, by: 4) {
                guard !Task.isCancelled else { return }
                await withTaskGroup(of: Void.self) { group in
                    for cell in pending[start..<min(start + 4, pending.count)] {
                        group.addTask {
                            guard !Task.isCancelled else { return }
                            await cell.updateMetrics()
                        }
                    }
                }
            }
        }

    }

}

extension CDatePicker {

    private var calendarRefreshKey: CalendarRefreshKey {
        CalendarRefreshKey(
            month: currentMonth,
            active: sceneActive,
            source: AppSettings.dataSource.rawValue,
            unit: AppSettings.energyUnit.rawValue,
            activeGoal: AppSettings.customCalActive,
            passiveGoal: AppSettings.customCalPassive,
            revision: refreshRevision
        )
    }

    func isDaySelected(_ d: Date) -> Bool {
        Calendar.current.startOfDay(for: d) == navigation.selectedDay
    }

    var weekdays: [String] {
        Calendar.current.shortWeekdaySymbolsLocalized
    }
    
    private func dayBackground(_ date: Date, index: Int, count: Int) -> some View {
        let selected = isDaySelected(date)
        return UnevenRoundedRectangle(
            topLeadingRadius: index == 0 ? 10 : 0,
            bottomLeadingRadius: index == count - 7 ? 10 : 0,
            bottomTrailingRadius: index == count - 1 ? 10 : 0,
            topTrailingRadius: index == 6 ? 10 : 0,
            style: .circular
        )
        .fill(getDayCellBackground(d: date))
        .stroke(Color("TextColor").opacity(selected ? 1 : 0), style: StrokeStyle(lineWidth: selected ? 2 : 0))
        .brightness(level: getDayCellBrightness(d: date))
        .transaction { $0.animation = nil }
    }
    
    func getDayCellBrightness(d: Date) -> BrightnessLevel {
        if d.isToday {
            return .primary
        }
        
        return .none
    }
    
    func getDayCellBackground(d: Date) -> Color {
        if Calendar.current.isDate(d, equalTo: currentMonth, toGranularity: .month) {
            return AppSettings.CardBackground
        }
        
        return Color.clear
    }

}

/// One date and its balance indicator, updated only by that day's health snapshot.
private struct CalendarDayLabel: View {

    @EnvironmentObject private var settings: Settings

    @Environment(\.colorScheme) private var scheme

    let day: HealthInterface
    let isCurrentMonth: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text(verbatim: "\(day.id.day)")
                .font(.callout)
                .opacity(isCurrentMonth ? 1 : 0.7)
                .fontWeight(isCurrentMonth ? .semibold : .medium)
                .dynamicTypeSize(...DynamicTypeSize.xxLarge)

            Circle()
                .fill(balanceColor.gradient)
                .frame(width: 7)
                .brightness(level: scheme == .dark ? .primary : .none)
        }
    }

    private var balanceColor: Color {
        guard day.sample.consumed > 0 else { return settings.getGraphEmptyColor(scheme).brighten(-0.1) }
        if day.sample.balanceNow > 0 { return settings.burnedColor }
        if day.sample.balanceNow < 0 { return settings.consumedColor }
        return settings.getGraphEmptyColor(scheme).brighten(-0.1)
    }

}

/// Inputs that affect visible calendar dots.
private struct CalendarRefreshKey: Hashable {

    let month: Date
    let active: Bool
    let source: Int
    let unit: String
    let activeGoal: Int
    let passiveGoal: Int
    let revision: Int

}

#Preview {
    PreviewPager
}
