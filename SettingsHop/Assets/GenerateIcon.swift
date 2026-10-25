import AppKit
// Mustard base shared with the other apps (same as KeynoteSweeper). Motif: a gear with a hopping arrow landing on it.
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

// Gear (lower right): teeth around a ring, cream fill with a brown outline.
let center = NSPoint(x: 590, y: 420)
let teeth = 8, outer = 250.0, inner = 200.0
let gear = NSBezierPath()
for i in 0..<(teeth * 4) {
    let angle = Double(i) / Double(teeth * 4) * 2 * .pi + .pi / Double(teeth * 4)
    let r = (i % 4 == 0 || i % 4 == 1) ? outer : inner
    let p = NSPoint(x: center.x + CGFloat(cos(angle) * r), y: center.y + CGFloat(sin(angle) * r))
    i == 0 ? gear.move(to: p) : gear.line(to: p)
}
gear.close(); gear.lineJoinStyle = .round
NSGraphicsContext.saveGraphicsState()
let gearShadow = NSShadow(); gearShadow.shadowColor = NSColor.black.withAlphaComponent(0.18); gearShadow.shadowBlurRadius = 14; gearShadow.shadowOffset = NSSize(width: 0, height: -6); gearShadow.set()
cream.setFill(); gear.fill()
NSGraphicsContext.restoreGraphicsState()
brown.setStroke(); gear.lineWidth = 22; gear.stroke()
let hub = NSBezierPath(ovalIn: NSRect(x: center.x - 80, y: center.y - 80, width: 160, height: 160))
hub.lineWidth = 22; hub.stroke()

// Hopping arrow: an arc from the upper left that lands on the gear.
let arc = NSBezierPath()
arc.move(to: NSPoint(x: 210, y: 560))
arc.curve(to: NSPoint(x: 560, y: 720), controlPoint1: NSPoint(x: 220, y: 800), controlPoint2: NSPoint(x: 470, y: 840))
arc.lineWidth = 40; arc.lineCapStyle = .round; brown.setStroke(); arc.stroke()
let head = NSBezierPath()
head.move(to: NSPoint(x: 610, y: 650)); head.line(to: NSPoint(x: 470, y: 690)); head.line(to: NSPoint(x: 580, y: 790)); head.close()
head.lineJoinStyle = .round; head.lineWidth = 18; brown.setFill(); head.fill(); head.stroke()
// Take-off dot.
NSBezierPath(ovalIn: NSRect(x: 180, y: 470, width: 60, height: 60)).fill()
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("SettingsHop.png"))
