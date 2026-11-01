import AppKit
import Foundation

let folder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
let localized: [String: [(String, String)]] = [
    "en-US": [("Calorie balance", "balance"), ("Your progress", "progress"), ("Custom colors", "colors"), ("Custom colors", "colors")],
    "de-DE": [("Kalorienbilanz", "bilanz"), ("Dein Fortschritt", "Fortschritt"), ("Eigene Farben", "Farben"), ("Eigene Farben", "Farben")],
    "fr-FR": [("Bilan calorique", "calorique"), ("Vos progrès", "progrès"), ("Vos couleurs", "couleurs"), ("Vos couleurs", "couleurs")],
    "es-ES": [("Balance calórico", "calórico"), ("Tu progreso", "progreso"), ("Tus colores", "colores"), ("Tus colores", "colores")]
]
let width = 886, height = 116
for (locale, captions) in localized {
    let localeFolder = folder.appendingPathComponent(locale, isDirectory: true)
    try FileManager.default.createDirectory(at: localeFolder, withIntermediateDirectories: true)
    for (index, caption) in captions.enumerated() {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSColor(srgbRed: 17/255, green: 18/255, blue: 22/255, alpha: 1).setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).fill()
    let text = NSMutableAttributedString(string: caption.0, attributes: [.font: NSFont.systemFont(ofSize: 50, weight: .semibold), .foregroundColor: NSColor(srgbRed: 245/255, green: 245/255, blue: 247/255, alpha: 1), .kern: -1.0])
    text.addAttribute(.foregroundColor, value: NSColor(srgbRed: 139/255, green: 185/255, blue: 232/255, alpha: 1), range: (caption.0 as NSString).range(of: caption.1))
    let size = text.size()
    text.draw(at: NSPoint(x: (CGFloat(width) - size.width) / 2, y: CGFloat(height - 100) + (CGFloat(100) - size.height) / 2 + 1))
    NSGraphicsContext.restoreGraphicsState()
    try rep.representation(using: .png, properties: [:])!.write(to: localeFolder.appendingPathComponent(String(format: "caption-%02d.png", index + 1)))
}
}
