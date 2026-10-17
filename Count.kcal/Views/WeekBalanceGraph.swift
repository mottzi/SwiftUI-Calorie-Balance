import SwiftUI
import SQLiteData

/// Week paging and day selection share the dashboard's calendar navigation.
struct WeekBalanceGraph: View {

    @EnvironmentObject private var settings: Settings
    @Environment(\.scenePhase) private var scenePhase

    @State private var completedRefreshRevision = 0

    @FetchAll private var dayChoices: [StoredDayChoice]

    let navigation: DayPager
    let refreshRevision: Int
    let selectDay: (Date) -> Void

    var body: some View {
        let excludedDayIDs = Set(dayChoices.filter { $0.choice == DayChoice.excluded.rawValue }.map(\.id))
        ScrollView(.horizontal) {
            // Loaded weeks retain their identities; SwiftUI creates only nearby charts.
            LazyHStack(spacing: 0) {
                ForEach(navigation.balanceWeeks) { week in
                    WeekBalanceChart(
                        dataPoints: week.days,
                        selectedDay: navigation.selectedDay,
                        selectDay: selectDay,
                        excludedDayIDs: excludedDayIDs
                    )
                    // Keep chart insets inside each page so the pager clips at the screen edge.
                    .padding(.horizontal, CardMetrics.horizontalInset + 4)
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
        // Keep pager initialization stable; animate ancestor movement as one transform.
        .transaction { $0.animation = nil }
        .geometryGroup()
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

    @ViewBuilder
    fileprivate func calendarScrollTargetBehavior(offset: CGFloat, origin: CGFloat?, isScrolling: Bool) -> some View {
        if #available(iOS 18.4, *) {
            scrollTargetBehavior(CalendarPagingBehavior(offset: offset, origin: origin, isScrolling: isScrolling))
        } else {
            scrollTargetBehavior(.paging)
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
    @State private var offset: CGFloat = 0
    @State private var dragOrigin: CGFloat?

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
            .calendarScrollTargetBehavior(
                offset: offset,
                origin: dragOrigin,
                isScrolling: phase == .interacting || phase == .decelerating
            )
            .scrollPosition($position, anchor: .center)
            .animation(animated ? .snappy : nil, value: position)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.x
            } action: { _, offset in
                self.offset = offset
            }
            .onScrollTargetVisibilityChange(idType: Date.self, threshold: 0.5) { ids in
                guard ids.count == 1, let id = ids.first else { return }
                visibleID = id
                guard phase == .interacting || phase == .decelerating, id != selection else { return }
                onSelect(id)
            }
            .onChange(of: selection) { _, day in
                // A user's midpoint selection already belongs to this scroll.
                guard visibleID != day else { return }
                position.scrollTo(id: day, anchor: .center)
            }
            .onScrollPhaseChange { _, phase, context in
                if phase == .tracking || (phase == .interacting && dragOrigin == nil) {
                    dragOrigin = context.geometry.contentOffset.x
                } else if phase == .idle {
                    dragOrigin = nil
                }
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
            .animation(animated ? .snappy : nil, value: position)
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
                position = day
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

    @EnvironmentObject private var settings: Settings
    @Environment(Streak.self) private var streak
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let graphHeight: CGFloat = 60

    let dataPoints: [HealthInterface]

    let selectedDay: Date
    let selectDay: (Date) -> Void
    var excludedDayIDs: Set<String> = []

    private var hasLoadedWeek: Bool { dataPoints.allSatisfy(\.hasLoadedSnapshot) }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(dataPoints, id: \.id) { point in
                Button {
                    selectDay(point.id)
                } label: {
                    VStack(spacing: 6) {
                        WeekDayLabel(
                            date: point.id,
                            isSelected: isDaySelected(barDay: point.id)
                        )
                        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                    
                        VBarBalanceGraph(
                            energy: point.isTodayPage ? point.sample.midnight : point.sample.now,
                            maxEnergy: maxEnergy,
                            date: point.id,
                            isSelected: isDaySelected(barDay: point.id),
                            isInCurrentStreak: streak.contains(point.id),
                            isExcluded: excludedDayIDs.contains(
                                AppDatabase.recordID(for: point.id, sampleData: point.sample.isSampleData)
                            ),
                            showsValue: hasLoadedWeek
                        )
                        .frame(height: graphHeight)
                        .opacity(hasLoadedWeek ? 1 : 0)
                        .accessibilityHidden(!hasLoadedWeek)
                        .overlay {
                            if !hasLoadedWeek {
                                Capsule()
                                    .fill(.quaternary)
                                    .frame(height: 2)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(point.id, format: .dateTime.weekday(.wide).month().day()))
                .accessibilityValue(hasLoadedWeek
                    ? Text("\(abs((point.isTodayPage ? point.sample.midnight : point.sample.now).balance))")
                    : Text("Loading calorie data"))
                .accessibilityAddTraits(isDaySelected(barDay: point.id) ? .isSelected : [])
            }
        }
        .background {
            GeometryReader { geometry in
                // Keep the existing max-based scale. An out-of-range goal has
                // no visible reference rather than being clamped to a false value.
                if settings.balanceGoal > 0, settings.balanceGoal <= maxEnergy {
                    let ratio = Double(settings.balanceGoal) / Double(maxEnergy)
                    let direction: CGFloat = settings.weightGoal == .lose ? 1 : -1
                    let baseline = geometry.size.height - graphHeight / 2
                    let goalY = baseline - direction * (VBarBalanceGraph.barHeight(graphHeight: graphHeight, ratio: ratio) + VBarBalanceGraph.baselineGap)

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
                                let height = VBarBalanceGraph.barHeight(graphHeight: graphHeight, ratio: Double(energy.balance) / Double(maxEnergy))
                                let barRect = CGRect(
                                    x: CGFloat(layoutDirection == .leftToRight ? index : dataPoints.count - index - 1) * columnWidth + columnWidth * 0.125,
                                    y: isDeficit ? baseline - height - VBarBalanceGraph.baselineGap : baseline + VBarBalanceGraph.baselineGap,
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
            .opacity(hasLoadedWeek ? 1 : 0)
        }
        // Data changes animate within the chart, independently of pager layout.
        .transaction(value: energyBalances) { transaction in
            // Initial loads explicitly disable animation; do not override their intent.
            if reduceMotion {
                transaction.animation = nil
            } else if !transaction.disablesAnimations {
                transaction.animation = .snappy
            }
        }
    }

}

private struct WeekDayLabel: View {

    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .footnote) private var dateDiameter: CGFloat = 24

    let date: Date
    let isSelected: Bool

    var body: some View {
        let isToday = date.isToday
        let todayFill = Color("SecondaryTextColor").opacity(colorScheme == .dark ? 0.28 : 0.15)

        VStack(spacing: 0) {
            Text(date, format: .dateTime.weekday(.abbreviated))
                .textCase(.uppercase)
                .font(.caption2.weight(.medium))
                .foregroundStyle(isSelected ? Color("TextColor") : Color("SecondaryTextColor"))

            Text(date, format: .dateTime.day())
                .font(.footnote.weight(.semibold))
                .foregroundStyle(isSelected ? Color("BackGroundColor") : Color("TextColor"))
                .frame(maxWidth: .infinity)
                .frame(height: dateDiameter)
                .background {
                    Circle()
                        .fill(isSelected ? Color("TextColor") : todayFill)
                        .frame(maxWidth: dateDiameter)
                        .opacity(isSelected || isToday ? 1 : 0)
                }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .animation(nil, value: isSelected)
    }

}

extension WeekBalanceChart {

    func isDaySelected(barDay: Date) -> Bool {
        Calendar.current.startOfDay(for: barDay) == selectedDay
    }

    private var energyBalances: [EnergyBalance] {
        dataPoints.map { $0.isTodayPage ? $0.sample.midnight : $0.sample.now }
    }

    var maxEnergy: Int {
        energyBalances.map { abs($0.balance) }.max() ?? 0
    }

}

extension WeekBalanceChart {

    /// Daily balance bar with goal feedback for past days.
    struct VBarBalanceGraph: View {

        @EnvironmentObject private var AppSettings: Settings

        @Environment(\.dynamicTypeSize) private var dynamicType

        @Environment(\.colorScheme) private var scheme
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        /// Current or midnight balance for the selected day.
        let energy: EnergyBalance
        let maxEnergy: Int
        let date: Date
        var isSelected: Bool = false
        var isInCurrentStreak = false
        var isExcluded: Bool = false
        var showsValue = true

        static let baselineGap: CGFloat = 1

        static func barHeight(graphHeight: CGFloat, ratio: Double) -> CGFloat {
            // Reserve the gap so maximum bars stay inside the scroll view's bounds.
            max(0, graphHeight / 2 - baselineGap) * CGFloat(abs(ratio))
        }

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
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: isExcluded)
                        .frame(width: geo.size.width * 0.75, height: barChartHeight(graphHeight: geo.size.height))
                        .overlay {
                            LinearGradient(
                                colors: [scheme == .dark ? .black : .white, color.brighten(0.1)],
                                startPoint: scheme == .dark ? .bottom : .top,
                                endPoint: scheme == .dark ? .top : .bottom
                            )
                                .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: isExcluded)
                                .opacity(scheme == .dark ? gradientOpacityDark : gradientOpacityLight)
                                .clipShape(Self.barShape(isDeficit: barChartRatio > 0))
                        }
                        .overlay {
                            if showsValue && barChartRatio != 0 && isInCurrentStreak {
                                DiagonalShine()
                                    .clipShape(Self.barShape(isDeficit: barChartRatio > 0))
                            }
                        }
                        .offset(y: barChartRatio > 0
                            ? -barChartHeight(graphHeight: geo.size.height) / 2 - Self.baselineGap
                            : barChartHeight(graphHeight: geo.size.height) / 2 + Self.baselineGap)
                    
                    Rectangle()
                        .frame(width: geo.size.width, height: 2)
                        .foregroundStyle(Color("TextColor").opacity(0.7))
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .overlay {
                    if showsValue && !dynamicType.isAccessibilitySize {
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
        if isExcluded { return .secondary }

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
        Self.barHeight(graphHeight: graphHeight, ratio: barChartRatio)
    }

}

private let gradientOpacityLight: Double = 0.10
private let gradientOpacityDark: Double = 0.20

//#Preview
//{
//}

#Preview { PreviewPager }
