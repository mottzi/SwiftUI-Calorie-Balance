import SwiftUI
import WidgetKit

/// Recorded energy paths with a marked present and a dashed midnight estimate.
struct EnergyContourDrawing: View {

    @Environment(\.widgetRenderingMode) private var renderingMode

    let contour: EnergyContour
    let burned: Color
    let consumed: Color

    var body: some View {
        GeometryReader { proxy in
            let rect = CGRect(x: 3, y: 3, width: max(proxy.size.width - 6, 1), height: max(proxy.size.height - 6, 1))
            ZStack {
                baseline(in: rect)
                present(in: rect)
                expenditure(in: rect).widgetAccentable()
                intake(in: rect)
                marker(in: rect)
            }
        }
    }

}

extension EnergyContourDrawing {

    private func baseline(in rect: CGRect) -> some View {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        }
        .stroke(.primary.opacity(0.1), lineWidth: 0.5)
    }

    private func present(in rect: CGRect) -> some View {
        Path { path in
            path.move(to: CGPoint(x: rect.minX + rect.width * contour.progress, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * contour.progress, y: rect.maxY))
        }
        .stroke(.primary.opacity(0.13), style: StrokeStyle(lineWidth: 0.5, dash: [1, 2]))
    }

    private func expenditure(in rect: CGRect) -> some View {
        ZStack {
            ribbon(in: rect)
                .fill(LinearGradient(
                    colors: [burned.opacity(0.3), burned.opacity(0.025)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
            burnedPath(in: rect)
                .stroke(burned.opacity(0.12), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            burnedPath(in: rect)
                .stroke(burned, style: StrokeStyle(
                    lineWidth: 1.5,
                    lineCap: .round,
                    lineJoin: .round,
                    dash: contour.isBurnEstimated ? [2, 2] : []
                ))
            forecast(in: rect, burned: true)
                .stroke(burned.opacity(0.5), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [2, 2.5]))
        }
    }

    private func intake(in rect: CGRect) -> some View {
        ZStack {
            consumedPath(in: rect)
                .stroke(intakeColor, style: StrokeStyle(lineWidth: 1.25, lineCap: .round, lineJoin: .round))
            forecast(in: rect, burned: false)
                .stroke(intakeColor.opacity(0.35), style: StrokeStyle(lineWidth: 0.75, lineCap: .round, dash: [1, 3]))
            Circle()
                .fill(intakeColor)
                .frame(width: 3, height: 3)
                .position(point(contour.current, burned: false, in: rect))
        }
    }

    private func marker(in rect: CGRect) -> some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [burned.opacity(0.4), burned.opacity(0)],
                    center: .center,
                    startRadius: 1,
                    endRadius: 8
                ))
                .frame(width: 16, height: 16)
                .widgetAccentable()
            Circle()
                .fill(.black)
                .frame(width: 5, height: 5)
            Circle()
                .stroke(.primary, lineWidth: 1.3)
                .frame(width: 5, height: 5)
        }
        .position(point(contour.current, burned: true, in: rect))
    }

    private var intakeColor: Color { renderingMode == .fullColor ? consumed : .white }

}

extension EnergyContourDrawing {

    private func burnedPath(in rect: CGRect) -> Path {
        smoothPath(contour.points.map { point($0, burned: true, in: rect) })
    }

    private func consumedPath(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: point(contour.points[0], burned: false, in: rect))
        for index in 1..<contour.points.count {
            let previous = point(contour.points[index - 1], burned: false, in: rect)
            let current = point(contour.points[index], burned: false, in: rect)
            path.addLine(to: CGPoint(x: current.x, y: previous.y))
            path.addLine(to: current)
        }
        return path
    }

    private func ribbon(in rect: CGRect) -> Path {

        var path = burnedPath(in: rect)
        path.addLine(to: point(contour.current, burned: false, in: rect))
        for index in (1..<contour.points.count).reversed() {
            let current = point(contour.points[index], burned: false, in: rect)
            let previous = point(contour.points[index - 1], burned: false, in: rect)
            path.addLine(to: CGPoint(x: current.x, y: previous.y))
            path.addLine(to: previous)
        }
        path.closeSubpath()
        return path
    }

    private func forecast(in rect: CGRect, burned: Bool) -> Path {
        Path { path in
            path.move(to: point(contour.current, burned: burned, in: rect))
            path.addLine(to: CGPoint(
                x: rect.maxX,
                y: rect.maxY - rect.height * (burned ? contour.estimatedBurned : contour.current.consumed) / contour.scale
            ))
        }
    }

    private func point(_ value: EnergyContour.Point, burned: Bool, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + rect.width * value.time,
            y: rect.maxY - rect.height * (burned ? value.burned : value.consumed) / contour.scale
        )
    }

    private func smoothPath(_ points: [CGPoint]) -> Path {

        var path = Path()
        path.move(to: points[0])
        guard points.count > 1 else { return path }
        let slopes = zip(points, points.dropFirst()).map { first, second in
            (second.y - first.y) / max(second.x - first.x, 0.001)
        }
        for index in 1..<points.count {
            let first = points[index - 1]
            let second = points[index]
            let distance = (second.x - first.x) / 3
            let before = index > 1 ? tangent(slopes[index - 2], slopes[index - 1]) : slopes[0]
            let after = index < slopes.count ? tangent(slopes[index - 1], slopes[index]) : slopes[index - 1]
            path.addCurve(
                to: second,
                control1: CGPoint(x: first.x + distance, y: min(max(first.y + before * distance, second.y), first.y)),
                control2: CGPoint(x: second.x - distance, y: min(max(second.y - after * distance, second.y), first.y))
            )
        }
        return path
    }

    private func tangent(_ first: Double, _ second: Double) -> Double {
        first * second > 0 ? 2 / (1 / first + 1 / second) : 0
    }

}
