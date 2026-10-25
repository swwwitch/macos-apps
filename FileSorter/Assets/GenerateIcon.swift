import AppKit
// Mustard base shared with the other apps (same as KeynoteSweeper / SettingsHop). Motif: a document dropping into one of two folders.
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
func soft(_ draw: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let s = NSShadow(); s.shadowColor = NSColor.black.withAlphaComponent(0.18); s.shadowBlurRadius = 14; s.shadowOffset = NSSize(width: 0, height: -6); s.set()
    draw(); NSGraphicsContext.restoreGraphicsState()
}
// Two folders at the bottom.
func folder(_ x: CGFloat) {
    let p = NSBezierPath()
    p.move(to: NSPoint(x: x, y: 210)); p.line(to: NSPoint(x: x, y: 410)); p.line(to: NSPoint(x: x + 100, y: 410)); p.line(to: NSPoint(x: x + 130, y: 380))
    p.line(to: NSPoint(x: x + 300, y: 380)); p.line(to: NSPoint(x: x + 300, y: 210)); p.close(); p.lineJoinStyle = .round
    soft { cream.setFill(); p.fill() }
    brown.setStroke(); p.lineWidth = 22; p.stroke()
}
folder(170); folder(554)
// Document at the top.
let doc = NSBezierPath(roundedRect: NSRect(x: 412, y: 600, width: 200, height: 250), xRadius: 28, yRadius: 28)
soft { cream.setFill(); doc.fill() }
brown.setStroke(); doc.lineWidth = 22; doc.stroke()
brown.setFill()
for (i, w) in [120.0, 90, 120].enumerated() { NSBezierPath(roundedRect: NSRect(x: 452, y: 780 - CGFloat(i) * 50, width: CGFloat(w), height: 22), xRadius: 11, yRadius: 11).fill() }
// Arrows to both folders.
for (endX, c1x) in [(320.0, 420.0), (704.0, 604.0)] {
    let a = NSBezierPath(); a.lineWidth = 32; a.lineCapStyle = .round
    a.move(to: NSPoint(x: 512, y: 570)); a.curve(to: NSPoint(x: endX, y: 470), controlPoint1: NSPoint(x: 512, y: 520), controlPoint2: NSPoint(x: c1x, y: 470))
    brown.setStroke(); a.stroke()
    let dir: CGFloat = endX < 512 ? -1 : 1
    let h = NSBezierPath(); h.move(to: NSPoint(x: endX + dir * 40, y: 470)); h.line(to: NSPoint(x: endX - dir * 20, y: 510)); h.line(to: NSPoint(x: endX - dir * 20, y: 430)); h.close()
    h.lineJoinStyle = .round; h.lineWidth = 14; h.fill(); h.stroke()
}
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("FileSorter.png"))
