import SwiftUI

/// Recent daily balances with selection of a day in the dashboard.
struct WeekBalanceGraph: View {

    @Environment(\.dynamicTypeSize) private var dynamicType
    @EnvironmentObject private var settings: Settings

    private let graphHeight: CGFloat = 60

    var DataPoints: [HealthInterface]

    let selectedDay: Date
    let selectDay: (Date) -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(DataPoints, id: \.id) { point in
                Button {
                    selectDay(point.id)
                } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            Image(systemName: "circle.fill")
                                .foregroundStyle(Color("TextColor"))
                                .font(.system(size: 18))
                                .opacity(isDaySelected(barDay: point.sample.date) ? 1 : 0)
                
                            Text("\(point.sample.date.workday)")
                                .font(dynamicType.isAccessibilitySize ? .caption2 : .system(size: 12))
                                .fontDesign(.rounded)
                                .fontWeight(.bold)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(
                                    isDaySelected(barDay: point.sample.date) ? Color("ContrastColor") : Color("TextColor")
                                )
                                .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                        }
                    
                        VBarBalanceGraph(
                            energy: point.isTodayPage ? point.sample.midnight : point.sample.now,
                            maxEnergy: maxEnergy,
                            date: point.sample.date,
                            isSelected: isDaySelected(barDay: point.id)
                        )
                        .frame(height: graphHeight)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(point.id, format: .dateTime.weekday(.wide).month().day()))
                .accessibilityValue(Text("\(abs((point.isTodayPage ? point.sample.midnight : point.sample.now).balance))"))
            }
        }
        .background {
            GeometryReader { geometry in
                // Keep the existing max-based scale. An out-of-range goal has
                // no visible reference rather than being clamped to a false value.
                if settings.balanceGoal > 0, settings.balanceGoal <= maxEnergy {
                    let ratio = CGFloat(settings.balanceGoal) / CGFloat(maxEnergy)
                    let direction: CGFloat = settings.weightGoal == .lose ? 1 : -1
                    let baseline = geometry.size.height - graphHeight / 2
                    let goalY = baseline - direction * (graphHeight / 2 * ratio + 1)

                    Path { path in
                        path.move(to: CGPoint(x: 0, y: goalY))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: goalY))
                    }
                    .stroke(
                        Color("TextColor").opacity(0.45),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [0.15, 6])
                    )
                    .mask {
                        // Remove the bar silhouettes from the line itself so
                        // translucent fills cannot let the dots show through.
                        Path { mask in
                            mask.addRect(CGRect(origin: .zero, size: geometry.size))
                            let columnWidth = geometry.size.width / CGFloat(DataPoints.count)
                            for (index, point) in DataPoints.enumerated() {
                                let energy = point.isTodayPage ? point.sample.midnight : point.sample.now
                                let isDeficit = energy.balance > 0
                                let height = graphHeight / 2 * CGFloat(abs(energy.balance)) / CGFloat(maxEnergy)
                                let barRect = CGRect(
                                    x: CGFloat(index) * columnWidth + columnWidth * 0.125,
                                    y: isDeficit ? baseline - height - 1 : baseline + 1,
                                    width: columnWidth * 0.75,
                                    height: height
                                )
                                mask.addPath(VBarBalanceGraph.barShape(isDeficit: isDeficit).path(in: barRect))
                            }
                        }
                        .fill(style: FillStyle(eoFill: true))
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

}

extension WeekBalanceGraph {

    func isDaySelected(barDay: Date) -> Bool {
        Calendar.current.startOfDay(for: barDay) == selectedDay
    }

    var maxEnergy: Int {
        DataPoints.map { point in
            abs((point.isTodayPage ? point.sample.midnight : point.sample.now).balance)
        }.max() ?? 0
    }

}

extension WeekBalanceGraph {

    /// Daily balance bar with goal feedback for past days.
    struct VBarBalanceGraph: View {

        @EnvironmentObject private var AppSettings: Settings

        @Environment(\.dynamicTypeSize) private var dynamicType

        @Environment(\.colorScheme) private var scheme

        /// Current or midnight balance for the selected day.
        let energy: EnergyBalance
        let maxEnergy: Int
        let date: Date
        var isSelected: Bool = false

        static func barShape(isDeficit: Bool) -> UnevenRoundedRectangle {
            UnevenRoundedRectangle(cornerRadii: RectangleCornerRadii(
                topLeading: isDeficit ? 10 : 0,
                bottomLeading: isDeficit ? 0 : 10,
                bottomTrailing: isDeficit ? 0 : 10,
                topTrailing: isDeficit ? 10 : 0
            ))
        }
        
        var body: some View {
            GeometryReader { geo in
                ZStack {
                    Self.barShape(isDeficit: barChartRatio > 0)
                        .fill(color.brighten(0.1).gradient)
                        .frame(width: geo.size.width * 0.75, height: (geo.size.height / 2.0) * abs(barChartRatio))
                        .overlay {
                            LinearGradient(
                                colors: [scheme == .dark ? .black : .white, color.brighten(0.1)],
                                startPoint: scheme == .dark ? .bottom : .top,
                                endPoint: scheme == .dark ? .top : .bottom
                            )
                                .opacity(scheme == .dark ? gradientOpacityDark : gradientOpacityLight)
                                .clipShape(Self.barShape(isDeficit: barChartRatio > 0))
                        }

                        .offset(y: barChartRatio > 0
                            ? -barChartHeight(graphHeight: geo.size.height) / 2 - 1
                            : barChartHeight(graphHeight: geo.size.height) / 2 + 1)
                    
                    Rectangle()
                        .frame(width: geo.size.width, height: 2)
                        .foregroundStyle(Color("TextColor").opacity(0.7))
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .overlay {
                    if !dynamicType.isAccessibilitySize {
                        Text("\(abs(energy.balance))")
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .font(.caption)
                            .fontDesign(.rounded)
                            .fontWeight(isSelected ? .bold : .semibold)
                            .foregroundStyle(Color("TextColor"))
                            .offset(y: energy.balance > 0 ? 14 : -14)
                    }
                }
            }
        }

    }

}

extension WeekBalanceGraph.VBarBalanceGraph {

    var barChartRatio: Double {
        guard maxEnergy > 0 else { return 0 }
        return min(1, max(-1, Double(energy.balance) / Double(maxEnergy)))
    }

    var color: Color {
        let color = barChartRatio > 0 ? AppSettings.burnedColor : AppSettings.consumedColor
        let isToday = date.isToday

        if energy.consumed <= 0 {
            if isToday {
                return color
            } else {
                return .secondary
            }
        } else {
            if energy.meetsGoal(AppSettings.balanceGoal, isLoss: AppSettings.weightGoal == .lose) && !isToday {
                return color.brighten(0.3)
            } else {
                return color
            }
        }
    }

    func barChartHeight(graphHeight: CGFloat) -> CGFloat {
        (graphHeight / 2.0) * abs(barChartRatio)
    }

}

//#Preview
//{
//}

#Preview { PreviewPager }
