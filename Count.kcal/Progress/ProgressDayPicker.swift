import SwiftUI

struct ProgressDayPicker: View {

    @Environment(\.dynamicTypeSize) private var dynamicType
    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 48
    @ScaledMetric(relativeTo: .body) private var chromeHeight: CGFloat = 148
    @State private var saveFailed = false

    let days: [(day: ProgressDay, eligibility: DayEligibility)]
    let dateRange: String
    let canEdit: Bool
    let saveChoice: (DayChoice, Date) throws -> Void

    var body: some View {
        ProgressSheetContent(title: "Exclude days", detent: detent) {
            VStack(alignment: .leading, spacing: 8) {
                Text(dateRange)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)

                VStack(spacing: 0) {
                    ForEach(days, id: \.day.id) { item in
                        VStack(spacing: 0) {
                            dayButton(item.day, isExcluded: item.eligibility == .excluded)
                            if item.day.id != days.last?.day.id { Divider() }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
                .disabled(!canEdit)

                Text("Exclusions affect your calorie average and streak.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .alert("Could not save", isPresented: $saveFailed) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your choice is unchanged. Try again.")
        }
    }

    private var detent: PresentationDetent {
        if dynamicType.isAccessibilitySize || days.count > 10 { return .large }
        // The fixed-height rows leave room for the date range, footer, and toolbar.
        return .height(chromeHeight + (max(48, rowHeight) + 1) * CGFloat(days.count))
    }

    private func dayButton(_ day: ProgressDay, isExcluded: Bool) -> some View {
        Button {
            do {
                try saveChoice(isExcluded ? .automatic : .excluded, day.date)
            } catch {
                saveFailed = true
            }
        } label: {
            HStack(spacing: 8) {
                Text(day.date, format: .dateTime.weekday(.wide).day().month(.abbreviated))
                Spacer(minLength: 0)
                if isExcluded {
                    Text("Excluded")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .layoutPriority(1)
                }
            }
            .lineLimit(1)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: max(48, rowHeight), alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isExcluded ? .isSelected : [])
    }

}
