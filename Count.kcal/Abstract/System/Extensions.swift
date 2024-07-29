import Foundation
import SwiftUI

extension Text
{
    func graphLabelStyle(_ schema: ColorScheme) -> some View
    {
        self
            .foregroundColor(Color("GraphTextColor"))
            .font(.caption)
            .fontDesign(.rounded)
            .fontWeight(.semibold)
            .shadow(color: .black.opacity(schema == .dark ? 0.8 : 0.5), radius: 4)
            .contrast(schema == .dark ? 1.5 : 2)
    }
}

extension CGFloat
{
    // Function to clamp the value within the provided range
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat
    {
        // Return the clamped value
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

extension Color
{
    func darken(_ level: Double) -> Color
    {
        return self.brighten(-level)
    }
    
    func brighten(_ level: Double) -> Color
    {
        if level == 0 { return self }
        
        let uiColor = UIColor(self)
        
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        brightness += level

        let brighterUIColor = UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
        
        return Color(brighterUIColor)
    }
}

extension Calendar
{
    var shortWeekdaySymbolsLocalized: [String]
    {
        let firstWeekday = self.firstWeekday
        let symbols = self.shortWeekdaySymbols
        
        return Array(symbols[firstWeekday - 1 ..< symbols.count] + symbols[0 ..< firstWeekday - 1])
    }
}

extension Date
{
    func isSameMonth(as date: Date) -> Bool
    {
        return Calendar.current.isDate(self, equalTo: date, toGranularity: .month)
    }
    
    var year: Int
    {
        return Calendar.current.dateComponents([.year], from: self).year!
    }
    
    var month: Int
    {
        return Calendar.current.dateComponents([.month], from: self).month!
    }
    
    var day: Int
    {
        return Calendar.current.dateComponents([.day], from: self).day!
    }
    
    var monthString: String
    {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM"
        
        return dateFormatter.string(from: self)
    }
    
    var weekStartDate: Date
    {
        let weekday = Calendar.current.component(.weekday, from: self)
        let firstWeekday = Calendar.current.firstWeekday
        let daysToSubtract = (weekday - firstWeekday + 7) % 7
        
        return Calendar.current.date(byAdding: .day, value: -daysToSubtract, to: self)!
    }
    
    var weekEndDate: Date
    {
        let weekday = Calendar.current.component(.weekday, from: self)
        let firstWeekday = Calendar.current.firstWeekday
        let lastWeekdayIndex = (firstWeekday + 5) % 7 + 1

        let daysToAdd = weekday > lastWeekdayIndex ? (7 - weekday) + (lastWeekdayIndex % 7) : lastWeekdayIndex - weekday
            
        return Calendar.current.date(byAdding: .day, value: daysToAdd, to: self)!
    }
    
    var lastDayOfMonth: Date
    {
        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: self)!
        let firstDayNextMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: nextMonth))!
        
        return Calendar.current.date(byAdding: .day, value: -1, to: firstDayNextMonth)!
    }
}

#if DEBUG
extension View
{
    func debug(_ color: Color = .orange) -> some View
    {
        self
            .border(color, width: 1)
    }
}
#endif

extension Date
{
    static var getDayProgress: Double 
    {
        let now = Date.now
    
        let startOfDay = Calendar.current.startOfDay(for: now)
        let secondsSinceStartOfDay = now.timeIntervalSince(startOfDay)
        let totalSecondsInDay = 24.0 * 60.0 * 60.0

        return secondsSinceStartOfDay / totalSecondsInDay
    }
    
    var nextSunday: Date
    {
        var components = DateComponents()
        components.day = 8 - Calendar.current.component(.weekday, from: self)
        
        return Calendar.current.date(byAdding: components, to: self)!
    }
    
    var lastMonday: Date
    {
        var components = DateComponents()
        components.day = -(Calendar.current.component(.weekday, from: self) - 2)
        
        return Calendar.current.date(byAdding: components, to: self)!
    }
    
    var isToday: Bool
    {
        return self.isSameDay(as: .now)
    }
    
    func isSameDay(as date: Date) -> Bool
    {
        return Calendar.current.isDate(self, inSameDayAs: date)

//        return Calendar.current.dateComponents([.year, .month, .day], from: self) == Calendar.current.d*/ateComponents([.year, .month, .day], from: date)
    }
    
    var shortTime: String
    {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .short
            
        return dateFormatter.string(from: self)
    }
    
    var shortDate: String
    {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.current
        dateFormatter.setLocalizedDateFormatFromTemplate("EddMM")
            
        return dateFormatter.string(from: self)
    }
    
    var workday: String
    {
        let dateFormatter = DateFormatter()
        
        dateFormatter.locale = Locale.current
        dateFormatter.dateFormat = "EEEEE"

        return dateFormatter.string(from: self)
    }
    
    var dayOfMonth: String
    {
        let dateFormatter = DateFormatter()
        
        dateFormatter.locale = Locale.current
        dateFormatter.dateFormat = "dd"

        return dateFormatter.string(from: self)
    }
    
    var relative: String
    {
        if Calendar.current.isDateInToday(self)
        {
            return String(localized: "Today")
        }
        else if Calendar.current.isDateInYesterday(self)
        {
            return String(localized: "Yesterday")
        }
        else if Calendar.current.isDateInTomorrow(self)
        {
            return String(localized: "Tomorrow")
        }
        else
        {
            return self.shortDate
        }
    }
    
    func addDays(_ days: Int) -> Date
    {
        return Calendar.current.date(byAdding: .day, value: days, to: self)!
    }
    
    func subtractDays(_ days: Int) -> Date
    {
        return Calendar.current.date(byAdding: .day, value: -days, to: self)!
    }
    
    var yesterday: Date
    {
        return self.subtractDays(1)
    }
    
    var tomorrow: Date
    {
        return self.addDays(1)
    }
}
