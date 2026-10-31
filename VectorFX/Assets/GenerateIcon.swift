import AppKit
// Mustard base shared with the other apps (same as VectorMaestro). Motif: an object card with a drop shadow and "fx" (Illustrator effects) on it.
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
let softShadow = NSShadow(); softShadow.shadowColor = NSColor.black.withAlphaComponent(0.18); softShadow.shadowBlurRadius = 14; softShadow.shadowOffset = NSSize(width: 0, height: -6)

// Shadow card (the drop shadow effect) behind the object card.
let shadowCard = NSBezierPath(roundedRect: NSRect(x: 290, y: 190, width: 520, height: 520), xRadius: 90, yRadius: 90)
brown.withAlphaComponent(0.42).setFill(); shadowCard.fill()
let card = NSBezierPath(roundedRect: NSRect(x: 214, y: 290, width: 520, height: 520), xRadius: 90, yRadius: 90)
NSGraphicsContext.saveGraphicsState(); softShadow.set(); cream.setFill(); card.fill(); NSGraphicsContext.restoreGraphicsState()
brown.setStroke(); card.lineWidth = 22; card.stroke()
// "fx" on the card.
let font = NSFontManager.shared.convert(NSFont.systemFont(ofSize: 330, weight: .heavy), toHaveTrait: .italicFontMask)
let fx = NSAttributedString(string: "fx", attributes: [.font: font, .foregroundColor: brown, .kern: -6])
let size = fx.size()
fx.draw(at: NSPoint(x: 474 - size.width / 2, y: 545 - size.height / 2))
// Sparkle at the upper right (the effect being applied).
func sparkle(_ c: NSPoint, _ r: CGFloat) {
    let p = NSBezierPath(); let k = r * 0.28
    p.move(to: NSPoint(x: c.x, y: c.y + r)); p.curve(to: NSPoint(x: c.x + r, y: c.y), controlPoint1: NSPoint(x: c.x + k, y: c.y + k), controlPoint2: NSPoint(x: c.x + k, y: c.y + k))
    p.curve(to: NSPoint(x: c.x, y: c.y - r), controlPoint1: NSPoint(x: c.x + k, y: c.y - k), controlPoint2: NSPoint(x: c.x + k, y: c.y - k))
    p.curve(to: NSPoint(x: c.x - r, y: c.y), controlPoint1: NSPoint(x: c.x - k, y: c.y - k), controlPoint2: NSPoint(x: c.x - k, y: c.y - k))
    p.curve(to: NSPoint(x: c.x, y: c.y + r), controlPoint1: NSPoint(x: c.x - k, y: c.y + k), controlPoint2: NSPoint(x: c.x - k, y: c.y + k)); p.close()
    NSGraphicsContext.saveGraphicsState(); softShadow.set(); cream.setFill(); p.fill(); NSGraphicsContext.restoreGraphicsState()
    brown.setStroke(); p.lineWidth = 14; p.lineJoinStyle = .round; p.stroke()
}
sparkle(NSPoint(x: 770, y: 790), 112)
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("VectorFX.png"))
