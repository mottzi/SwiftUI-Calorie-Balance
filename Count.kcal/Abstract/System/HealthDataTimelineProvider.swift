import WidgetKit

/// One daily snapshot displayed by a widget or complication.
struct HealthDataEntry: TimelineEntry {

    let date: Date
    let data: HealthData

}

/// Health snapshots and refresh timing shared by widgets and complications.
struct HealthDataTimelineProvider: TimelineProvider {

    /// Supplies sample values while WidgetKit reserves the widget layout.
    func placeholder(in context: Context) -> HealthDataEntry {
        HealthDataEntry(date: .now, data: HealthData.example(for: .now))
    }

    /// Supplies the gallery snapshot.
    func getSnapshot(in context: Context, completion: @escaping (HealthDataEntry) -> Void) {
        completion(placeholder(in: context))
    }

    /// Requests a refresh after fifteen minutes or at the next midnight.
    func getTimeline(in context: Context, completion: @escaping (Timeline<HealthDataEntry>) -> Void) {

        Task {
            // keep the entry and health query on the same day if midnight passes during the fetch
            let date = Date.now
            let data = await HKRepository.shared.fetchDailySnapshot(for: date, now: date)
            let midnight = Calendar.current.nextDate(
                after: date,
                matching: DateComponents(hour: 0, minute: 0, second: 0),
                matchingPolicy: .nextTime
            )!
            let timeline = Timeline(
                entries: [HealthDataEntry(date: date, data: data)],
                policy: .after(min(date.addingTimeInterval(15 * 60), midnight))
            )
            completion(timeline)
        }
    }

}
