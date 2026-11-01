import SwiftUI

/// Elapsed local calendar days in the current uninterrupted sharing period.
struct SharingDurationView: View {

    @Environment(\.calendar) private var calendar

    let peerName: String
    let startedAt: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let days = max(0, calendar.dateComponents(
                [.day], from: calendar.startOfDay(for: startedAt),
                to: calendar.startOfDay(for: context.date)
            ).day ?? 0)
            if days == 0 {
                Text("You've been sharing your calorie balance with \(peerName) since today.",
                     comment: "Sharing duration on the day both people accepted sharing. The argument is the other person's name.")
            } else {
                Text("You've been sharing your calorie balance with \(peerName) for \(days) days.",
                     comment: "Uninterrupted sharing duration. First argument is the other person's name; second is the number of local calendar days since acceptance.")
            }
        }
    }

}
