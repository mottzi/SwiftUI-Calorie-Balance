import SwiftUI

/// Bar corners, row spacing, value labels, and motion duration.
struct CalorieBarConfiguration {

    var cornerRadius: CGFloat = 6
    var rowSpacing: CGFloat = 2
    var showsLabels = true
    var animatesNumericValues = false
    var labelSpacing: CGFloat = 4
    var labelInset: CGFloat = 4
    var animationDuration: TimeInterval = CalorieGraphAnimation.defaultDuration

}
