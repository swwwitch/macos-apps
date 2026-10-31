import AppKit
// PasteInARow icon: the family's mustard tile (as in Shared/DesignAssets/app-icons-mustard-final.png),
// a white sheet with brown text lines whose top line is highlighted, and a brown badge with a white arrow —
// one line taken from the top and pasted, press after press.
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

// Sheet with five text lines; the first one sits in a mustard highlight.
let card = NSRect(x: 170, y: 230, width: 600, height: 590)
let cardPath = NSBezierPath(roundedRect: card, xRadius: 52, yRadius: 52)
NSGraphicsContext.saveGraphicsState()
let cardShadow = NSShadow(); cardShadow.shadowColor = brown.withAlphaComponent(0.25)
cardShadow.shadowBlurRadius = 12; cardShadow.shadowOffset = NSSize(width: 0, height: -9); cardShadow.set()
white.setFill(); cardPath.fill()
NSGraphicsContext.restoreGraphicsState()
brown.setStroke(); cardPath.lineWidth = 22; cardPath.stroke()

let left = card.minX + 80
let widths: [CGFloat] = [400, 330, 380, 280, 340]
let top = card.maxY - 110
let step: CGFloat = 95
let highlight = NSBezierPath(roundedRect: NSRect(x: card.minX + 40, y: top - 42, width: card.width - 80, height: 84), xRadius: 22, yRadius: 22)
mustard.setFill(); highlight.fill()
for (i, width) in widths.enumerated() {
    let y = top - step * CGFloat(i)
    line(NSPoint(x: left, y: y), NSPoint(x: left + width, y: y), width: 30, color: i == 0 ? brown : brown.withAlphaComponent(0.55))
}

// Three rising baton strokes signify the three coordinated paste modes.
for (i, y) in [CGFloat(230), 305, 380].enumerated() {
 line(NSPoint(x: 650, y: y), NSPoint(x: 850, y: y + CGFloat(i * 14)), width: 28, color: brown)
}
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
