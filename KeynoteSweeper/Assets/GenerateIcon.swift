import AppKit
// Mustard base shared with the other apps (same as PDF2Keynote). Motif: a broom sweeping a slide screen on a stand.
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

// Slide screen on a stand (upper left).
let legs = NSBezierPath()
legs.move(to: NSPoint(x: 430, y: 470)); legs.line(to: NSPoint(x: 350, y: 290))
legs.move(to: NSPoint(x: 430, y: 470)); legs.line(to: NSPoint(x: 510, y: 290))
legs.lineWidth = 30; legs.lineCapStyle = .round; brown.setStroke(); legs.stroke()
let screen = NSBezierPath(roundedRect: NSRect(x: 190, y: 450, width: 480, height: 330), xRadius: 30, yRadius: 30)
NSGraphicsContext.saveGraphicsState()
let screenShadow = NSShadow(); screenShadow.shadowColor = NSColor.black.withAlphaComponent(0.18); screenShadow.shadowBlurRadius = 14; screenShadow.shadowOffset = NSSize(width: 0, height: -6); screenShadow.set()
cream.setFill(); screen.fill()
NSGraphicsContext.restoreGraphicsState()
screen.lineWidth = 16; screen.stroke()
// Title bar and a few lines on the slide.
brown.setStroke()
for (y, w, width) in [(700.0, 250.0, 26.0), (630.0, 330.0, 16.0), (580.0, 280.0, 16.0), (530.0, 200.0, 16.0)] {
    let line = NSBezierPath(); line.move(to: NSPoint(x: 260, y: y)); line.line(to: NSPoint(x: 260 + w, y: y))
    line.lineWidth = width; line.lineCapStyle = .round; line.stroke()
}

// Broom (lower right), handle leaning up to the right.
let handle = NSBezierPath(); handle.move(to: NSPoint(x: 640, y: 380)); handle.line(to: NSPoint(x: 850, y: 800))
handle.lineWidth = 34; handle.lineCapStyle = .round; brown.setStroke(); handle.stroke()
// Bristles: a fan below the handle's foot, rotated with the handle.
NSGraphicsContext.saveGraphicsState()
let transform = NSAffineTransform(); transform.translateX(by: 640, yBy: 380); transform.rotate(byDegrees: -26.6); transform.concat()
let head = NSBezierPath(roundedRect: NSRect(x: -70, y: -40, width: 140, height: 60), xRadius: 18, yRadius: 18)
brown.setFill(); head.fill()
let fan = NSBezierPath()
fan.move(to: NSPoint(x: -70, y: -30)); fan.line(to: NSPoint(x: 70, y: -30))
fan.line(to: NSPoint(x: 120, y: -230)); fan.line(to: NSPoint(x: -120, y: -230)); fan.close()
fan.lineJoinStyle = .round
cream.setFill(); fan.fill(); fan.lineWidth = 16; brown.setStroke(); fan.stroke()
for x in [-60.0, -20.0, 20.0, 60.0] {
    let stroke = NSBezierPath(); stroke.move(to: NSPoint(x: x * 0.9, y: -60)); stroke.line(to: NSPoint(x: x * 1.6, y: -200))
    stroke.lineWidth = 12; stroke.lineCapStyle = .round; stroke.stroke()
}
NSGraphicsContext.restoreGraphicsState()
// Swept-away dust.
brown.setFill()
for (x, y, r) in [(250.0, 210.0, 20.0), (320.0, 180.0, 14.0), (205.0, 260.0, 12.0)] {
    NSBezierPath(ovalIn: NSRect(x: x - r, y: y - r, width: r * 2, height: r * 2)).fill()
}
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("KeynoteSweeper.png"))
