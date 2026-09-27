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

    /// Loads the current day and requests another refresh after fifteen minutes.
    func getTimeline(in context: Context, completion: @escaping (Timeline<HealthDataEntry>) -> Void) {

        Task {
            // keep the entry and health query on the same day if midnight passes during the fetch
            let date = Date.now
            let data = await HKRepository.shared.fetchDailySnapshot(for: date, now: date)
            let timeline = Timeline(
                entries: [HealthDataEntry(date: date, data: data)],
                policy: .after(date.addingTimeInterval(15 * 60))
            )
            completion(timeline)
        }
    }

}
