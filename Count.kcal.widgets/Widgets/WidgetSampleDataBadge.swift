import SwiftUI
import WidgetKit

/// Mirrors the top-trailing mode icon's styling at the widget's leading edge.
private struct WidgetSampleDataBadge: View {

    @Environment(\.colorScheme) private var scheme
    @Environment(\.widgetRenderingMode) private var renderingMode

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
            .background {
                if scheme == .dark || renderingMode == .accented {
                    UnevenRoundedRectangle(
                        topLeadingRadius: 20,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 20,
                        topTrailingRadius: 0,
                        style: .circular
                    )
                    .fill(Color("BackGroundColor").gradient)
                    .opacity(renderingMode == .accented ? 0.25 : 1)
                }
            }
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
