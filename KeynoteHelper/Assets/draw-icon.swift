import AppKit
// KeynoteHelper icon: the family's mustard tile (as in Shared/DesignAssets/app-icons-mustard-final.png),
// a white presentation screen on a brown stand with a mustard slide shape, and a brown badge with
// a white ⌘ (system font glyph) — Keynote commands on hotkeys.
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
let rect = NSRect(x: 72, y: 72, width: 880, height: 880)
let path = NSBezierPath(roundedRect: rect, xRadius: 210, yRadius: 210)
let shadow = NSShadow(); shadow.shadowColor = .black.withAlphaComponent(0.2); shadow.shadowBlurRadius = 14; shadow.shadowOffset = NSSize(width: 0, height: -7)
NSGraphicsContext.saveGraphicsState(); shadow.set()
NSColor(calibratedRed: 0.96, green: 0.76, blue: 0.08, alpha: 1).setFill(); path.fill(); NSGraphicsContext.restoreGraphicsState()
NSGradient(starting: NSColor(calibratedRed: 1, green: 0.82, blue: 0.14, alpha: 1), ending: NSColor(calibratedRed: 0.94, green: 0.72, blue: 0.06, alpha: 1))!.draw(in: path, angle: -65)
NSColor.white.withAlphaComponent(0.45).setStroke(); path.lineWidth = 7; path.stroke()

let white = NSColor(calibratedRed: 1, green: 0.995, blue: 0.98, alpha: 1)
let brown = NSColor(calibratedRed: 0.35, green: 0.24, blue: 0.07, alpha: 1)
let mustard = NSColor(calibratedRed: 0.96, green: 0.74, blue: 0.08, alpha: 1)

func line(_ a: NSPoint, _ b: NSPoint, width: CGFloat, color: NSColor = brown) {
    let p = NSBezierPath(); p.move(to: a); p.line(to: b)
    p.lineWidth = width; p.lineCapStyle = .round; color.setStroke(); p.stroke()
}

// Stand: a pole from the screen down to two splayed legs (drawn first, behind the screen).
line(NSPoint(x: 480, y: 330), NSPoint(x: 480, y: 210), width: 34)
line(NSPoint(x: 480, y: 230), NSPoint(x: 380, y: 160), width: 34)
line(NSPoint(x: 480, y: 230), NSPoint(x: 580, y: 160), width: 34)

// Screen: white card, brown frame, a title bar line and a mustard shape like a slide.
let screen = NSRect(x: 170, y: 320, width: 620, height: 480)
let screenPath = NSBezierPath(roundedRect: screen, xRadius: 46, yRadius: 46)
NSGraphicsContext.saveGraphicsState()
let cardShadow = NSShadow(); cardShadow.shadowColor = brown.withAlphaComponent(0.25)
cardShadow.shadowBlurRadius = 12; cardShadow.shadowOffset = NSSize(width: 0, height: -9); cardShadow.set()
white.setFill(); screenPath.fill()
NSGraphicsContext.restoreGraphicsState()
brown.setStroke(); screenPath.lineWidth = 22; screenPath.stroke()
line(NSPoint(x: 250, y: 700), NSPoint(x: 560, y: 700), width: 34)
line(NSPoint(x: 250, y: 620), NSPoint(x: 460, y: 620), width: 22)
let shape = NSBezierPath(roundedRect: NSRect(x: 250, y: 400, width: 250, height: 160), xRadius: 22, yRadius: 22)
mustard.setFill(); shape.fill()

// Badge: brown disc with a white ⌘.
let center = NSPoint(x: 735, y: 300)
let radius: CGFloat = 165
let disc = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
NSGraphicsContext.saveGraphicsState()
let discShadow = NSShadow(); discShadow.shadowColor = brown.withAlphaComponent(0.3)
discShadow.shadowBlurRadius = 12; discShadow.shadowOffset = NSSize(width: 0, height: -8); discShadow.set()
brown.setFill(); disc.fill()
NSGraphicsContext.restoreGraphicsState()
white.setStroke(); disc.lineWidth = 16; disc.stroke()
let font = NSFont.systemFont(ofSize: 230, weight: .bold) as CTFont
var unichar: UniChar = 0x2318
var glyphID: CGGlyph = 0
CTFontGetGlyphsForCharacters(font, &unichar, &glyphID, 1)
if let outline = CTFontCreatePathForGlyph(font, glyphID, nil), let context = NSGraphicsContext.current?.cgContext {
    let box = outline.boundingBoxOfPath
    context.saveGState()
    context.translateBy(x: center.x - box.midX, y: center.y - box.midY)
    context.addPath(outline); context.setFillColor(white.cgColor); context.fillPath()
    context.restoreGState()
}

image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
