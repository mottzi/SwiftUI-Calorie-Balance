import SwiftUI

struct ProgressExcludedDays: View {

    @Environment(\.dynamicTypeSize) private var dynamicType

    let days: [(day: ProgressDay, eligibility: DayEligibility)]
    let restore: (Date) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Not included")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                ForEach(days, id: \.day.id) { item in
                    VStack(spacing: 0) {
                        let layout = dynamicType.isAccessibilitySize
                            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                            : AnyLayout(HStackLayout(spacing: 12))
                        layout {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.day.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                                Text(item.eligibility.title)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityElement(children: .combine)
                            if item.eligibility == .excluded {
                                Button("Undo") { restore(item.day.date) }
                                    .frame(minWidth: 44, minHeight: 44)
                                    .accessibilityLabel("Undo exclusion for \(item.day.date, format: .dateTime.weekday().day().month())")
                            }
                        }
                        .frame(minHeight: 44)
                        .padding(.vertical, 6)
                        if item.day.id != days.last?.day.id { Divider() }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
            Text("Exclusions affect your average and streak, not weight.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

}
