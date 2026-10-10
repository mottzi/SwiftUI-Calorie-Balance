import SwiftUI
import Testing
import UIKit
@testable import Count_kcal

@MainActor
struct BarGraphFillTests {

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
        let top = try pixels(of: GeometryReader { geometry in
            BarBalanceGraphTopRow(
                geometry: geometry, energy: energy, mode: .midnight, labels: false, animateNumericValues: true
            )
        }.environmentObject(settings).environment(\.colorScheme, scheme), width: 64, height: 16)
        let bottom = try pixels(of: GeometryReader { geometry in
            BarBalanceGraphBottomRow(
                geometry: geometry, energy: energy, mode: .midnight, labels: false, animateNumericValues: true
            )
        }.environmentObject(settings).environment(\.colorScheme, scheme), width: 64, height: 16)
        let shades: [(Color, BrightnessLevel, BrightnessContext, Int, [UInt8])] = [
            (settings.burnedColor, .primary, .circlegraphMidnight, 8, top),
            (settings.burnedColor, .secondary, .circlegraphMidnight, 32, top),
            (settings.burnedColor, .tertiary, .circlegraphMidnight, 56, top),
            (settings.consumedColor, .primary, .bargraph, 32, bottom)
        ]
        for (color, level, context, x, bar) in shades {
            // Reproduce the existing circle's effect order, including its final dark adjustment.
            let circle = try pixels(of: Rectangle().fill(color.gradient)
                .brightness(level: level, to: context)
                .saturation(Settings.baseSaturation)
                .brightness(scheme == .dark ? -0.1 : 0)
                .environment(\.colorScheme, scheme), width: 64, height: 16)
            for y in [2, 8, 13] {
                for channel in 0..<3 {
                    let index = (y * 64 + x) * 4 + channel
                    #expect(abs(Int(bar[index]) - Int(circle[index])) <= 1)
                }
            }
        }
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
