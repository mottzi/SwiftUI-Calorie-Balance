import SwiftUI

/// Week paging and day selection share the dashboard's calendar navigation.
struct WeekBalanceGraph: View {

    @EnvironmentObject private var settings: Settings
    @Environment(\.scenePhase) private var scenePhase

    @State private var completedRefreshRevision = 0

    let navigation: DayPager
    let refreshRevision: Int
    let selectDay: (Date) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            // Loaded weeks retain their identities; SwiftUI creates only nearby charts.
            LazyHStack(spacing: 0) {
                ForEach(navigation.balanceWeeks) { week in
                    WeekBalanceChart(
                        dataPoints: week.days,
                        selectedDay: navigation.selectedDay,
                        selectDay: selectDay
                    )
                    .padding(.horizontal, 6)
                    // Keep chart insets inside each page so the pager clips at the screen edge.
                    .padding(.horizontal)
                    .containerRelativeFrame(.horizontal)
                    .id(week.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .calendarPaging(
            selection: navigation.balanceWeekStart(for: navigation.selectedDay),
            animated: true,
            onSelect: { start in
                navigation.selectDay(navigation.day(inBalanceWeek: start), animated: true)
            },
            onActivity: { scrolling in
                navigation.weekIsScrolling = scrolling
                navigation.ensureSelectionBuffer()
            }
        )
        .accessibilityScrollAction { edge in
            let offset = edge == .leading ? -7 : edge == .trailing ? 7 : 0
            guard offset != 0 else { return }
            let start = navigation.balanceWeekStart(for: navigation.selectedDay)
            guard let next = Calendar.current.date(byAdding: .day, value: offset, to: start) else { return }
            let day = navigation.day(inBalanceWeek: next)
            navigation.ensurePagesForSelection(day)
            navigation.selectDay(day, animated: true)
        }
        .task(id: refreshKey) { await refreshWeek() }
    }

    private var refreshKey: WeekRefreshKey {
        WeekRefreshKey(
            start: navigation.balanceWeekStart(for: navigation.selectedDay),
            today: navigation.weekPages.last!.id,
            active: scenePhase == .active,
            source: settings.dataSource.rawValue,
            unit: settings.energyUnit.rawValue,
            activeGoal: settings.customCalActive,
            passiveGoal: settings.customCalPassive,
            revision: refreshRevision,
            bufferedWeeks: navigation.balanceWeeks.count
        )
    }

    private func refreshWeek() async {
        let key = refreshKey
        guard key.active else { return }
        let force = completedRefreshRevision != key.revision

        let calendar = Calendar.current
        // Load all five buffered weeks, nearest first. Scrolling can change the
        // priority, but each day retains and completes its in-progress load.
        let weeks = navigation.balanceWeeks.filter {
            abs(calendar.dateComponents([.day], from: key.start, to: $0.id).day ?? 0) <= 14
        }.sorted {
            abs($0.id.timeIntervalSince(key.start)) < abs($1.id.timeIntervalSince(key.start))
        }
        for week in weeks {
            guard !Task.isCancelled else { return }
            // Pager owns the latest week's refresh and the selected dashboard day.
            guard week.id != navigation.weekPages.first?.id else { continue }
            let days = week.days.filter { $0.id != navigation.selectedDay }
            // Bound query fan-out instead of starting 7 x 8 HealthKit queries at once.
            for offset in stride(from: 0, to: days.count, by: 2) {
                guard !Task.isCancelled else { return }
                let batch = days[offset..<min(offset + 2, days.count)]
                await withTaskGroup(of: Void.self) { group in
                    for day in batch {
                        group.addTask {
                            guard !Task.isCancelled else { return }
                            await day.updateMetrics(animated: false, force: force)
                        }
                    }
                }
            }
            guard !Task.isCancelled else { return }
        }
        completedRefreshRevision = key.revision
    }

}

// Both calendar strips use the same native paging and visibility policy.
extension View {
    @ViewBuilder
    func calendarPaging(
        selection: Date,
        animated: Bool,
        onSelect: @escaping (Date) -> Void,
        onActivity: @escaping (Bool) -> Void
    ) -> some View {
        if #available(iOS 18, *) {
            modifier(CalendarPaging(selection: selection, animated: animated,
                                    onSelect: onSelect, onActivity: onActivity))
        } else {
            modifier(LegacyCalendarPaging(selection: selection, animated: animated,
                                          onSelect: onSelect, onActivity: onActivity))
        }
    }
}

@available(iOS 18, *)
private struct CalendarPaging: ViewModifier {
    let selection: Date
    let animated: Bool
    let onSelect: (Date) -> Void
    let onActivity: (Bool) -> Void
    @State private var position: ScrollPosition
    @State private var phase: ScrollPhase = .idle
    @State private var visibleID: Date?

    init(selection: Date, animated: Bool,
         onSelect: @escaping (Date) -> Void, onActivity: @escaping (Bool) -> Void) {
        self.selection = selection
        self.animated = animated
        self.onSelect = onSelect
        self.onActivity = onActivity
        _position = State(initialValue: ScrollPosition(id: selection, anchor: .center))
        _visibleID = State(initialValue: selection)
    }

    func body(content: Content) -> some View {
        content
            .scrollTargetBehavior(.paging)
            .scrollPosition($position, anchor: .center)
            .onScrollTargetVisibilityChange(idType: Date.self, threshold: 0.5) { ids in
                guard ids.count == 1, let id = ids.first else { return }
                visibleID = id
                guard phase == .interacting || phase == .decelerating, id != selection else { return }
                onSelect(id)
            }
            .onAppear { position.scrollTo(id: selection, anchor: .center) }
            .onChange(of: selection) { _, day in
                // A user's midpoint selection already belongs to this scroll.
                guard visibleID != day else { return }
                withAnimation(animated ? .snappy : nil) {
                    position.scrollTo(id: day, anchor: .center)
                }
            }
            .onScrollPhaseChange { _, phase in
                self.phase = phase
                onActivity(phase != .idle)
            }
    }
}

/// iOS 17 uses SwiftUI's ID binding for native paging and selection.
private struct LegacyCalendarPaging: ViewModifier {
    let selection: Date
    let animated: Bool
    let onSelect: (Date) -> Void
    let onActivity: (Bool) -> Void
    @State private var position: Date?
    @State private var programmaticTarget: Date?

    init(selection: Date, animated: Bool,
         onSelect: @escaping (Date) -> Void, onActivity: @escaping (Bool) -> Void) {
        self.selection = selection
        self.animated = animated
        self.onSelect = onSelect
        self.onActivity = onActivity
        _position = State(initialValue: selection)
    }

    func body(content: Content) -> some View {
        content
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $position, anchor: .center)
            .onChange(of: position) { _, day in
                guard let day else { return }
                if let target = programmaticTarget {
                    if day == target { programmaticTarget = nil }
                } else if day != selection {
                    onSelect(day)
                }
            }
            .onChange(of: selection) { _, day in
                guard position != day else { return }
                programmaticTarget = day
                withAnimation(animated ? .snappy : nil) { position = day }
            }
    }
}

private struct WeekRefreshKey: Hashable {
    var start: Date
    let today: Date
    let active: Bool
    let source: Int
    let unit: String
    let activeGoal: Int
    let passiveGoal: Int
    let revision: Int
    let bufferedWeeks: Int
}

/// One compact seven-day balance page; also used by self-contained previews.
struct WeekBalanceChart: View {

    @Environment(\.dynamicTypeSize) private var dynamicType
    @EnvironmentObject private var settings: Settings
    @Environment(\.layoutDirection) private var layoutDirection

    private let graphHeight: CGFloat = 60

    let dataPoints: [HealthInterface]

    let selectedDay: Date
    let selectDay: (Date) -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(dataPoints, id: \.id) { point in
                Button {
                    selectDay(point.id)
                } label: {
                    VStack(spacing: 6) {
                        HStack(spacing: 2) {
                            ZStack {
                                Image(systemName: "circle.fill")
                                    .foregroundStyle(Color("TextColor"))
                                    .font(.system(size: 18))
                                    .opacity(isDaySelected(barDay: point.id) ? 1 : 0)

                                Text("\(point.id.workday)")
                                    .font(dynamicType.isAccessibilitySize ? .caption2 : .system(size: 12))
                                    .fontDesign(.rounded)
                                    .fontWeight(.bold)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .foregroundStyle(
                                        isDaySelected(barDay: point.id) ? Color("ContrastColor") : Color("TextColor")
                                    )
                                    .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                            }
                            .animation(.snappy, value: isDaySelected(barDay: point.id))
                            Text(point.id, format: .dateTime.day())
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(Color("SecondaryTextColor"))
                                .lineLimit(1)
                        }
                        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                    
                        VBarBalanceGraph(
                            energy: point.isTodayPage ? point.sample.midnight : point.sample.now,
                            maxEnergy: maxEnergy,
                            date: point.id,
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
                .accessibilityAddTraits(isDaySelected(barDay: point.id) ? .isSelected : [])
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
                            let columnWidth = geometry.size.width / CGFloat(dataPoints.count)
                            for (index, point) in dataPoints.enumerated() {
                                let energy = point.isTodayPage ? point.sample.midnight : point.sample.now
                                let isDeficit = energy.balance > 0
                                let height = graphHeight / 2 * CGFloat(abs(energy.balance)) / CGFloat(maxEnergy)
                                let barRect = CGRect(
                                    x: CGFloat(layoutDirection == .leftToRight ? index : dataPoints.count - index - 1) * columnWidth + columnWidth * 0.125,
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

extension WeekBalanceChart {

    func isDaySelected(barDay: Date) -> Bool {
        Calendar.current.startOfDay(for: barDay) == selectedDay
    }

    var maxEnergy: Int {
        dataPoints.map { point in
            abs((point.isTodayPage ? point.sample.midnight : point.sample.now).balance)
        }.max() ?? 0
    }

}

extension WeekBalanceChart {

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

extension WeekBalanceChart.VBarBalanceGraph {

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
