import SwiftUI

struct CalendarToolbarButton: View {

    @Binding var showCalendar: Bool
    let controlsDisabled: Bool
    let toggleCalendar: () -> Void

    var body: some View {
        Button(action: toggleCalendar) {
            Image(showCalendar ? .customCalendarSlash : .customCalendar)
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color("TextColor"))
                .fontWeight(.medium)
        }
        .disabled(controlsDisabled)
    }

}
