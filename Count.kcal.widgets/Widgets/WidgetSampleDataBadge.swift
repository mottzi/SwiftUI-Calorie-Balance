import SwiftUI
import WidgetKit

/// Marks sample data at the widget's leading edge.
private struct WidgetSampleDataBadge: View {

    var body: some View {
        Image(systemName: "testtube.2")
            .accessibilityLabel("Sample Data")
            .font(.caption)
            .fontWeight(.thin)
            .foregroundStyle(Color("SecondaryTextColor"))
            .fixedSize()
            .padding(.leading, 12)
            .padding(.trailing, 10)
            .padding(.top, 3)
            .opacity(0.8)
    }

}

extension View {

    /// The entry keeps the badge consistent with the values displayed by the widget.
    func sampleHealthDataIndicator(_ entry: HealthDataEntry) -> some View {
        overlay(alignment: .topLeading) {
            if entry.isSampleData {
                WidgetSampleDataBadge()
            }
        }
    }

}
