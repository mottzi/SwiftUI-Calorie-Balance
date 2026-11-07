import SwiftUI

/// Calendar paging that accepts native flicks and 100-point slow drags.
struct CalendarPagingBehavior: ScrollTargetBehavior {

    let travel: CGFloat
    let origin: CGFloat?
    let isScrolling: Bool

    @available(iOS 18.4, *)
    func properties(context: PropertiesContext) -> Properties {
        PagingScrollTargetBehavior().properties(context: context)
    }

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {

        PagingScrollTargetBehavior().updateTarget(&target, context: context)
        let width = context.containerSize.width
        guard isScrolling else { return }
        guard let origin else { return }
        guard context.axes.contains(.horizontal), width > 0 else { return }
        guard abs(context.originalTarget.rect.width - width) <= 0.5 else { return }
        guard abs(origin - (origin / width).rounded() * width) <= 0.5 else { return }
        guard abs(origin - context.originalTarget.rect.minX) <= 0.5 else { return }
        target.rect.origin.x = Self.destination(
            original: context.originalTarget.rect.minX,
            native: target.rect.minX,
            travel: travel,
            pageWidth: width,
            contentWidth: context.contentSize.width
        )
    }

    /// Only direction and crossing 100 points affect the slow-drag rule.
    static func thresholdTravel(_ travel: CGFloat) -> CGFloat {
        abs(travel) >= 100 ? (travel > 0 ? 100 : -100) : 0
    }

    /// Keeps native flick targets and accepts slow drags of at least 100 points.
    static func destination(
        original: CGFloat,
        native: CGFloat,
        travel: CGFloat,
        pageWidth: CGFloat,
        contentWidth: CGFloat
    ) -> CGFloat {

        guard pageWidth > 0 else { return original }
        let start = (original / pageWidth).rounded() * pageWidth
        let destination: CGFloat
        if abs(native - start) <= 0.5, abs(travel) >= 100 {
            destination = start + (travel > 0 ? pageWidth : -pageWidth)
        } else {
            destination = native
        }
        let lower = max(start - pageWidth, 0)
        let upper = min(start + pageWidth, max(contentWidth - pageWidth, 0))
        return min(max(destination, lower), upper)
    }

}
