// Draws the DMG window background (660 × 420 pt) at 1x and 2x:
//   swift Scripts/dmg/make-background.swift Scripts/dmg
// Then: tiffutil -cathidpicheck background.png background@2x.png -out background.tiff
import AppKit

let W: CGFloat = 660, H: CGFloat = 420
// Icon centres used by make-dmg.sh (Finder coordinates, origin top-left).
let tolio = CGPoint(x: 170, y: 190), apps = CGPoint(x: 490, y: 190)

func draw(scale: CGFloat) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W * scale), pixelsHigh: Int(H * scale), bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: W, height: H)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let g = NSGraphicsContext.current!.cgContext
    // Flip to top-left origin like Finder.
    g.translateBy(x: 0, y: H); g.scaleBy(x: 1, y: -1)

    // Soft lavender background with a violet glow behind the icons.
    let bg = NSGradient(colors: [NSColor(srgbRed: 0.975, green: 0.968, blue: 1.0, alpha: 1), NSColor(srgbRed: 0.918, green: 0.904, blue: 0.985, alpha: 1)])!
    bg.draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -90)
    let glow = NSGradient(colors: [NSColor(srgbRed: 0.48, green: 0.42, blue: 1, alpha: 0.18), NSColor(srgbRed: 0.48, green: 0.42, blue: 1, alpha: 0)])!
    glow.draw(fromCenter: NSPoint(x: W / 2, y: 190), radius: 0, toCenter: NSPoint(x: W / 2, y: 190), radius: 300, options: [])

    func text(_ s: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, y: CGFloat) {
        let style = NSMutableParagraphStyle(); style.alignment = .center
        let a = NSAttributedString(string: s, attributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .paragraphStyle: style])
        NSGraphicsContext.saveGraphicsState()
        // Text draws upright in a flipped context via a flipped graphics context.
        let flipped = NSGraphicsContext(cgContext: g, flipped: true)
        NSGraphicsContext.current = flipped
        a.draw(in: NSRect(x: 0, y: y, width: W, height: size * 1.6))
        NSGraphicsContext.restoreGraphicsState()
    }
    text("Drag Tolio to Applications", size: 21, weight: .semibold, color: NSColor(srgbRed: 0.11, green: 0.11, blue: 0.14, alpha: 1), y: 44)

    // Arrow between the two icons.
    let accent = NSColor(srgbRed: 0.48, green: 0.42, blue: 1, alpha: 1)
    g.setStrokeColor(accent.cgColor); g.setLineWidth(5); g.setLineCap(.round); g.setLineJoin(.round)
    let y = tolio.y - 4
    g.move(to: CGPoint(x: tolio.x + 86, y: y)); g.addLine(to: CGPoint(x: apps.x - 86, y: y)); g.strokePath()
    g.move(to: CGPoint(x: apps.x - 104, y: y - 16)); g.addLine(to: CGPoint(x: apps.x - 86, y: y)); g.addLine(to: CGPoint(x: apps.x - 104, y: y + 16)); g.strokePath()

    // First-launch hint.
    let muted = NSColor(srgbRed: 0.36, green: 0.35, blue: 0.45, alpha: 1)
    text("First time? Open Tolio, then allow it once:", size: 12.5, weight: .medium, color: muted, y: 326)
    text("System Settings → Privacy & Security → Open Anyway", size: 12.5, weight: .semibold, color: accent.blended(withFraction: 0.25, of: .black)!, y: 346)

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
try! draw(scale: 1).write(to: URL(fileURLWithPath: out + "/background.png"))
try! draw(scale: 2).write(to: URL(fileURLWithPath: out + "/background@2x.png"))
print("ok")
