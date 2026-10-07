import AppKit
// Mustard base shared with the other apps. Motif: a PDF page flowing onto a slide screen on a stand.
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

// PDF page with a folded corner (upper left).
let page = NSBezierPath()
page.move(to: NSPoint(x: 200, y: 830)); page.line(to: NSPoint(x: 390, y: 830)); page.line(to: NSPoint(x: 470, y: 750))
page.line(to: NSPoint(x: 470, y: 470)); page.line(to: NSPoint(x: 200, y: 470)); page.close()
page.lineJoinStyle = .round
cream.setFill(); page.fill(); brown.setStroke(); page.lineWidth = 14; page.stroke()
let fold = NSBezierPath(); fold.move(to: NSPoint(x: 390, y: 830)); fold.line(to: NSPoint(x: 390, y: 750)); fold.line(to: NSPoint(x: 470, y: 750))
fold.lineWidth = 14; fold.lineJoinStyle = .round; fold.stroke()
for (y, w) in [(690.0, 160.0), (640.0, 210.0), (590.0, 210.0), (540.0, 140.0)] {
    let line = NSBezierPath(); line.move(to: NSPoint(x: 245, y: y)); line.line(to: NSPoint(x: 245 + w, y: y))
    line.lineWidth = 18; line.lineCapStyle = .round; line.stroke()
}

// Slide screen on a stand (lower right).
let legs = NSBezierPath()
legs.move(to: NSPoint(x: 640, y: 330)); legs.line(to: NSPoint(x: 560, y: 160))
legs.move(to: NSPoint(x: 640, y: 330)); legs.line(to: NSPoint(x: 720, y: 160))
legs.lineWidth = 30; legs.lineCapStyle = .round; brown.setStroke(); legs.stroke()
let screen = NSBezierPath(roundedRect: NSRect(x: 380, y: 300, width: 520, height: 340), xRadius: 30, yRadius: 30)
NSGraphicsContext.saveGraphicsState()
let screenShadow = NSShadow(); screenShadow.shadowColor = NSColor.black.withAlphaComponent(0.18); screenShadow.shadowBlurRadius = 14; screenShadow.shadowOffset = NSSize(width: 0, height: -6); screenShadow.set()
cream.setFill(); screen.fill()
NSGraphicsContext.restoreGraphicsState()
screen.lineWidth = 16; screen.stroke()
// Miniature of the page placed on the slide.
let mini = NSBezierPath(roundedRect: NSRect(x: 560, y: 360, width: 160, height: 220), xRadius: 10, yRadius: 10)
brown.setFill(); mini.fill()
cream.setStroke()
for (y, w) in [(520.0, 90.0), (480.0, 110.0), (440.0, 70.0)] {
    let line = NSBezierPath(); line.move(to: NSPoint(x: 585, y: y)); line.line(to: NSPoint(x: 585 + w, y: y))
    line.lineWidth = 14; line.lineCapStyle = .round; line.stroke()
}
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("PDF2Keynote.png"))
