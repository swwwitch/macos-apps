import AppKit
// Mustard base shared with the other apps. Motif: two keycaps side by side, the same key in two sets, with a mark between them.
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
let box = NSBezierPath(roundedRect: NSRect(x: 80, y: 80, width: 864, height: 864), xRadius: 220, yRadius: 220)
let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.23); shadow.shadowBlurRadius = 18; shadow.shadowOffset = NSSize(width: 0, height: -7)
NSGraphicsContext.saveGraphicsState(); shadow.set()
NSGradient(starting: NSColor(srgbRed: 1, green: 0.84, blue: 0.19, alpha: 1), ending: NSColor(srgbRed: 0.93, green: 0.69, blue: 0.055, alpha: 1))!.draw(in: box, angle: -75)
NSGraphicsContext.restoreGraphicsState()
NSColor.white.withAlphaComponent(0.35).setStroke(); box.lineWidth = 5; box.stroke()
let brown = NSColor(srgbRed: 0.38, green: 0.27, blue: 0.09, alpha: 1)
let cream = NSColor(srgbRed: 1, green: 0.985, blue: 0.95, alpha: 1)
let accent = NSColor(srgbRed: 0.8, green: 0.32, blue: 0.1, alpha: 1)
let softShadow = NSShadow(); softShadow.shadowColor = NSColor.black.withAlphaComponent(0.18); softShadow.shadowBlurRadius = 14; softShadow.shadowOffset = NSSize(width: 0, height: -6)

func keycap(_ rect: NSRect, fill: NSColor, ink: NSColor, glyph: String) {
    let cap = NSBezierPath(roundedRect: rect, xRadius: 62, yRadius: 62)
    NSGraphicsContext.saveGraphicsState(); softShadow.set(); fill.setFill(); cap.fill(); NSGraphicsContext.restoreGraphicsState()
    brown.setStroke(); cap.lineWidth = 22; cap.stroke()
    let top = NSBezierPath(roundedRect: rect.insetBy(dx: 44, dy: 44).offsetBy(dx: 0, dy: 16), xRadius: 34, yRadius: 34)
    ink.withAlphaComponent(0.22).setStroke(); top.lineWidth = 10; top.stroke()
    let font = NSFont.systemFont(ofSize: 176, weight: .bold)
    let text = NSAttributedString(string: glyph, attributes: [.font: font, .foregroundColor: ink])
    let size = text.size()
    text.draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2 + 16))
}

let side: CGFloat = 340
keycap(NSRect(x: 150, y: 342, width: side, height: side), fill: cream, ink: brown, glyph: "⌘")
keycap(NSRect(x: 534, y: 342, width: side, height: side), fill: brown, ink: cream, glyph: "⌘")

// A "not equal" mark below the keys: what the app looks for.
let bars = NSBezierPath()
bars.move(to: NSPoint(x: 410, y: 268)); bars.line(to: NSPoint(x: 614, y: 268))
bars.move(to: NSPoint(x: 410, y: 196)); bars.line(to: NSPoint(x: 614, y: 196))
bars.lineWidth = 34; bars.lineCapStyle = .round; brown.setStroke(); bars.stroke()
let slash = NSBezierPath()
slash.move(to: NSPoint(x: 462, y: 150)); slash.line(to: NSPoint(x: 562, y: 314))
slash.lineWidth = 34; slash.lineCapStyle = .round; accent.setStroke(); slash.stroke()
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("VectorKeyMap.png"))
