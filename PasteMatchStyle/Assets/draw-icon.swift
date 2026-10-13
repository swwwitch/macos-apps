import AppKit
// PasteMatchStyle icon: the family's mustard tile (as in Shared/DesignAssets/app-icons-mustard-final.png),
// a white clipboard with plain brown text lines, and a brown badge with a white "T" — the text alone, without its style.
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

// Clipboard: white board with a brown clip and four plain text lines of the same weight.
let card = NSRect(x: 170, y: 200, width: 600, height: 600)
let cardPath = NSBezierPath(roundedRect: card, xRadius: 52, yRadius: 52)
NSGraphicsContext.saveGraphicsState()
let cardShadow = NSShadow(); cardShadow.shadowColor = brown.withAlphaComponent(0.25)
cardShadow.shadowBlurRadius = 12; cardShadow.shadowOffset = NSSize(width: 0, height: -9); cardShadow.set()
white.setFill(); cardPath.fill()
NSGraphicsContext.restoreGraphicsState()
brown.setStroke(); cardPath.lineWidth = 22; cardPath.stroke()
let clip = NSBezierPath(roundedRect: NSRect(x: card.midX - 130, y: card.maxY - 50, width: 260, height: 110), xRadius: 36, yRadius: 36)
brown.setFill(); clip.fill()
let clipHole = NSBezierPath(roundedRect: NSRect(x: card.midX - 60, y: card.maxY + 18, width: 120, height: 26), xRadius: 13, yRadius: 13)
mustard.setFill(); clipHole.fill()
let left = card.minX + 80
let widths: [CGFloat] = [420, 360, 400, 250]
let top = card.maxY - 150
for (i, width) in widths.enumerated() {
    let y = top - 100 * CGFloat(i)
    line(NSPoint(x: left, y: y), NSPoint(x: left + width, y: y), width: 30, color: brown.withAlphaComponent(0.6))
}

// Badge: brown disc with a white "T" (plain text).
let center = NSPoint(x: 740, y: 290)
let radius: CGFloat = 165
let disc = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
NSGraphicsContext.saveGraphicsState()
let discShadow = NSShadow(); discShadow.shadowColor = brown.withAlphaComponent(0.3)
discShadow.shadowBlurRadius = 12; discShadow.shadowOffset = NSSize(width: 0, height: -8); discShadow.set()
brown.setFill(); disc.fill()
NSGraphicsContext.restoreGraphicsState()
white.setStroke(); disc.lineWidth = 16; disc.stroke()
line(NSPoint(x: center.x - 80, y: center.y + 75), NSPoint(x: center.x + 80, y: center.y + 75), width: 44, color: white)
line(NSPoint(x: center.x, y: center.y + 75), NSPoint(x: center.x, y: center.y - 85), width: 44, color: white)

image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
