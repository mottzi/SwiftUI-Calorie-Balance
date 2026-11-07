import SwiftUI
import SQLiteData

/// Week paging and day selection share the dashboard's calendar navigation.
struct WeekBalanceGraph: View {

    @EnvironmentObject private var settings: Settings
    @Environment(\.scenePhase) private var scenePhase

    @State private var completedRefreshRevision = 0
    @Namespace private var viewport
    @State private var centeredPage: Date?
    @State private var alignedPage: Date?

    @FetchAll private var dayChoices: [StoredDayChoice]

    let navigation: DayPager
    let refreshRevision: Int
    let selectDay: (Date) -> Void

    var body: some View {
        let excludedDayIDs = Set(dayChoices.filter { $0.choice == DayChoice.excluded.rawValue }.map(\.id))
        CalendarPageReturn(
            selection: navigation.balanceWeekStart(for: navigation.selectedDay),
            animated: true,
            pageDays: 7,
            followsGesture: navigation.selectionSource == .weekGesture
        ) { request, acceptsUserSelection, onArrival in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(navigation.balanceWeeks) { week in
                        chart(week, excludedDayIDs: excludedDayIDs)
                            .containerRelativeFrame(.horizontal)
                            .id(week.id)
                            .calendarPagePosition(
                                id: week.id, request: request, viewport: viewport,
                                onCenter: { centeredPage = $0 }, onAlignment: { alignedPage = $0 }, onArrival: onArrival
                            )
                    }
                }
                .scrollTargetLayout()
            }
            .coordinateSpace(name: viewport)
            .scrollIndicators(.hidden)
            .calendarPaging(
                request: request,
                centeredPage: centeredPage,
                alignedPage: alignedPage,
                acceptsUserSelection: acceptsUserSelection,
                onSelect: { start in
                    navigation.selectDay(navigation.day(inBalanceWeek: start), animated: true, source: .weekGesture)
                },
                onActivity: { scrolling in
                    navigation.weekIsScrolling = scrolling
                    navigation.ensureSelectionBuffer()
                }
            )
            // CalendarPaging owns scroll transactions, including the unanimated
            // long-return handoff. Clearing animation here also cancels week changes.
            .geometryGroup()
        } destination: { date in
            if let week = navigation.balanceWeeks.first(where: { $0.id == date }) {
                chart(week, excludedDayIDs: excludedDayIDs)
            }
        }
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

    private func chart(_ week: BalanceWeek, excludedDayIDs: Set<String>) -> some View {
        WeekBalanceChart(
            dataPoints: week.days,
            selectedDay: navigation.selectedDay,
            selectDay: selectDay,
            excludedDayIDs: excludedDayIDs
        )
        .padding(.horizontal, CardMetrics.horizontalInset + 4)
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
            marketingGoals: HealthDataMode.isMarketingDataEnabled
                ? [settings.balanceGoal, settings.proteinGoal, settings.carbsGoal, settings.fatsGoal] : [],
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
        request: CalendarScrollRequest,
        centeredPage: Date?, alignedPage: Date?,
        acceptsUserSelection: Bool,
        onSelect: @escaping (Date) -> Void,
        onActivity: @escaping (Bool) -> Void
    ) -> some View {
        if #available(iOS 18, *) {
            modifier(CalendarPaging(request: request, centeredPage: centeredPage, alignedPage: alignedPage, acceptsUserSelection: acceptsUserSelection,
                                    onSelect: onSelect, onActivity: onActivity))
        } else {
            modifier(LegacyCalendarPaging(request: request, acceptsUserSelection: acceptsUserSelection,
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
    let request: CalendarScrollRequest
    let centeredPage: Date?
    let alignedPage: Date?
    let acceptsUserSelection: Bool
    private var selection: Date { request.selection }
    private var animated: Bool { request.animated }
    let onSelect: (Date) -> Void
    let onActivity: (Bool) -> Void
    @State private var position: Date?
    @State private var phase: ScrollPhase = .idle
    @State private var visibleID: Date?
    @State private var travel: CGFloat = 0
    @State private var dragOrigin: CGFloat?

    init(request: CalendarScrollRequest, centeredPage: Date?, alignedPage: Date?, acceptsUserSelection: Bool,
         onSelect: @escaping (Date) -> Void, onActivity: @escaping (Bool) -> Void) {
        self.request = request
        self.centeredPage = centeredPage
        self.alignedPage = alignedPage
        self.acceptsUserSelection = acceptsUserSelection
        self.onSelect = onSelect
        self.onActivity = onActivity
        _position = State(initialValue: request.selection)
        _visibleID = State(initialValue: request.selection)
    }

    func body(content: Content) -> some View {
        ScrollViewReader { proxy in
            content
                .calendarScrollTargetBehavior(
                    offset: (dragOrigin ?? 0) + travel,
                    origin: dragOrigin,
                    isScrolling: phase == .interacting || phase == .decelerating
                )
                .scrollPosition(id: $position, anchor: .center)
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    guard let dragOrigin else { return 0 }
                    return CalendarPagingBehavior.thresholdTravel(geometry.contentOffset.x - dragOrigin)
                } action: { _, travel in
                    // The paging rule consumes only direction and the 100-point threshold.
                    self.travel = travel
                }
                .onChange(of: centeredPage) { _, id in
                    guard let id else { return }
                    visibleID = id
                    guard acceptsUserSelection,
                          phase == .interacting || phase == .decelerating, id != selection else { return }
                    onSelect(id)
                }
                .onChange(of: request) { _, request in
                    // Acknowledge only the page the native viewport actually reports.
                    // New commands always replace an older in-flight target.
                    guard request.requiresScroll(visibleID: visibleID) else { return }
                    let day = request.selection
                    var transaction = Transaction(animation: animated ? .snappy : nil)
                    transaction.disablesAnimations = !animated
                    withTransaction(transaction) {
                        if request.followsGesture {
                            position = day
                        } else {
                            proxy.scrollTo(day, anchor: .center)
                        }
                    }
                }
                .onChange(of: alignedPage) { _, day in
                    guard request.requiresAlignmentCorrection(
                        alignedID: day, isUserScrolling: phase != .idle && phase != .animating
                    ) else { return }
                    // Geometry is authoritative: a cancelled native animation may
                    // settle at its former target even after its binding changed.
                    scroll(to: selection, using: proxy)
                }
                .onScrollPhaseChange { _, phase, context in
                    if phase == .tracking || (phase == .interacting && dragOrigin == nil) {
                        dragOrigin = context.geometry.contentOffset.x
                        // A new gesture can begin after an untracked programmatic scroll.
                        travel = 0
                    } else if phase == .idle {
                        dragOrigin = nil
                    }
                    self.phase = phase
                    onActivity(phase != .idle)
                    if phase == .idle, request.requiresAlignmentCorrection(
                        alignedID: alignedPage, isUserScrolling: false
                    ) {
                        scroll(to: selection, using: proxy)
                    }
                }
        }
    }

    private func scroll(to day: Date, using proxy: ScrollViewProxy) {
        var transaction = Transaction(animation: animated ? .snappy : nil)
        transaction.disablesAnimations = !animated
        withTransaction(transaction) { proxy.scrollTo(day, anchor: .center) }
    }

}

/// iOS 17 uses SwiftUI's ID binding for native paging and selection.
private struct LegacyCalendarPaging: ViewModifier {
    let request: CalendarScrollRequest
    let acceptsUserSelection: Bool
    let onSelect: (Date) -> Void
    let onActivity: (Bool) -> Void
    @State private var position: Date?
    @State private var programmaticTarget: Date?

    init(request: CalendarScrollRequest, acceptsUserSelection: Bool,
         onSelect: @escaping (Date) -> Void, onActivity: @escaping (Bool) -> Void) {
        self.request = request
        self.acceptsUserSelection = acceptsUserSelection
        self.onSelect = onSelect
        self.onActivity = onActivity
        _position = State(initialValue: request.selection)
    }

    func body(content: Content) -> some View {
        content
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $position, anchor: .center)
            .onChange(of: position) { _, day in
                guard let day else { return }
                if let target = programmaticTarget {
                    if day == target { programmaticTarget = nil }
                } else if acceptsUserSelection, day != request.selection {
                    onSelect(day)
                }
            }
            .onChange(of: request) { _, request in
                guard request.requiresScroll(visibleID: position) else { return }
                programmaticTarget = position == request.selection ? nil : request.selection
                var transaction = Transaction(animation: request.animated ? .snappy : nil)
                transaction.disablesAnimations = !request.animated
                withTransaction(transaction) { position = request.selection }
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
    let marketingGoals: [Int]
    let revision: Int
    let bufferedWeeks: Int
}

/// Adapts dashboard health data and preferences to the shared chart drawing.
struct WeekBalanceChart: View {
    @EnvironmentObject private var settings: Settings
    @Environment(Streak.self) private var streak

    let dataPoints: [HealthInterface]
    let selectedDay: Date
    let selectDay: (Date) -> Void
    var excludedDayIDs: Set<String> = []

    var body: some View {
        WeekBalanceChartContent(
            dataPoints: dataPoints.map { point in
                let energy = point.isTodayPage ? point.sample.midnight : point.sample.now
                return .init(
                    id: point.id,
                    energy: energy,
                    color: WeekBalanceChartContent.VBarBalanceGraph.barColor(
                        energy: energy, isToday: point.id.isToday,
                        goalReached: energy.meetsGoal(settings.balanceGoal, isLoss: settings.weightGoal == .lose),
                        isExcluded: excludedDayIDs.contains(AppDatabase.recordID(for: point.id, sampleData: point.sample.isSampleData)),
                        burned: settings.burnedColor, consumed: settings.consumedColor
                    ),
                    isInCurrentStreak: streak.contains(point.id),
                    isLoaded: point.hasLoadedSnapshot
                )
            },
            selectedDay: selectedDay,
            goalBalance: settings.weightGoal == .lose ? settings.balanceGoal : -settings.balanceGoal,
            selectDay: selectDay
        )
    }
}

/// One compact seven-day balance page; also used by self-contained previews.
struct WeekBalanceChartContent: View {

    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let graphHeight: CGFloat = 60

    struct Day: Identifiable {
        let id: Date
        let energy: EnergyBalance
        let color: Color
        var isInCurrentStreak = false
        var isLoaded = true
    }

    let dataPoints: [Day]
    let selectedDay: Date
    var calendar = Calendar.current
    var goalBalance: Int? = nil
    var selectDay: ((Date) -> Void)? = nil

    private var hasLoadedWeek: Bool { dataPoints.allSatisfy(\.isLoaded) }
    private var energyBalances: [EnergyBalance] { dataPoints.map(\.energy) }
    private var maxEnergy: Int { energyBalances.map { abs($0.balance) }.max() ?? 0 }

    private func isDaySelected(barDay: Date) -> Bool {
        calendar.isDate(barDay, inSameDayAs: selectedDay)
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(dataPoints, id: \.id) { point in
                dayColumn(point)
            }
        }
        .background {
            GeometryReader { geometry in
                // Keep the existing max-based scale. An out-of-range goal has
                // no visible reference rather than being clamped to a false value.
                if let goalBalance, goalBalance != 0, abs(goalBalance) <= maxEnergy {
                    let ratio = Double(abs(goalBalance)) / Double(maxEnergy)
                    let direction: CGFloat = goalBalance > 0 ? 1 : -1
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
                                let energy = point.energy
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

    @ViewBuilder
    private func dayColumn(_ point: Day) -> some View {
        if let selectDay {
            Button { selectDay(point.id) } label: { dayContent(point) }
                .buttonStyle(.plain)
        } else {
            dayContent(point)
        }
    }

    private func dayContent(_ point: Day) -> some View {
        VStack(spacing: 6) {
            WeekDayLabel(
                date: point.id,
                calendar: calendar,
                isSelected: isDaySelected(barDay: point.id)
            )
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)

            VBarBalanceGraph(
                energy: point.energy,
                maxEnergy: maxEnergy,
                color: point.color,
                isSelected: isDaySelected(barDay: point.id),
                isInCurrentStreak: point.isInCurrentStreak,
                showsValue: point.isLoaded
            )
            .frame(height: graphHeight)
            .opacity(point.isLoaded ? 1 : 0)
            .accessibilityHidden(!point.isLoaded)
            .overlay {
                if !point.isLoaded {
                    Capsule()
                        .fill(.quaternary)
                        .frame(height: 2)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(point.id.formatted(Date.FormatStyle(calendar: calendar, timeZone: calendar.timeZone).weekday(.wide).month().day())))
        .accessibilityValue(point.isLoaded ? Text("\(abs(point.energy.balance))") : Text("Loading calorie data"))
        .accessibilityAddTraits(isDaySelected(barDay: point.id) ? .isSelected : [])
    }

}

private struct WeekDayLabel: View {

    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .footnote) private var dateDiameter: CGFloat = 24

    let date: Date
    let calendar: Calendar
    let isSelected: Bool

    var body: some View {
        let isToday = calendar.isDateInToday(date)
        let todayFill = Color("SecondaryTextColor").opacity(colorScheme == .dark ? 0.28 : 0.15)

        VStack(spacing: 0) {
            Text(date.formatted(Date.FormatStyle(calendar: calendar, timeZone: calendar.timeZone).weekday(.abbreviated)))
                .textCase(.uppercase)
                .font(.caption2.weight(.medium))
                .foregroundStyle(isSelected ? Color("TextColor") : Color("SecondaryTextColor"))

            Text(date.formatted(Date.FormatStyle(calendar: calendar, timeZone: calendar.timeZone).day()))
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

extension WeekBalanceChartContent {

    /// Daily balance bar with goal feedback for past days.
    struct VBarBalanceGraph: View {

        @Environment(\.dynamicTypeSize) private var dynamicType

        @Environment(\.colorScheme) private var scheme
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        /// Current or midnight balance for the selected day.
        let energy: EnergyBalance
        let maxEnergy: Int
        let color: Color
        var isSelected: Bool = false
        var isInCurrentStreak = false
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
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: color)
                        .frame(width: geo.size.width * 0.75, height: barChartHeight(graphHeight: geo.size.height))
                        .overlay {
                            LinearGradient(
                                colors: [scheme == .dark ? .black : .white, color.brighten(0.1)],
                                startPoint: scheme == .dark ? .bottom : .top,
                                endPoint: scheme == .dark ? .top : .bottom
                            )
                                .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: color)
                                .opacity(scheme == .dark ? gradientOpacityDark : gradientOpacityLight)
                                .clipShape(Self.barShape(isDeficit: barChartRatio > 0))
                        }
                        .overlay {
                            if showsValue && barChartRatio != 0 && isInCurrentStreak {
                                DiagonalShine(delay: 0.65)
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

extension WeekBalanceChartContent.VBarBalanceGraph {

    var barChartRatio: Double {
        guard maxEnergy > 0 else { return 0 }
        return min(1, max(-1, Double(energy.balance) / Double(maxEnergy)))
    }

    /// Resolves the same bar appearance for local and received days.
    static func barColor(energy: EnergyBalance, isToday: Bool, goalReached: Bool,
                         isExcluded: Bool, burned: Color, consumed: Color) -> Color {
        if isExcluded || (energy.consumed <= 0 && !isToday) { return .secondary }
        let color = energy.balance > 0 ? burned : consumed
        return goalReached && !isToday ? color.brighten(0.3) : color
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
