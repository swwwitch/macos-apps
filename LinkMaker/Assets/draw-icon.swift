import AppKit
// LinkMaker icon: the family's mustard tile (as CellCopyCleaner), a white browser window with a brown title bar
// and address bar, and a brown badge with a white chain link — the page's title and URL turned into a link.
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

// Browser window card.
let card = NSRect(x: 170, y: 250, width: 620, height: 560)
let cardPath = NSBezierPath(roundedRect: card, xRadius: 52, yRadius: 52)
NSGraphicsContext.saveGraphicsState()
let cardShadow = NSShadow(); cardShadow.shadowColor = brown.withAlphaComponent(0.25)
cardShadow.shadowBlurRadius = 12; cardShadow.shadowOffset = NSSize(width: 0, height: -9); cardShadow.set()
white.setFill(); cardPath.fill()
NSGraphicsContext.restoreGraphicsState()
let barHeight: CGFloat = 130
let bar = card.maxY - barHeight
NSGraphicsContext.saveGraphicsState()
cardPath.addClip()
brown.setFill(); NSRect(x: card.minX, y: bar, width: card.width, height: barHeight).fill()
NSGraphicsContext.restoreGraphicsState()
// Window buttons and the address field in the title bar.
for i in 0..<3 {
    let dot = NSBezierPath(ovalIn: NSRect(x: card.minX + 50 + CGFloat(i) * 52, y: bar + barHeight / 2 - 17, width: 34, height: 34))
    (i == 0 ? mustard : white.withAlphaComponent(0.85)).setFill(); dot.fill()
}
let field = NSBezierPath(roundedRect: NSRect(x: card.minX + 230, y: bar + 36, width: card.width - 280, height: barHeight - 72), xRadius: 29, yRadius: 29)
white.setFill(); field.fill()
line(NSPoint(x: card.minX + 268, y: bar + barHeight / 2), NSPoint(x: card.maxX - 110, y: bar + barHeight / 2), width: 16, color: mustard)
// Page text lines.
for (i, length) in [400.0, 320.0, 240.0].enumerated() {
    let y = bar - 90 - CGFloat(i) * 80
    line(NSPoint(x: card.minX + 70, y: y), NSPoint(x: card.minX + 70 + CGFloat(length), y: y), width: 26)
}
brown.setStroke(); cardPath.lineWidth = 22; cardPath.stroke()

// Badge: brown disc with a white chain link (two rounded links at 45°).
let center = NSPoint(x: 735, y: 300)
let radius: CGFloat = 165
let disc = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
NSGraphicsContext.saveGraphicsState()
let discShadow = NSShadow(); discShadow.shadowColor = brown.withAlphaComponent(0.3)
discShadow.shadowBlurRadius = 12; discShadow.shadowOffset = NSSize(width: 0, height: -8); discShadow.set()
brown.setFill(); disc.fill()
NSGraphicsContext.restoreGraphicsState()
white.setStroke(); disc.lineWidth = 16; disc.stroke()
if let context = NSGraphicsContext.current?.cgContext {
    context.saveGState()
    context.translateBy(x: center.x, y: center.y)
    context.rotate(by: .pi / 4)
    func link(_ dx: CGFloat, _ color: NSColor) {
        let ring = NSBezierPath(roundedRect: NSRect(x: dx - 66, y: -36, width: 132, height: 72), xRadius: 36, yRadius: 36)
        ring.lineWidth = 26; color.setStroke(); ring.stroke()
    }
    // Mustard under, white over; then the mustard again over the upper crossing so the links interlock.
    link(44, mustard)
    link(-44, white)
    NSBezierPath(rect: NSRect(x: -40, y: 8, width: 80, height: 60)).addClip()
    link(44, mustard)
    context.restoreGState()
}

image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
