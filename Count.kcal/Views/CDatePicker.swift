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
                
                ForEach(days) { d in
                    CalendarDayLabel(day: d, isCurrentMonth: d.id.isSameMonth(as: currentMonth))
                    .offset(y: -1)
                    .frame(width: width, height: width)
                    .background {
                        Group {
                            if days.first == d {
                                UnevenRoundedRectangle(
                                    topLeadingRadius: 10,
                                    bottomLeadingRadius: 0,
                                    bottomTrailingRadius: 0,
                                    topTrailingRadius: 0,
                                    style: .circular
                                )
                                    .fill(getDayCellBackground(d: d.id))
                                    .stroke(
                                        Color("TextColor").opacity(getDayCellStrokeOpacity(d: d.id)),
                                        style: getDayCellStrokeStyle(d: d.id)
                                    )
                                    .brightness(level: getDayCellBrightness(d: d.id))
                            } else if days.last == d {
                                UnevenRoundedRectangle(
                                    topLeadingRadius: 0,
                                    bottomLeadingRadius: 0,
                                    bottomTrailingRadius: 10,
                                    topTrailingRadius: 0,
                                    style: .circular
                                )
                                    .fill(getDayCellBackground(d: d.id))
                                    .stroke(
                                        Color("TextColor").opacity(getDayCellStrokeOpacity(d: d.id)),
                                        style: getDayCellStrokeStyle(d: d.id)
                                    )
                                    .brightness(level: getDayCellBrightness(d: d.id))
                            } else if days.firstIndex(of: d) == 6 {
                                UnevenRoundedRectangle(
                                    topLeadingRadius: 0,
                                    bottomLeadingRadius: 0,
                                    bottomTrailingRadius: 0,
                                    topTrailingRadius: 10,
                                    style: .circular
                                )
                                    .fill(getDayCellBackground(d: d.id))
                                    .stroke(
                                        Color("TextColor").opacity(getDayCellStrokeOpacity(d: d.id)),
                                        style: getDayCellStrokeStyle(d: d.id)
                                    )
                                    .brightness(level: getDayCellBrightness(d: d.id))
                            } else if days.firstIndex(of: d) == days.count - 7 {
                                UnevenRoundedRectangle(
                                    topLeadingRadius: 0,
                                    bottomLeadingRadius: 10,
                                    bottomTrailingRadius: 0,
                                    topTrailingRadius: 0,
                                    style: .circular
                                )
                                    .fill(getDayCellBackground(d: d.id))
                                    .stroke(
                                        Color("TextColor").opacity(getDayCellStrokeOpacity(d: d.id)),
                                        style: getDayCellStrokeStyle(d: d.id)
                                    )
                                    .brightness(level: getDayCellBrightness(d: d.id))
                            } else {
                                Rectangle()
                                    .fill(getDayCellBackground(d: d.id))
                                    .stroke(
                                        Color("TextColor").opacity(getDayCellStrokeOpacity(d: d.id)),
                                        style: getDayCellStrokeStyle(d: d.id)
                                    )
                                    .brightness(level: getDayCellBrightness(d: d.id))
                            }
                        }
                        .transaction { transaction in
                            transaction.animation = nil
                        }
                    }
                    .contentShape(.rect)
                    .onTapGesture {
                        selectDay(d.id)
                    }
                   
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
            for cell in cells {
                guard !Task.isCancelled else { return }
                guard !sharedDays.contains(cell.id) else { continue }
                await cell.updateMetrics()
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
        return Calendar.current.shortWeekdaySymbolsLocalized
    }
    
    func getDayCellStrokeStyle(d: Date) -> StrokeStyle {
        if isDaySelected(d) {
            return StrokeStyle(lineWidth: 2)
        }
        
        return StrokeStyle(lineWidth: 0)
    }
    
    func getDayCellStrokeOpacity(d: Date) -> Double {
        if isDaySelected(d) {
            return 1
        }
        
        return 0
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
