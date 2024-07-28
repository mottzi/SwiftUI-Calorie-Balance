import SwiftUI

struct DayCell: Identifiable, Hashable
{
    let id = UUID().uuidString
    let date: Date
    let vm: HealthInterface
}

struct CDatePicker: View
{
    @EnvironmentObject private var AppSettings: Settings

    @Environment(\.colorScheme) private var scheme: ColorScheme

    @Binding var Pages: [HealthInterface]
    @Binding var selectedPage: HealthInterface?
    
    @Binding var ignoreChanges: Bool
    @Binding var calendarMode: CalendarModes
    @Binding var currentMonth: Date
    
    @State private var days: [DayCell] = []
    
    func findPage(for date: Date) -> HealthInterface?
    {
        Pages.first { $0.sample.date.isSameDay(as: date) }
    }
    
    func isDaySelected(_ d: Date) -> Bool
    {
        if let selectedPage, d.isSameDay(as: selectedPage.sample.date)
        {
            return true
        }
        
        return false
    }
        
    var weekdays: [String]
    {
        return Calendar.current.shortWeekdaySymbolsLocalized
    }
    
    func getDayCellStrokeStyle(d: Date) -> StrokeStyle
    {
        if isDaySelected(d)
        {
            return StrokeStyle(lineWidth: 2)
        }
        
        return StrokeStyle(lineWidth: 0)
    }
    
    func getDayCellStrokeOpacity(d: Date) -> Double
    {
        if isDaySelected(d)
        {
            return 1
        }
        
        return 0
    }
    
    func getDayCellBrightness(d: Date) -> BrightnessLevel
    {
        if d.isToday
        {
            return .primary
        }
        
        return .none
    }
    
    func getDayCellBackground(d: Date) -> Color
    {
        if Calendar.current.isDate(d, equalTo: currentMonth, toGranularity: .month)
        {
            return AppSettings.CardBackground
        }
        
        return Color.clear
    }
    
    var body: some View
    {
        let columns = Array(repeating: GridItem(.flexible()), count: 7)
        let width = 43.0
        let spacing = 2.0
            
        VStack(spacing: 8)
        {
            HStack(spacing: 20)
            {
                HStack(alignment: .lastTextBaseline, spacing: 8)
                {
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
                
                Button
                {
                    currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth)!
                }
                label:
                {
                    Image(systemName: "chevron.left")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                        .foregroundColor(Color("TextColor"))
                        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                }
                .padding(.trailing, 12)
                
                Button
                {
                    currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth)!
                }
                label:
                {
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
            
            LazyVGrid(columns: columns, spacing: spacing + 1)
            {
                ForEach(weekdays, id: \.self)
                { day in
                    Text(verbatim: day)
                        .font(.callout)
                        .fontWeight(.medium)
                        .fontDesign(.rounded)
                        .padding(.bottom, 6)
                        .foregroundStyle(Color("TextColor"))
                        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                }
                
                ForEach(days, id: \.self)
                { d in
                    VStack(spacing: 2)
                    {
                        Text(verbatim: "\(d.date.day)")
                            .font(.callout)
                            .opacity(d.date.isSameMonth(as: currentMonth) ? 1 : 0.7)
                            .fontWeight(d.date.isSameMonth(as: currentMonth) ? .semibold : .medium)
                            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                        
                        Circle()
                            .fill(d.vm.sample.balanceNow > 0 && d.vm.sample.consumed > 0 ? AppSettings.burnedColor.gradient : d.vm.sample.balanceNow < 0 && d.vm.sample.consumed > 0 ? AppSettings.consumedColor.gradient : AppSettings.getGraphEmptyColor(scheme).brighten(-0.1).gradient)
                            .frame(width: 7)
                            .brightness(level: scheme == .dark ? .primary : .none)
                    }
                    .offset(y: -1)
                    .frame(width: width, height: width)
                    .background
                    {
                        Group
                        {
                            if days.first! == d
                            {
                                UnevenRoundedRectangle(topLeadingRadius: 10, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 0, style: .circular)
                                    .fill(getDayCellBackground(d: d.date))
                                    .stroke(Color("TextColor").opacity(getDayCellStrokeOpacity(d: d.date)), style: getDayCellStrokeStyle(d: d.date))
                                    .brightness(level: getDayCellBrightness(d: d.date))
                            }
                            else if days.last! == d
                            {
                                UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 10, topTrailingRadius: 0, style: .circular)
                                    .fill(getDayCellBackground(d: d.date))
                                    .stroke(Color("TextColor").opacity(getDayCellStrokeOpacity(d: d.date)), style: getDayCellStrokeStyle(d: d.date))
                                    .brightness(level: getDayCellBrightness(d: d.date))
                            }
                            else if days.firstIndex(of: d) == 6
                            {
                                UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 10, style: .circular)
                                    .fill(getDayCellBackground(d: d.date))
                                    .stroke(Color("TextColor").opacity(getDayCellStrokeOpacity(d: d.date)), style: getDayCellStrokeStyle(d: d.date))
                                    .brightness(level: getDayCellBrightness(d: d.date))
                            }
                            else if days.firstIndex(of: d) == days.count - 7
                            {
                                UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 10, bottomTrailingRadius: 0, topTrailingRadius: 0, style: .circular)
                                    .fill(getDayCellBackground(d: d.date))
                                    .stroke(Color("TextColor").opacity(getDayCellStrokeOpacity(d: d.date)), style: getDayCellStrokeStyle(d: d.date))
                                    .brightness(level: getDayCellBrightness(d: d.date))
                            }
                            else
                            {
                                Rectangle()
                                    .fill(getDayCellBackground(d: d.date))
                                    .stroke(Color("TextColor").opacity(getDayCellStrokeOpacity(d: d.date)), style: getDayCellStrokeStyle(d: d.date))
                                    .brightness(level: getDayCellBrightness(d: d.date))
                            }
                        }
                        .transaction { transaction in
                            transaction.animation = nil
                        }
                    }
                    .contentShape(.rect)
                    .onTapGesture
                    {
                        ignoreChanges = true

                        if let page = findPage(for: d.date)
                        {
                            withAnimation(.snappy)
                            {
                                selectedPage = page
                            }
                        }
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
        .onChange(of: selectedPage)
        { o, n in
            guard let n else { return }
            
            if n.sample.date < days.first!.date
            {
                currentMonth = n.sample.date
            }
            else if n.sample.date > days.last!.date.tomorrow
            {
                currentMonth = n.sample.date
            }
        }
        .onChange(of: currentMonth, initial: true)
        { oldValue, newValue in
            let firstDay = Calendar.current.date(from: DateComponents(year: newValue.year, month: newValue.month, day: 1))!.weekStartDate
            let lastDay = newValue.lastDayOfMonth.weekEndDate
                                    
            var d: [DayCell] = []
            
            var currentDate = firstDay
            
            while currentDate <= lastDay
            {
                let new = DayCell(date: currentDate, vm: HealthInterface(HealthData.empty(for: currentDate)))
                d.append(new)
                
                currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
            }
            
            withAnimation(.snappy)
            {
                days = d
            }
            
            for d in days
            {
                Task.detached
                {
                    await d.vm.updateMetrics()
                }
            }
            
            // prepend days of calendar to Pages for navigation
            if findPage(for: firstDay) == nil
            {
                var nextDate = Pages[0].sample.date.yesterday
                
                while firstDay.yesterday < nextDate
                {
                    Pages.insert(HealthInterface(.empty(for: nextDate)), at: 0)
                    
                    nextDate = nextDate.yesterday
                }
            }
            
            // append days of calendar to Pages for navigation
            if findPage(for: lastDay) == nil
            {
                var nextDate = Pages[Pages.count - 1].sample.date.tomorrow
                
                while !nextDate.isSameDay(as: lastDay.tomorrow.tomorrow)
                {
                    Pages.append(HealthInterface(.empty(for: nextDate)))
                    
                    nextDate = nextDate.tomorrow
                }
            }
        }

    }
}

#Preview 
{
    PreviewPager
}
