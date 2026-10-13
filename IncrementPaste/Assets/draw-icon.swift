import AppKit
// IncrementPaste icon: the family's mustard tile (as in Shared/DesignAssets/app-icons-mustard-final.png),
// a white card with a large brown number on a mustard highlight, and a brown badge with a white plus —
// the number on the clipboard counted up at each paste.
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

func line(_ a: NSPoint, _ b: NSPoint, width: CGFloat, color: NSColor = brown, cap: NSBezierPath.LineCapStyle = .round) {
    let p = NSBezierPath(); p.move(to: a); p.line(to: b)
    p.lineWidth = width; p.lineCapStyle = cap; color.setStroke(); p.stroke()
}

// Card with a large number on a mustard highlight.
let card = NSRect(x: 170, y: 230, width: 600, height: 590)
let cardPath = NSBezierPath(roundedRect: card, xRadius: 52, yRadius: 52)
NSGraphicsContext.saveGraphicsState()
let cardShadow = NSShadow(); cardShadow.shadowColor = brown.withAlphaComponent(0.25)
cardShadow.shadowBlurRadius = 12; cardShadow.shadowOffset = NSSize(width: 0, height: -9); cardShadow.set()
white.setFill(); cardPath.fill()
NSGraphicsContext.restoreGraphicsState()
brown.setStroke(); cardPath.lineWidth = 22; cardPath.stroke()

let highlight = NSBezierPath(roundedRect: NSRect(x: card.minX + 70, y: card.minY + 110, width: card.width - 140, height: 360), xRadius: 40, yRadius: 40)
mustard.setFill(); highlight.fill()
let font = NSFont.systemFont(ofSize: 400, weight: .heavy).fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 400) } ?? NSFont.systemFont(ofSize: 400, weight: .heavy)
let digit = NSAttributedString(string: "1", attributes: [.font: font, .foregroundColor: brown])
let size = digit.size()
digit.draw(at: NSPoint(x: card.midX - size.width / 2 - 20, y: highlight.bounds.midY - size.height / 2 + 6))
// Two short lines above the number, like the text around it.
line(NSPoint(x: card.minX + 90, y: card.maxY - 75), NSPoint(x: card.minX + 330, y: card.maxY - 75), width: 26, color: brown.withAlphaComponent(0.55))
line(NSPoint(x: card.minX + 90, y: card.minY + 60), NSPoint(x: card.minX + 260, y: card.minY + 60), width: 26, color: brown.withAlphaComponent(0.55))

// Badge: brown disc with a white plus.
let center = NSPoint(x: 740, y: 300)
let radius: CGFloat = 165
let disc = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
NSGraphicsContext.saveGraphicsState()
let discShadow = NSShadow(); discShadow.shadowColor = brown.withAlphaComponent(0.3)
discShadow.shadowBlurRadius = 12; discShadow.shadowOffset = NSSize(width: 0, height: -8); discShadow.set()
brown.setFill(); disc.fill()
NSGraphicsContext.restoreGraphicsState()
white.setStroke(); disc.lineWidth = 16; disc.stroke()
line(NSPoint(x: center.x - 80, y: center.y), NSPoint(x: center.x + 80, y: center.y), width: 48, color: white)
line(NSPoint(x: center.x, y: center.y - 80), NSPoint(x: center.x, y: center.y + 80), width: 48, color: white)

image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
