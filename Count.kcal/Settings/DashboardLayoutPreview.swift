import SwiftUI

/// A muted, noninteractive scale model above the native ordering controls.
struct DashboardLayoutPreview: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var day: HealthInterface?
    @State private var weights: WeightHistory?
    @State private var contentHeight: CGFloat = 650

    let dailyCards: [DailyDashboardCard]
    let macros: [MacroNutrient]
    let progressPosition: ProgressPosition
    let width: CGFloat

    let canvasWidth: CGFloat

    var body: some View {
        VStack(spacing: 14) {
            Text("Layout preview")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            ZStack(alignment: .topLeading) {
                if let day, let weights {
                    VStack(spacing: 16) {
                        ForEach(progressPosition.sections) { section in
                            switch section {
                            case .daily:
                                VStack(spacing: 16) {
                                    ForEach(dailyCards) { card in
                                        DashboardPreviewCard(card: card, macros: macros)
                                            .geometryGroup()
                                    }
                                }
                                .geometryGroup()
                            case .progress:
                                DashboardPreviewProgress()
                                    .geometryGroup()
                            }
                        }
                    }
                    .frame(width: canvasWidth)
                    .fixedSize(horizontal: false, vertical: true)
                    .onGeometryChange(for: CGFloat.self) { geometry in
                        geometry.size.height
                    } action: { height in
                        contentHeight = height
                    }
                    .environment(day)
                    .environment(weights)
                    // The miniature is a diagram; the controls below retain Dynamic Type.
                    .environment(\.dynamicTypeSize, .large)
                    .animation(reduceMotion ? nil : .smooth(duration: 0.4), value: dailyCards)
                    .animation(reduceMotion ? nil : .smooth(duration: 0.4), value: macros)
                    .animation(reduceMotion ? nil : .smooth(duration: 0.4), value: progressPosition)
                    .scaleEffect(width / canvasWidth, anchor: .topLeading)
                }
            }
            .frame(width: width, height: contentHeight * width / canvasWidth, alignment: .topLeading)
            .saturation(0)
            .opacity(0.5)
            .allowsHitTesting(false)
            .accessibilityHidden(true)


        }
        .frame(width: width)
        .task {
            guard day == nil else { return }
            let date = Calendar.current.startOfDay(for: Date.now)
            day = HealthInterface(.example(for: date))
            let sampleWeights = WeightHistory()
            sampleWeights.dailyAverages = (0..<30).map { index in
                WeightChartData(date: date.subtractDays(29 - index), weightAvg: 82.7 - Double(index) * 0.1)
            }
            sampleWeights.latestWeight = 79.8
            sampleWeights.latestWeightDate = date
            weights = sampleWeights
        }
    }
}
