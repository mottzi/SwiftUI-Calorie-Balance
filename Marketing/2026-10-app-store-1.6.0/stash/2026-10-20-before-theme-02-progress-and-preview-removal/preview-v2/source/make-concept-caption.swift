import AppKit
import Foundation

let destination = URL(fileURLWithPath: CommandLine.arguments[1])
let width = 886, height = 100
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor(srgbRed: 17/255, green: 18/255, blue: 22/255, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).fill()
let text = NSMutableAttributedString(string: "Calorie balance.", attributes: [
    .font: NSFont.systemFont(ofSize: 50, weight: .semibold),
    .foregroundColor: NSColor(srgbRed: 245/255, green: 245/255, blue: 247/255, alpha: 1),
    .kern: -1.0
])
text.addAttribute(.foregroundColor, value: NSColor(srgbRed: 139/255, green: 185/255, blue: 232/255, alpha: 1), range: NSRange(location: 8, length: 8))
let size = text.size()
text.draw(at: NSPoint(x: (CGFloat(width) - size.width) / 2, y: (CGFloat(height) - size.height) / 2 + 1))
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!.write(to: destination)
