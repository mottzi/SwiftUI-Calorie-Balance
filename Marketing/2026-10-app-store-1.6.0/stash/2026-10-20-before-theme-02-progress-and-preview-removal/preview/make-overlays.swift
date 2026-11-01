import AppKit
import Foundation

// Editable native typography for the App Preview. Coordinates are top-left.
let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let copy: [String: [[String]]] = [
    "en-US": [["TODAY", "Your day.", "In balance."], ["NOW + MIDNIGHT", "See where today", "is heading."], ["MACROS + PROGRESS", "Macros and", "weight trends."], ["THEME 2", "Your theme.", "Your choice."], ["COUNT.KCAL", "Know your", "balance."]],
    "es-ES": [["HOY", "Tu día.", "En equilibrio."], ["AHORA + MEDIANOCHE", "Anticipa tu", "balance del día."], ["MACROS + PROGRESO", "Macros y", "evolución del peso."], ["TEMA 2", "Tus colores.", "Tu elección."], ["COUNT.KCAL", "Conoce tu", "balance."]],
    "de-DE": [["HEUTE", "Dein Tag.", "In Balance."], ["JETZT + MITTERNACHT", "Sieh, wohin dein", "Tag führt."], ["MAKROS + FORTSCHRITT", "Makros und", "Gewichtstrends."], ["DESIGN 2", "Deine Farben.", "Deine Wahl."], ["COUNT.KCAL", "Deine Bilanz.", "Auf einen Blick."]],
    "fr-FR": [["AUJOURD'HUI", "Votre journée.", "En équilibre."], ["MAINTENANT + MINUIT", "Anticipez votre", "bilan du jour."], ["MACROS + PROGRÈS", "Macros et", "évolution du poids."], ["THÈME 2", "Vos couleurs.", "Votre choix."], ["COUNT.KCAL", "Votre bilan.", "En un regard."]]
]
let width = 886, height = 246
let background = NSColor(srgbRed: 17/255, green: 18/255, blue: 22/255, alpha: 1)
for (locale, scenes) in copy {
    let folder = root.appendingPathComponent(locale, isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    for (index, lines) in scenes.enumerated() {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let context = NSGraphicsContext.current!.cgContext
        context.translateBy(x: 0, y: CGFloat(height)); context.scaleBy(x: 1, y: -1)
        background.setFill(); NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).fill()
        func draw(_ text: String, x: CGFloat, y: CGFloat, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
            let style = NSMutableParagraphStyle(); style.lineBreakMode = .byClipping
            let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .paragraphStyle: style, .kern: -0.8]
            text.draw(in: NSRect(x: x, y: y, width: 786, height: size * 1.4), withAttributes: attributes)
        }
        // AppKit's glyph drawing uses its own orientation, so flip the text locally.
        context.saveGState(); context.translateBy(x: 0, y: CGFloat(height)); context.scaleBy(x: 1, y: -1)
        func topDraw(_ text: String, top: CGFloat, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
            draw(text, x: 48, y: CGFloat(height) - top - size * 1.25, size: size, weight: weight, color: color)
        }
        topDraw(lines[0], top: 24, size: 19, weight: .semibold, color: NSColor(srgbRed: 0.40, green: 0.68, blue: 1, alpha: 1))
        topDraw(lines[1], top: 62, size: 65, weight: .semibold, color: NSColor(srgbRed: 245/255, green: 245/255, blue: 247/255, alpha: 1))
        topDraw(lines[2], top: 132, size: 65, weight: .semibold, color: NSColor(srgbRed: 245/255, green: 245/255, blue: 247/255, alpha: 1))
        context.restoreGState()
        NSGraphicsContext.restoreGraphicsState()
        try rep.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent(String(format: "caption-%02d.png", index + 1)))
    }
}
