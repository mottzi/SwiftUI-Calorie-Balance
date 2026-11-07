import Foundation
import Testing
@testable import Count_kcal

struct CalendarPagingTests {

    @Test(arguments: [false, true])
    func settledViewportMustMatchSelectionEvenAfterBufferInsertion(followsGesture: Bool) {
        let selected = Date(timeIntervalSince1970: 1_800_000_000)
        let shifted = selected.addingTimeInterval(-7 * 86_400)
        let request = CalendarScrollRequest(selection: selected, animated: false, followsGesture: followsGesture)
        #expect(request.requiresAlignmentCorrection(alignedID: shifted, isUserScrolling: false))
        #expect(!request.requiresAlignmentCorrection(alignedID: shifted, isUserScrolling: true))
        #expect(!request.requiresAlignmentCorrection(alignedID: selected, isUserScrolling: false))
        #expect(!request.requiresAlignmentCorrection(alignedID: nil, isUserScrolling: false))
    }


    @Test func returningToStillVisiblePageReplacesPendingScroll() {
        let source = Date(timeIntervalSince1970: 1_800_000_000)
        let nextWeek = source.addingTimeInterval(7 * 86_400)
        // The new target was requested, but the old week still contains the midpoint.
        let first = CalendarScrollRequest(selection: nextWeek, animated: true)
        let acceptsInitialTarget = first.requiresScroll(visibleID: source)
        #expect(acceptsInitialTarget)
        // A quick reversal must replace that in-flight command, even before midpoint.
        let reversal = CalendarScrollRequest(selection: source, animated: true)
        let acceptsReversal = reversal.requiresScroll(visibleID: source)
        #expect(acceptsReversal)
    }

    @MainActor @Test(arguments: [-4, -1, 0, 1, 4])
    func selectingDaysWithinPreparedWeekKeepsScrollTargetsStable(weekOffset: Int) {
        let calendar = Calendar.current
        // This week also exercises calendar-day arithmetic across the autumn DST change.
        let today = calendar.date(from: DateComponents(year: 2026, month: 10, day: 25))!
        let navigation = DayPager(past: 5, future: 1, today: today)
        let start = calendar.date(
            byAdding: .day, value: weekOffset * 7,
            to: navigation.balanceWeekStart(for: today)
        )!
        let edge = navigation.day(inBalanceWeek: start)
        navigation.selectDay(edge, animated: true)
        // Both scroll strips have settled after displaying the destination week.
        navigation.ensureSelectionBuffer()
        let targets = navigation.pages.map(\.id)

        for offset in [0, 6, 1, 5, 2, 4, 3] {
            let day = calendar.date(byAdding: .day, value: offset, to: start)!
            navigation.ensurePagesForSelection(day)
            navigation.selectDay(day, animated: true)
            navigation.ensureSelectionBuffer()
            #expect(navigation.pages.map(\.id) == targets)
            #expect(navigation.page(for: day) != nil)
        }
    }

    @MainActor @Test func initialWeekAlreadyHasStableScrollTargets() {
        let calendar = Calendar.current
        let today = calendar.date(from: DateComponents(year: 2026, month: 3, day: 29))!
        let navigation = DayPager(past: 5, future: 1, today: today)
        let targets = navigation.pages.map(\.id)
        let start = navigation.balanceWeekStart(for: today)

        for offset in 0..<7 {
            let day = calendar.date(byAdding: .day, value: offset, to: start)!
            navigation.ensurePagesForSelection(day)
            #expect(navigation.pages.map(\.id) == targets)
        }
    }

    @Test(arguments: [-117.0, -100.0, 100.0, 117.0])
    func stoppedDragAdvancesToAdjacentDay(travel: Double) {

        let width: CGFloat = 402
        let movement = CGFloat(travel)
        let original = 14 * width
        let destination = CalendarPagingBehavior.destination(
            original: original,
            native: original,
            travel: movement,
            pageWidth: width,
            contentWidth: 29 * width
        )
        let expected = original + (movement > 0 ? width : -width)
        #expect(destination == expected)
    }

    @Test(arguments: [-99.9, -62.0, -20.0, 0.0, 20.0, 62.0, 99.9])
    func smallStoppedMovementKeepsNativeCancellation(travel: Double) {
        #expect(CalendarPagingBehavior.destination(
            original: 804,
            native: 804,
            travel: travel,
            pageWidth: 402,
            contentWidth: 4_020
        ) == 804)
    }

    @Test(arguments: [-1.0, 1.0])
    func nativeFlickAdvancesEvenWithSmallMovement(direction: Double) {

        let original: CGFloat = 2_010
        let native = original + CGFloat(direction) * 402
        #expect(CalendarPagingBehavior.destination(
            original: original,
            native: native,
            travel: CGFloat(direction) * 25,
            pageWidth: 402,
            contentWidth: 4_020
        ) == native)
    }

    @Test func nativeReverseFlickOverridesEarlierDragDirection() {
        #expect(CalendarPagingBehavior.destination(
            original: 804,
            native: 402,
            travel: 150,
            pageWidth: 402,
            contentWidth: 4_020
        ) == 402)
    }

    @Test(arguments: [-2_000.0, 2_000.0])
    func fastFlickCannotSkipSeveralDays(travel: Double) {
        #expect(CalendarPagingBehavior.destination(
            original: 2_010,
            native: 2_010 + travel,
            travel: travel,
            pageWidth: 402,
            contentWidth: 4_020
        ) == (travel > 0 ? 2_412 : 1_608))
    }

    @Test func cannotScrollBeyondBufferedPages() {
        #expect(CalendarPagingBehavior.destination(
            original: 0,
            native: 0,
            travel: -117,
            pageWidth: 402,
            contentWidth: 1_206
        ) == 0)
        #expect(CalendarPagingBehavior.destination(
            original: 804,
            native: 804,
            travel: 117,
            pageWidth: 402,
            contentWidth: 1_206
        ) == 804)
    }

    @Test(arguments: [200.0, 600.0])
    func slowDragThresholdUsesPointsRegardlessOfPageWidth(width: Double) {

        let pageWidth = CGFloat(width)
        let nextPage = pageWidth * 2
        #expect(CalendarPagingBehavior.destination(
            original: pageWidth,
            native: pageWidth,
            travel: 100,
            pageWidth: pageWidth,
            contentWidth: pageWidth * 5
        ) == nextPage)
        #expect(CalendarPagingBehavior.destination(
            original: pageWidth,
            native: pageWidth,
            travel: 99,
            pageWidth: pageWidth,
            contentWidth: pageWidth * 5
        ) == pageWidth)
    }

    @Test func thresholdGeometryPreservesEveryPagingDecision() {
        for width: CGFloat in [200, 390, 600] {
            let original = width * 4
            for travel in stride(from: CGFloat(-2_000), through: 2_000, by: 0.5) {
                for native in [original - width, original, original + width] {
                    let raw = CalendarPagingBehavior.destination(
                        original: original, native: native, travel: travel,
                        pageWidth: width, contentWidth: width * 10)
                    let threshold = CalendarPagingBehavior.destination(
                        original: original, native: native,
                        travel: CalendarPagingBehavior.thresholdTravel(travel),
                        pageWidth: width, contentWidth: width * 10)
                    #expect(threshold == raw)
                }
            }
        }
    }

    @Test func unlaidOutStripKeepsItsPosition() {
        #expect(CalendarPagingBehavior.destination(
            original: 804,
            native: 804,
            travel: 117,
            pageWidth: 0,
            contentWidth: 1_206
        ) == 804)
    }

    @Test(arguments: [-21, -7, 7, 21])
    func distantReturnWaitsForAnimationAndVisibleDestination(distance: Int) {
        let source = Date(timeIntervalSince1970: 1_800_000_000)
        let target = Calendar.current.date(byAdding: .day, value: distance, to: source)!
        var state = CalendarReturnState(selection: source)
        state.select(target, animated: true, pageDays: 1)
        let flight = state.flight!
        #expect(state.nativeSelection == source)
        #expect(!state.animatesNativeScroll)
        let ignoredArrival = state.arrive(at: target, requestID: state.nativeRequest.id)
        #expect(!ignoredArrival)

        state.completeAnimation(id: flight.id)
        #expect(state.nativeSelection == target)
        #expect(state.isReanchoring)
        let wrongArrival = state.arrive(at: source, requestID: state.nativeRequest.id)
        let correctArrival = state.arrive(at: target, requestID: state.nativeRequest.id)
        #expect(!wrongArrival)
        #expect(correctArrival)
        #expect(state.flight == nil)
        // Enabling this in the arrival callback can animate the native handoff.
        #expect(!state.animatesNativeScroll)
    }

    @Test(arguments: [false, true])
    func newerSelectionRetargetsSlideAndIgnoresOldCompletion(afterAnimation: Bool) {
        let source = Date(timeIntervalSince1970: 1_800_000_000)
        let target = Calendar.current.date(byAdding: .day, value: 21, to: source)!
        let latest = Calendar.current.date(byAdding: .day, value: -14, to: source)!
        var state = CalendarReturnState(selection: source)
        state.select(target, animated: true, pageDays: 1)
        let oldID = state.flight!.id
        if afterAnimation { state.completeAnimation(id: oldID) }
        state.select(latest, animated: true, pageDays: 1)
        let newID = state.flight!.id
        state.completeAnimation(id: oldID)
        let ignoredArrival = state.arrive(at: target, requestID: state.nativeRequest.id)
        #expect(!ignoredArrival)
        #expect(state.flight?.id == newID)
        #expect(state.flight?.source == target)
        #expect(state.flight?.target == latest)
        #expect(!state.isReanchoring)
        #expect(!state.animatesNativeScroll)

        state.completeAnimation(id: newID)
        #expect(state.nativeSelection == latest)
        let arrived = state.arrive(at: latest, requestID: state.nativeRequest.id)
        #expect(arrived)
        #expect(state.flight == nil)
    }

    @Test func reversingLongReturnKeepsOverlayUntilSourceIsAligned() {
        let source = Date(timeIntervalSince1970: 1_800_000_000)
        let target = source.addingTimeInterval(21 * 86_400)
        var state = CalendarReturnState(selection: source)
        let initialRequest = state.nativeRequest
        state.select(target, animated: true, pageDays: 1)
        let oldID = state.flight!.id
        state.select(source, animated: true, pageDays: 1)
        #expect(state.flight?.target == source)
        state.completeAnimation(id: oldID)
        #expect(!state.isReanchoring)
        state.completeAnimation(id: state.flight!.id)
        // The date is unchanged, but the native viewport still needs a fresh command.
        #expect(state.nativeRequest != initialRequest)
        let returnedToSource = state.arrive(at: source, requestID: state.nativeRequest.id)
        #expect(returnedToSource)
    }

    @Test func gestureAcknowledgementPreservesNativeViewportReconciliation() {
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        let request = CalendarScrollRequest(selection: day, animated: false, followsGesture: true)
        #expect(!request.requiresScroll(visibleID: day))
        #expect(request.requiresScroll(visibleID: day.addingTimeInterval(-86_400)))
        #expect(request.requiresScroll(visibleID: nil))
    }

    @Test func rapidSelectionsKeepDayAndWeekOnLatestRequest() {
        let calendar = Calendar.current
        let source = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
        var daily = CalendarReturnState(selection: source)
        var weekly = CalendarReturnState(selection: source)
        var oldDayIDs: [UUID] = []
        var oldWeekIDs: [UUID] = []
        // Deterministic stress includes reversals, adjacent requests and interruptions
        // both before and after a prior animation enters native handoff.
        for index in 0..<1_000 {
            let offset = [6, 13, 6, 7, -21, 35, 0, -1, 1][index % 9]
            let target = calendar.date(byAdding: .day, value: offset, to: source)!
            let weekOffset = offset >= 0 ? offset / 7 : (offset - 6) / 7
            let week = calendar.date(byAdding: .day, value: weekOffset * 7, to: source)!
            daily.select(target, animated: true, pageDays: 1)
            weekly.select(week, animated: true, pageDays: 7)
            if let id = oldDayIDs.last { daily.completeAnimation(id: id) }
            if let id = oldWeekIDs.last { weekly.completeAnimation(id: id) }
            #expect(daily.flight?.target ?? daily.nativeSelection == target)
            #expect(weekly.flight?.target ?? weekly.nativeSelection == week)
            if let id = daily.flight?.id {
                oldDayIDs.append(id)
                if index % 3 == 0 { daily.completeAnimation(id: id) }
            }
            if let id = weekly.flight?.id {
                oldWeekIDs.append(id)
                if index % 4 == 0 { weekly.completeAnimation(id: id) }
            }
            if index % 7 == 0 {
                if let id = daily.flight?.id { daily.completeAnimation(id: id); daily.arrive(at: target, requestID: daily.nativeRequest.id) }
                if let id = weekly.flight?.id { weekly.completeAnimation(id: id); weekly.arrive(at: week, requestID: weekly.nativeRequest.id) }
                #expect(daily.nativeSelection == target)
                #expect(weekly.nativeSelection == week)
            }
        }
    }

    @Test func staleAlignmentCannotFinishANewerReturnToTheSameDate() {
        let source = Date(timeIntervalSince1970: 1_800_000_000)
        let target = source.addingTimeInterval(21 * 86_400)
        var state = CalendarReturnState(selection: source)
        state.select(target, animated: true, pageDays: 1)
        state.completeAnimation(id: state.flight!.id)
        let staleRequest = state.nativeRequest.id
        state.select(source, animated: true, pageDays: 1)
        state.select(target, animated: true, pageDays: 1)
        state.completeAnimation(id: state.flight!.id)
        let staleArrival = state.arrive(at: target, requestID: staleRequest)
        #expect(!staleArrival)
        #expect(state.isReanchoring)
        let latestArrival = state.arrive(at: target, requestID: state.nativeRequest.id)
        #expect(latestArrival)
    }

    @Test func nativeGestureIsAcknowledgedWithoutAnAnimationOrHandoff() {
        let source = Date(timeIntervalSince1970: 1_800_000_000)
        let target = source.addingTimeInterval(86_400)
        var state = CalendarReturnState(selection: source)
        state.select(target, animated: false, pageDays: 1, followsGesture: true)
        #expect(state.nativeSelection == target)
        #expect(state.nativeRequest.followsGesture)
        #expect(!state.animatesNativeScroll)
        #expect(state.flight == nil)
    }

    @Test func shortReturnStillUsesNativeAnimationAfterLongReturn() {
        let source = Date(timeIntervalSince1970: 1_800_000_000)
        let target = Calendar.current.date(byAdding: .day, value: 21, to: source)!
        let adjacent = Calendar.current.date(byAdding: .day, value: -1, to: target)!
        var state = CalendarReturnState(selection: source)
        state.select(target, animated: true, pageDays: 1)
        state.completeAnimation(id: state.flight!.id)
        state.arrive(at: target, requestID: state.nativeRequest.id)
        state.select(adjacent, animated: true, pageDays: 1)
        #expect(state.flight == nil)
        #expect(state.nativeSelection == adjacent)
        #expect(state.animatesNativeScroll)
    }

    @Test func disablingMotionSettlesAnActiveReturnImmediately() {
        let source = Date(timeIntervalSince1970: 1_800_000_000)
        let target = Calendar.current.date(byAdding: .day, value: 21, to: source)!
        var state = CalendarReturnState(selection: source)
        state.select(target, animated: true, pageDays: 1)
        let oldID = state.flight!.id
        state.select(target, animated: false, pageDays: 1)
        state.completeAnimation(id: oldID)
        #expect(state.nativeSelection == target)
        #expect(state.flight == nil)
        #expect(!state.animatesNativeScroll)
    }

    @Test(arguments: [1, 7])
    func adjacentCalendarPageAcrossDSTUsesNativeScroll(pageDays: Int) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich")!
        let source = calendar.date(from: DateComponents(year: 2026, month: 10, day: 24))!
        let target = calendar.date(byAdding: .day, value: pageDays, to: source)!
        var state = CalendarReturnState(selection: source)
        state.select(target, animated: true, pageDays: pageDays, calendar: calendar)
        #expect(state.flight == nil)
        #expect(state.animatesNativeScroll)
    }

}
