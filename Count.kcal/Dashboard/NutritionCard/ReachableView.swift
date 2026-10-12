import SwiftUI
import WidgetKit

/// A labeled total and goal with a progress bar, shared by the apps and widgets.
struct ReachableView: View {

    @Environment(\.colorScheme) private var scheme

    @EnvironmentObject private var settings: Settings

    private let context: ViewContext
    private let consumedValue: Int
    private let goalValue: Int
    private let key: LocalizedStringKey
    private let unit: String
    private let color: Color
    private let graphHeight: CGFloat
    private let isLoading: Bool

    init(
        _ key: LocalizedStringKey,
        context: ViewContext = .app,
        consumedValue: Int,
        goalValue: Int,
        unit: String = "g",
        color: Color = Color("SecondaryTextColor"),
        graphHeight: CGFloat = 18,
        isLoading: Bool = false
    ) {
        self.key = key
        self.context = context
        self.consumedValue = consumedValue
        self.goalValue = goalValue
        self.unit = unit
        self.color = color
        self.graphHeight = graphHeight
        self.isLoading = isLoading
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ReachableHeader(
                key: key,
                consumedValue: consumedValue,
                goalValue: goalValue,
                unit: unit,
                animatesValues: context != .app,
                isLoading: isLoading
            )

            ReachableBar(
                progress: !isLoading && goalValue > 0 ? Double(consumedValue) / Double(goalValue) : 0,
                color: color,
                emptyColor: settings.getGraphEmptyColor(scheme),
                height: graphHeight
            )
            .opacity(isLoading ? 0.3 : 1)
            .scaleEffect(x: 1, y: isLoading ? 0.25 : 1)
        }
        .accessibilityElement(children: .combine)
    }

}

/// Keeps the numeric total together and gives it space before the label.
private struct ReachableHeader: View {

    @Environment(\.dynamicTypeSize) private var dynamicType

    let key: LocalizedStringKey
    let consumedValue: Int
    let goalValue: Int
    let unit: String
    let animatesValues: Bool
    let isLoading: Bool

    var body: some View {
        let stacked = dynamicType.isAccessibilitySize
        let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2)) : AnyLayout(HStackLayout())
        layout {
            Text(key)
                .lineLimit(stacked ? nil : 1)
                .transaction { $0.animation = nil }

            values
                .contentTransition(.numericText(value: Double(consumedValue)))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
                .frame(maxWidth: .infinity, alignment: stacked ? .leading : .trailing)
                .transaction { if !animatesValues { $0.animation = nil } }
        }
        .font(.caption.bold())
        .fontDesign(.rounded)
        .padding(.horizontal, 4)
        #if !os(watchOS)
        .foregroundStyle(Color("TextColor"))
        #endif
    }

    @ViewBuilder
    private var values: some View {
        if isLoading {
            Text(
                verbatim: goalValue > 0
                    ? "— / \(goalValue.formatted(.number.grouping(.never))) \(unit)"
                    : "— \(unit)"
            )
                .foregroundStyle(Color("SecondaryTextColor"))
        } else if goalValue > 0 {
            Text(
                """
                \(consumedValue, format: .number.grouping(.never)) / \
                \(goalValue, format: .number.grouping(.never)) \(unit)
                """
            )
        } else {
            Text("\(consumedValue, format: .number.grouping(.never)) \(unit)")
        }
    }

}

/// Draws a clamped fraction without storing layout measurements in state.
private struct ReachableBar: View {

    @Environment(\.colorScheme) private var scheme
    @Environment(\.widgetRenderingMode) private var renderingMode

    let progress: Double
    let color: Color
    let emptyColor: Color
    let height: CGFloat

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(emptyColor.brighten(scheme == .light ? 0.15 : -0.05))
                    .opacity(palette.empty.opacity)

                Capsule()
                    .fill(color.brighten(0.1))
                    .saturation(Settings.baseSaturation - 0.2)
                    .frame(width: geometry.size.width * min(max(progress, 0), 1))
                    .overlay {
                        LinearGradient(
                            colors: [scheme == .dark ? .black : .white, color.brighten(0.1)],
                            startPoint: scheme == .dark ? .bottom : .top,
                            endPoint: scheme == .dark ? .top : .bottom
                        )
                        .opacity(scheme == .dark ? 0.20 : 0.10)
                        .clipShape(Capsule())
                    }
                    .compositingGroup()
                    .opacity(palette.consumed.opacity)
            }
            .clipShape(Capsule())
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }

    private var palette: CalorieGraphPalette {
        var palette = CalorieGraphPalette(burned: color, consumed: color, empty: emptyColor)
        if renderingMode == .accented {
            palette.applyAccentedAppearance()
        }
        return palette
    }

}

enum ViewContext: Hashable {

    case app
    case widget(WidgetFamily)

}
