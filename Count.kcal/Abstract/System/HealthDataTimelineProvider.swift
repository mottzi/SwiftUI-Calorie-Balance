import WidgetKit
import SwiftUI

/// Health snapshots and refresh timing shared by widgets and complications.
struct HealthDataTimelineProvider: TimelineProvider {

    /// Requests a refresh after fifteen minutes or at the next midnight.
    func getTimeline(in context: Context, completion: @escaping (Timeline<HealthDataEntry>) -> Void) {

        Task { @MainActor in
            // keep the entry and health query on the same day if midnight passes during the fetch
            let date = Date.now
            #if os(iOS)
            let mode: GraphMode = ModeToggleManager.buttonMode() ? .now : .midnight
            #else
            let mode: GraphMode = .now
            #endif
            var revision: String
            var data: HealthData
            var policy: HealthSnapshotPolicy
            repeat {
                revision = HealthRepository.shared.revision
                policy = HealthSnapshotPolicy(settings: .shared)
                data = await HealthRepository.shared.fetchDailySnapshot(for: date, policy: policy, now: date)
            } while !Task.isCancelled && (
                revision != HealthRepository.shared.revision || policy != HealthSnapshotPolicy(settings: .shared)
            )
            let midnight = Calendar.current.nextDate(
                after: date,
                matching: DateComponents(hour: 0, minute: 0, second: 0),
                matchingPolicy: .nextTime
            )!
            let timeline = Timeline(
                entries: [HealthDataEntry(
                    date: date,
                    data: data,
                    isSampleData: data.isSampleData,
                    mode: mode,
                    policy: policy
                )],
                policy: .after(min(date.addingTimeInterval(15 * 60), midnight))
            )
            completion(timeline)
        }
    }

    /// Supplies the gallery snapshot.
    func getSnapshot(in context: Context, completion: @escaping (HealthDataEntry) -> Void) {
        completion(placeholder(in: context))
    }

}

extension HealthDataTimelineProvider {

    /// Supplies sample values while WidgetKit reserves the widget layout.
    func placeholder(in context: Context) -> HealthDataEntry {
        HealthDataEntry(date: .now, data: HealthData.example(for: .now))
    }

}

/// One daily snapshot displayed by a widget or complication.
struct HealthDataEntry: TimelineEntry {

    let date: Date
    let data: HealthData
    var isSampleData: Bool = false
    var mode: GraphMode = .midnight
    var policy = HealthSnapshotPolicy()

}

extension View {

    /// Replaces failed widget measurements with an unavailable message.
    func healthSnapshotAvailability(isUnavailable: Bool) -> some View {
        opacity(isUnavailable ? 0 : 1)
            .accessibilityHidden(isUnavailable)
            .overlay {
                if isUnavailable {
                    Text("Health data unavailable")
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                }
            }
    }

}
