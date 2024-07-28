import SwiftUI

struct CircleProgressView: View
{
    var progress: Double
    var color: Color
    var cutout: Double = 0.25
    var lineWidth: CGFloat = 8
    
    var body: some View 
    {
        ArcShape(ratio: progress, cutout: cutout)
            .stroke(color.gradient, lineWidth: lineWidth)
    }
}

struct ArcShape: Shape
{
    var ratio: Double
    var cutout: Double
    var degreesCutout: Double { 360 * cutout }
    var graphStartAngle: Double { 180 + degreesCutout / 2 }
    var graphEndAngle: Double { 180 - degreesCutout / 2 }
    var interpolatedEnd: Double { graphStartAngle + graphEndAngle * 2 * ratio }
    
    var animatableData: Double
    {
        get { max(0, ratio) }
        set { ratio = max(0, newValue) }
    }
    
    func path(in rect: CGRect) -> Path 
    {
        let start = Angle.degrees(graphStartAngle - 90)
        let end = Angle.degrees(interpolatedEnd - 90)

        var path = Path()
        
        path.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: rect.width / 2, startAngle: start, endAngle: end, clockwise: false)

        return path
    }
}
