import SwiftUI

struct CircleProgressView: View {

    var progress: Double
    var color: Color
    var cutout: Double = 0.25
    var lineWidth: CGFloat = 8
    var startProgress: Double = 0
    
    var body: some View {
        // Expose progress as built-in trim values for WidgetKit's archived view.
        Circle()
            .trim(from: startProgress * (1 - cutout), to: progress * (1 - cutout))
            .rotation(.degrees(90 + 180 * cutout))
            .stroke(color.gradient, lineWidth: lineWidth)
    }

}
