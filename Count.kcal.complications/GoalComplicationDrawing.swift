import SwiftUI
import WidgetKit

/// Open progress ring with a separate track for tinted watch faces.
struct ComplicationProgressRing: View {

    let fraction: Double
    let color: Color
    var lineWidth: CGFloat = 4

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.78)
                .stroke(.primary.opacity(0.18), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            Circle()
                .trim(from: 0, to: min(max(fraction, 0), 1) * 0.78)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .widgetAccentable()
        }
        .rotationEffect(.degrees(129.6))
        .padding(lineWidth / 2)
        .accessibilityHidden(true)
    }

}

/// Twenty equal segments measure progress toward one daily allowance.
struct ComplicationSegmentedMeter: View {

    let fraction: Double
    let color: Color

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<20) { segment in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(.primary.opacity(0.18))
                    .overlay(alignment: .leading) {
                        GeometryReader { geometry in
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(color)
                                .frame(width: geometry.size.width * min(max(fraction * 20 - Double(segment), 0), 1))
                                .widgetAccentable()
                        }
                    }
            }
        }
        .frame(height: 9)
        .accessibilityHidden(true)
    }

}
