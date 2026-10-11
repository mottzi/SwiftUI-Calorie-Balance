import SwiftUI

/// Native ring drawing shared by live applications and archived widgets.
struct CalorieCircleDrawing: View {

    let values: EnergyGraphValues
    let configuration: CalorieCircleConfiguration
    let palette: CalorieCirclePalette

    var body: some View {
        GeometryReader { geometry in
            let diameter = max(0, min(geometry.size.width, geometry.size.height))
            let fitted = configuration.fitted(to: diameter)
            ZStack {
                CalorieCircleRing(
                    segments: values.burnedSegments,
                    diameter: diameter - fitted.lineWidth,
                    configuration: fitted,
                    palette: palette
                )
                CalorieCircleRing(
                    segments: values.consumedSegments,
                    diameter: diameter - 3 * fitted.lineWidth - 2 * fitted.ringSpacing,
                    configuration: fitted,
                    palette: palette
                )
            }
            .frame(width: diameter, height: diameter)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

}
