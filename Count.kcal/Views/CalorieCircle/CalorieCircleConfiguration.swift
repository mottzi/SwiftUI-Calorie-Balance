import SwiftUI

/// Stroke thickness, ring spacing, bottom opening, separators, and animation duration.
struct CalorieCircleConfiguration {

    var lineWidth: CGFloat = 8
    var ringSpacing: CGFloat = 2
    var openAngle: Angle = .degrees(90)
    var segmentGap: CGFloat = 2
    var animationDuration: TimeInterval = 0.5

    /// Fits both strokes inside the available square without negative ring dimensions.
    func fitted(to diameter: CGFloat) -> CalorieCircleConfiguration {
        var fitted = self
        fitted.lineWidth = min(max(lineWidth, 0), diameter / 4)
        fitted.ringSpacing = min(max(ringSpacing, 0), max(0, (diameter - fitted.lineWidth * 4) / 2))
        fitted.openAngle = .degrees(min(max(openAngle.degrees, 0), 360))
        fitted.segmentGap = max(segmentGap, 0)
        return fitted
    }

}
