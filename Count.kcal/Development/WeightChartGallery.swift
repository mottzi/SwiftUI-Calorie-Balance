#if DEBUG && targetEnvironment(simulator)
import SwiftUI

/// Simulator-only entry point: launch with --weight-chart-qa.
struct WeightChartGallery: View {
    @State private var index = 0
    @State private var narrow = false
    @State private var light = false
    @State private var largeText = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button("Previous") { index = (index + WeightChartScenario.cases.count - 1) % WeightChartScenario.cases.count }
                    .accessibilityIdentifier("qa.previous")
                Spacer()
                Text(verbatim: "\(index + 1) / \(WeightChartScenario.cases.count)")
                Spacer()
                Button("Next") { index = (index + 1) % WeightChartScenario.cases.count }
                    .accessibilityIdentifier("qa.next")
            }
            HStack {
                Button(narrow ? "Width 320" : "Full width") { narrow.toggle() }
                    .accessibilityIdentifier("qa.width")
                Spacer()
                Button(light ? "Light" : "Dark") { light.toggle() }
                    .accessibilityIdentifier("qa.appearance")
                Spacer()
                Button(largeText ? "Large type" : "Default type") { largeText.toggle() }
                    .accessibilityIdentifier("qa.type")
            }
            Text(verbatim: WeightChartScenario.cases[index].id)
                .font(.headline)
            ScrollView {
                WeightChartScenarioView(scenario: WeightChartScenario.cases[index])
                    .id(index)
                    .frame(maxWidth: narrow ? 320 : .infinity)
                    .frame(maxWidth: .infinity)
                    .environment(\.dynamicTypeSize, largeText ? .accessibility3 : .large)
            }
        }
        .fontDesign(.rounded)
        .padding(.top, 8)
        .background(Settings.shared.AppBackground)
        .preferredColorScheme(light ? .light : .dark)
        .environmentObject(Settings.shared)
    }
}
#endif
