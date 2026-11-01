import SwiftUI
import Testing
import UIKit
import WidgetKit
@testable import Count_kcal

@MainActor
struct BarGraphFillTests {

    @Test(arguments: [138, 300], [LayoutDirection.leftToRight, .rightToLeft])
    func widgetProjectionLabelsRemainComplete(width: Int, direction: LayoutDirection) throws {
        let palette = CalorieGraphPalette(burned: .blue, consumed: .orange, empty: .gray)
        let configuration = CalorieBarConfiguration(animatesNumericValues: true)
        for consumed in [2_000, 3_000] {
            for mode in [WidgetRenderingMode.fullColor, .accented] {
                for projection in [0, 320] {
                    let values = EnergyGraphValues(EnergyBalance(
                        active: 700, resting: 1_580, restingRemaining: projection, consumed: consumed
                    ))
                    var images: [[UInt8]] = []
                    for retained in [false, true] {
                        images.append(try pixels(
                            of: CalorieBarRow(
                                values: values, side: .burned, configuration: configuration,
                                palette: palette, rendering: .widget,
                                projectedRestingLabel: retained ? 320 : nil
                            )
                            .environment(\.colorScheme, .dark)
                            .environment(\.layoutDirection, direction)
                            .environment(\.widgetRenderingMode, mode),
                            width: width, height: 22
                        ))
                    }
                    // Compare the projection's solid glyph pixels against the ordinary
                    // complete label. In Now mode the retained number must stay covered.
                    let occupiedEnd = Int(Double(width) * values.burnedSegments[2].range.upperBound)
                    var comparedPixels = 0
                    var mismatchedPixels = 0
                    for y in 4..<18 {
                        for trailingX in 4..<40 {
                            let x = direction == .leftToRight
                                ? occupiedEnd - 1 - trailingX : width - occupiedEnd + trailingX
                            let index = (y * width + x) * 4
                            let reference = Int(images[0][index])
                            let actual = Int(images[1][index])
                            if projection == 0 || (mode == .accented ? reference < 5 : reference > 245) {
                                comparedPixels += 1
                                if abs(actual - reference) > 2 { mismatchedPixels += 1 }
                            }
                        }
                    }
                    #expect(comparedPixels > 0)
                    #expect(mismatchedPixels == 0)
                }
            }
        }
    }

    @Test(arguments: [ColorScheme.light, .dark], [LayoutDirection.leftToRight, .rightToLeft])
    func widgetLayersPreserveSegmentShadesInBothDirections(scheme: ColorScheme, direction: LayoutDirection) throws {
        let palette = CalorieGraphPalette(burned: .blue, consumed: .orange, empty: .gray)
        let configuration = CalorieBarConfiguration(showsLabels: false, animatesNumericValues: true)
        for projection in [0, 75] {
            for consumed in [60, 250] {
                let values = EnergyGraphValues(EnergyBalance(
                    active: 25, resting: 100, restingRemaining: projection, consumed: consumed
                ))
                for side in [EnergyGraphValues.Side.burned, .consumed] {
                    var images: [[UInt8]] = []
                    for rendering in [CalorieGraphRendering.live, .widget] {
                        images.append(try pixels(
                            of: CalorieBarRow(
                                values: values, side: side, configuration: configuration,
                                palette: palette, rendering: rendering
                            )
                            .environment(\.colorScheme, scheme)
                            .environment(\.layoutDirection, rendering == .live ? .leftToRight : direction)
                            .environment(\.widgetRenderingMode, .fullColor),
                            width: 240, height: 22
                        ))
                    }
                    // average interior patches to avoid native gradient dithering and segment edges
                    for segment in values.segments(for: side) where segment.range.upperBound > segment.range.lowerBound {
                        let progress = (segment.range.lowerBound + segment.range.upperBound) / 2
                        let referenceX = min(239, Int(progress * 240))
                        let x = direction == .leftToRight ? referenceX : 239 - referenceX
                        for y in [4, 11, 17] {
                            for channel in 0..<4 {
                                let reference = averageChannel(images[0], x: referenceX, y: y, channel: channel)
                                let widget = averageChannel(images[1], x: x, y: y, channel: channel)
                                #expect(abs(reference - widget) <= 2)
                            }
                        }
                    }
                }
            }
        }
    }

    @Test(arguments: [GraphMode.now, .midnight], [ColorScheme.light, .dark])
    func tintedBarsKeepSharedShadesAndSoftenPrediction(mode: GraphMode, scheme: ColorScheme) throws {

        for consumed in [500, 1_200] {
            var data = HealthData.empty(for: Date(timeIntervalSince1970: 0))
            data.burnedActive = 200
            data.burnedPassive = 400
            data.burnedPassive7 = 800
            data.consumed = consumed
            let values = EnergyGraphValues(mode == .now ? data.now : data.midnight)
            let graph = BarBalanceGraph(
                mode: mode,
                labels: false,
                animateNumericValues: true,
                rendering: .widget
            )
                .environment(HealthInterface(data))
                .environmentObject(Settings.shared)
                .environment(\.colorScheme, scheme)
                .environment(\.widgetRenderingMode, .accented)
            // tinted content keeps its alpha while all colors become white
            let rendered = try pixels(of: Color.white.mask(graph), width: 240, height: 44)
            let circle = CircleBalanceGraph(mode: mode, accentedWidget: true, rendering: .widget)
                .environment(HealthInterface(data))
                .environmentObject(Settings.shared)
                .environment(\.colorScheme, scheme)
            let reference = try pixels(of: Color.white.mask(circle), width: 130, height: 130)
            for (side, y, radius) in [(EnergyGraphValues.Side.burned, 10, 61.0), (.consumed, 33, 51.0)] {
                for segment in values.segments(for: side) where segment.range.upperBound > segment.range.lowerBound {
                    let progress = (segment.range.lowerBound + segment.range.upperBound) / 2
                    let angle = (135 + progress * 270) * Double.pi / 180
                    let circleX = Int(65 + radius * cos(angle))
                    let circleY = Int(65 + radius * sin(angle))
                    let x = Int(progress * 240)
                    let shade = Int(rendered[(y * 240 + x) * 4])
                    let circleShade = Int(reference[(circleY * 130 + circleX) * 4])
                    if segment.id == .prediction {
                        #expect((35...55).contains(shade - circleShade))
                    } else {
                        #expect(abs(shade - circleShade) <= 2)
                    }
                }
            }
        }
    }

    @Test(arguments: [GraphMode.now, .midnight])
    func tintedBarLabelsCutThroughBrightSegments(mode: GraphMode) throws {

        var data = HealthData.empty(for: Date(timeIntervalSince1970: 0))
        data.burnedActive = 301
        data.burnedPassive = 1_412
        data.burnedPassive7 = 2_000
        data.consumed = 1_593
        var rows: [[UInt8]] = []
        for labels in [false, true] {
            let graph = BarBalanceGraph(
                mode: mode,
                labels: labels,
                animateNumericValues: true,
                rendering: .widget
            )
                .environment(HealthInterface(data))
                .environmentObject(Settings.shared)
                .environment(\.colorScheme, .dark)
                .environment(\.widgetRenderingMode, .accented)
            rows.append(try pixels(of: Color.white.mask(graph), width: 240, height: 44))
        }
        for yRange in [0..<21, 23..<44] {
            let cutoutPixelCount = yRange.reduce(0) { count, y in
                count + (0..<240).filter {
                    Int(rows[0][(y * 240 + $0) * 4]) - Int(rows[1][(y * 240 + $0) * 4]) > 100
                }.count
            }
            #expect(cutoutPixelCount > 10)
        }
    }

    @Test(arguments: [ColorScheme.light, .dark])
    func tintedNutrientBarsShowFilledAndRemainingProgress(scheme: ColorScheme) throws {

        let graph = ReachableView(
            "Carbs",
            context: .widget(.systemLarge),
            consumedValue: 60,
            goalValue: 100,
            graphHeight: 12
        )
            .environmentObject(Settings.shared)
            .environment(\.colorScheme, scheme)
            .environment(\.widgetRenderingMode, .accented)
        let rendered = try pixels(of: Color.white.mask(graph), width: 240, height: 48)
        let progressRows = (24..<48).filter { y in
            let filled = Int(rendered[(y * 240 + 60) * 4])
            let remaining = Int(rendered[(y * 240 + 210) * 4])
            return abs(filled - 179) <= 2 && abs(remaining - 64) <= 2
        }
        #expect(progressRows.count >= 6)
    }

    @Test(arguments: [ColorScheme.light, .dark])
    func shadesMatchTheBrightnessEffectWithinTheRGBRange(scheme: ColorScheme) throws {

        let colors = [
            Color(red: 0.15, green: 0.31, blue: 0.57),
            Color(red: 0.55, green: 0.23, blue: 0.10, opacity: 0.6)
        ]
        let levels: [BrightnessLevel] = [.none, .primary, .secondary, .tertiary]
        for color in colors {
            for level in levels {
                let original = try pixels(of: Rectangle().fill(color).brightness(level: level)
                    .saturation(Settings.baseSaturation).environment(\.colorScheme, scheme))
                let replacement = try pixels(of: Rectangle().fill(GraphColorStyle(color: color, level: level))
                    .saturation(Settings.baseSaturation).environment(\.colorScheme, scheme))
                #expect(zip(original, replacement).allSatisfy { abs(Int($0) - Int($1)) <= 1 })
            }
        }
    }

    @Test(arguments: [ColorScheme.light, .dark])
    func unadjustedGradientsPreserveDynamicColors(scheme: ColorScheme) throws {

        let color = Color("TextColor")
        let original = try pixels(of: Rectangle().fill(color.gradient).environment(\.colorScheme, scheme))
        let replacement = try pixels(of: Rectangle()
            .fill(GraphColorStyle(color: color, brightness: 0).gradient).environment(\.colorScheme, scheme))
        #expect(original == replacement)
    }

    @Test func brightAndWideGamutFillsStayWithinTheRGBRange() {

        let colors = [Color.white, Color(.displayP3, red: 0.95, green: 0.463, blue: 0.238, opacity: 0.6)]
        let levels: [BrightnessLevel] = [.primary, .secondary, .tertiary]
        let environment = EnvironmentValues()
        for color in colors {
            for level in levels {
                let fill = GraphColorStyle(color: color, level: level).resolve(in: environment).resolve(in: environment)
                #expect((0...1).contains(fill.red))
                #expect((0...1).contains(fill.green))
                #expect((0...1).contains(fill.blue))
                #expect(fill.opacity == color.resolve(in: environment).opacity)
            }
        }
    }

    @Test(arguments: [ColorScheme.light, .dark])
    func barSegmentsMatchTheCirclePalette(scheme: ColorScheme) throws {

        let settings = Settings.shared
        let energy = EnergyBalance(active: 25, resting: 50, restingRemaining: 25, consumed: 100)
        let palette = CalorieGraphPalette(
            burned: settings.burnedColor,
            consumed: settings.consumedColor,
            empty: settings.getGraphEmptyColor(scheme)
        )
        let configuration = CalorieBarConfiguration(showsLabels: false, animatesNumericValues: true)
        let top = try pixels(
            of: CalorieBarRow(
                values: EnergyGraphValues(energy),
                side: .burned,
                configuration: configuration,
                palette: palette
            ).environment(\.colorScheme, scheme),
            width: 64,
            height: 16
        )
        let bottom = try pixels(
            of: CalorieBarRow(
                values: EnergyGraphValues(energy),
                side: .consumed,
                configuration: configuration,
                palette: palette
            ).environment(\.colorScheme, scheme),
            width: 64,
            height: 16
        )
        let shades: [(Color, BrightnessLevel, BrightnessContext, Int, [UInt8])] = [
            (settings.burnedColor, .primary, .circlegraphMidnight, 8, top),
            (settings.burnedColor, .secondary, .circlegraphMidnight, 32, top),
            (settings.burnedColor, .tertiary, .circlegraphMidnight, 56, top),
            (settings.consumedColor, .primary, .bargraph, 32, bottom)
        ]
        for (color, level, context, x, bar) in shades {
            // Reproduce the existing circle's effect order, including its final dark adjustment.
            let circle = try pixels(
                of: Rectangle().fill(color.gradient)
                    .brightness(level: level, to: context)
                    .saturation(Settings.baseSaturation)
                    .brightness(scheme == .dark ? -0.1 : 0)
                    .environment(\.colorScheme, scheme),
                width: 64,
                height: 16
            )
            for y in [2, 8, 13] {
                for channel in 0..<3 {
                    let index = (y * 64 + x) * 4 + channel
                    #expect(abs(Int(bar[index]) - Int(circle[index])) <= 1)
                }
            }
        }
    }

    @Test(arguments: [ColorScheme.light, .dark])
    func nativeCircleSegmentsRetainTheOriginalGradient(scheme: ColorScheme) throws {
        let color = Color(.displayP3, red: 0.1, green: 0.45, blue: 0.95)
        let segment = CircleProgressView(progress: 0.8, color: color)
            .brightness(level: .secondary, to: .circlegraphMidnight)
            .graphColorAppearance().environment(\.colorScheme, scheme)
        // The previous arc geometry, without its gap mask, is the palette reference.
        let reference = Path { path in
            path.addArc(
                center: CGPoint(x: 32, y: 32),
                radius: 32,
                startAngle: .degrees(135),
                endAngle: .degrees(135 + 270 * 0.8),
                clockwise: false
            )
        }
        .stroke(color.gradient, lineWidth: 8)
        .brightness(level: .secondary, to: .circlegraphMidnight)
        .graphColorAppearance().environment(\.colorScheme, scheme)
        let actual = try pixels(of: segment, width: 64, height: 64)
        let expected = try pixels(of: reference, width: 64, height: 64)
        for progress in [0.1, 0.25, 0.45, 0.6, 0.75] {
            let angle = (135 + progress * 270) * Double.pi / 180
            let x = Int(32 + 30 * cos(angle))
            let y = Int(32 + 30 * sin(angle))
            for channel in 0..<3 {
                let offset = (y * 64 + x) * 4 + channel
                #expect(abs(Int(actual[offset]) - Int(expected[offset])) <= 2)
            }
        }
    }

}

extension BarGraphFillTests {

    private func averageChannel(_ pixels: [UInt8], x: Int, y: Int, channel: Int) -> Double {

        var total = 0
        for row in (y - 2)...(y + 2) {
            for column in (x - 2)...(x + 2) {
                total += Int(pixels[(row * 240 + column) * 4 + channel])
            }
        }
        return Double(total) / 25
    }

    private func pixels<V: View>(of view: V, width: Int = 8, height: Int = 8) throws -> [UInt8] {

        let renderer = ImageRenderer(content: view.frame(width: CGFloat(width), height: CGFloat(height)).background(.black))
        renderer.scale = 1
        let image = try #require(renderer.uiImage?.cgImage)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        try pixels.withUnsafeMutableBytes { bytes in
            let context = try #require(CGContext(
                data: bytes.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ))
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return pixels
    }

}

@MainActor
struct CircleRingTests {

    @Test func boundariesLeaveTwoPointsOfTransparentSpace() {
        let radius = 61.0
        let ring = CircleRingSegments(boundaries: [0, 0.2, 0.5, 1, 1], radius: radius)
        let arcLength = radius * 2 * Double.pi * 0.75
        for index in 0..<2 {
            let gap = ring.ranges[index + 1].lowerBound - ring.ranges[index].upperBound
            #expect(abs(gap * arcLength - 2) < 0.0001)
        }
        #expect(ring.ranges[0].lowerBound == 0)
        #expect(ring.ranges[2].upperBound == 1)
        #expect(ring.ranges[3] == 1...1)
    }

    @Test func missingSegmentsDoNotRemoveOtherBoundaries() {
        let ring = CircleRingSegments(boundaries: [0, 0.2, 0.2, 0.7, 1], radius: 61)
        #expect(ring.ranges[1] == 0.2...0.2)
        #expect(ring.ranges[0].upperBound < ring.ranges[2].lowerBound)
        #expect(ring.ranges[2].upperBound < ring.ranges[3].lowerBound)
    }

    @Test func emptyAndTinySegmentsRemainValid() {
        let empty = CircleRingSegments(boundaries: [0, 0, 0, 0, 1], radius: 61)
        #expect(empty.ranges.last == 0...1)
        let tiny = CircleRingSegments(boundaries: [0, 0.2, 0.20001, 1], radius: 61)
        #expect(tiny.ranges[1].upperBound > tiny.ranges[1].lowerBound)
        let zeroSize = CircleRingSegments(boundaries: [0, 0.5, 1], radius: 0)
        #expect(zeroSize.ranges == [0...0.5, 0.5...1])
    }

    @Test(arguments: [GraphMode.now, .midnight])
    func bothRingsExposeTheBackgroundAtTheirBoundaries(mode: GraphMode) throws {
        var data = HealthData.empty(for: .now)
        data.burnedActive = 200
        data.burnedPassive = 300
        data.burnedPassive7 = 800
        data.consumed = 500
        let graph = CircleBalanceGraph(mode: mode)
            .environment(HealthInterface(data))
            .environmentObject(Settings.shared)
            .environment(\.colorScheme, .dark)
            .frame(width: 130, height: 130)
        let renderer = ImageRenderer(content: graph.background(Color(red: 1, green: 0, blue: 1)))
        renderer.scale = 3
        let image = try #require(renderer.uiImage?.cgImage)
        let size = image.width
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        try pixels.withUnsafeMutableBytes { bytes in
            let context = try #require(CGContext(
                data: bytes.baseAddress,
                width: size,
                height: size,
                bitsPerComponent: 8,
                bytesPerRow: size * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ))
            context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
        }
        let energy = mode == .now ? data.now : data.midnight
        let boundaries: [(Double, Double)] = mode == .now
            ? [(energy.ratio(of: energy.active), 61)]
            : [(energy.ratio(of: energy.active + energy.resting), 61),
               (energy.ratio(of: energy.consumed), 51)]
        for (progress, radius) in boundaries {
            let angle = (135 + progress * 270) * Double.pi / 180
            let x = Int((65 + radius * cos(angle)) * 3)
            let y = Int((65 + radius * sin(angle)) * 3)
            let offset = (y * size + x) * 4
            #expect(pixels[offset] > 250 && pixels[offset + 1] < 5 && pixels[offset + 2] > 250)
        }
    }

}
