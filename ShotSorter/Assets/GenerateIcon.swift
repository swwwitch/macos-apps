import AppKit
// Mustard base shared with the other apps (same as KeynoteSweeper / SettingsHop). Motif: a screenshot frame (corner marks)
// around a picture, with a sorting arrow into a tray.
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

// Picture card (upper left) with a mountain and sun.
let card = NSRect(x: 250, y: 430, width: 430, height: 330)
let cardPath = NSBezierPath(roundedRect: card, xRadius: 40, yRadius: 40)
NSGraphicsContext.saveGraphicsState()
let cardShadow = NSShadow(); cardShadow.shadowColor = NSColor.black.withAlphaComponent(0.18); cardShadow.shadowBlurRadius = 14; cardShadow.shadowOffset = NSSize(width: 0, height: -6); cardShadow.set()
cream.setFill(); cardPath.fill()
NSGraphicsContext.restoreGraphicsState()
brown.setStroke(); cardPath.lineWidth = 22; cardPath.stroke()
brown.setFill()
NSBezierPath(ovalIn: NSRect(x: 540, y: 640, width: 70, height: 70)).fill()
let mountain = NSBezierPath()
mountain.move(to: NSPoint(x: 290, y: 470)); mountain.line(to: NSPoint(x: 410, y: 620)); mountain.line(to: NSPoint(x: 480, y: 540))
mountain.line(to: NSPoint(x: 530, y: 590)); mountain.line(to: NSPoint(x: 640, y: 470)); mountain.close()
mountain.lineJoinStyle = .round; mountain.fill()
// Screenshot corner marks around the card.
let pad: CGFloat = 50, len: CGFloat = 90
let outer = card.insetBy(dx: -pad, dy: -pad)
let corners = NSBezierPath(); corners.lineWidth = 30; corners.lineCapStyle = .round; corners.lineJoinStyle = .round
for (x, y, dx, dy) in [(outer.minX, outer.maxY, 1.0, -1.0), (outer.maxX, outer.maxY, -1.0, -1.0), (outer.minX, outer.minY, 1.0, 1.0)] {
    corners.move(to: NSPoint(x: x + CGFloat(dx) * len, y: y)); corners.line(to: NSPoint(x: x, y: y)); corners.line(to: NSPoint(x: x, y: y + CGFloat(dy) * len))
}
corners.stroke()
// Sorting arrow from the lower right corner into a tray.
let arrow = NSBezierPath(); arrow.lineWidth = 34; arrow.lineCapStyle = .round; arrow.lineJoinStyle = .round
arrow.move(to: NSPoint(x: 700, y: 400)); arrow.curve(to: NSPoint(x: 760, y: 280), controlPoint1: NSPoint(x: 760, y: 380), controlPoint2: NSPoint(x: 770, y: 330))
arrow.stroke()
let head = NSBezierPath()
head.move(to: NSPoint(x: 700, y: 300)); head.line(to: NSPoint(x: 760, y: 220)); head.line(to: NSPoint(x: 820, y: 300)); head.close()
head.lineJoinStyle = .round; head.lineWidth = 16; head.fill(); head.stroke()
let tray = NSBezierPath(); tray.lineWidth = 30; tray.lineCapStyle = .round; tray.lineJoinStyle = .round
tray.move(to: NSPoint(x: 640, y: 250)); tray.line(to: NSPoint(x: 640, y: 180)); tray.line(to: NSPoint(x: 880, y: 180)); tray.line(to: NSPoint(x: 880, y: 250))
tray.stroke()
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("ShotSorter.png"))
