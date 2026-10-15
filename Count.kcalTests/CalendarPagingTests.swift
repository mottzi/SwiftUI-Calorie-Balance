import Foundation
import Testing
@testable import Count_kcal

struct CalendarPagingTests {

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

    @Test func unlaidOutStripKeepsItsPosition() {
        #expect(CalendarPagingBehavior.destination(
            original: 804,
            native: 804,
            travel: 117,
            pageWidth: 0,
            contentWidth: 1_206
        ) == 804)
    }

}
