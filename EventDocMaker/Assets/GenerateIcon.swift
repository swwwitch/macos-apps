import AppKit
// Mustard base shared with the other apps (same as KeynoteSweeper / SettingsHop). Motif: a stack of documents with a calendar tab (event).
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
func sheet(_ rect: NSRect) {
    let p = NSBezierPath(roundedRect: rect, xRadius: 36, yRadius: 36)
    NSGraphicsContext.saveGraphicsState()
    let s = NSShadow(); s.shadowColor = NSColor.black.withAlphaComponent(0.18); s.shadowBlurRadius = 14; s.shadowOffset = NSSize(width: 0, height: -6); s.set()
    cream.setFill(); p.fill()
    NSGraphicsContext.restoreGraphicsState()
    brown.setStroke(); p.lineWidth = 22; p.stroke()
}
// Two sheets behind, one in front.
sheet(NSRect(x: 400, y: 330, width: 360, height: 460))
sheet(NSRect(x: 330, y: 270, width: 360, height: 460))
sheet(NSRect(x: 260, y: 210, width: 360, height: 460))
// Calendar header on the front sheet with two rings.
brown.setFill()
NSBezierPath(roundedRect: NSRect(x: 260, y: 560, width: 360, height: 110), xRadius: 36, yRadius: 36).fill()
NSBezierPath(rect: NSRect(x: 260, y: 560, width: 360, height: 50)).fill()
cream.setFill()
for x in [340.0, 520.0] { NSBezierPath(roundedRect: NSRect(x: x, y: 620, width: 24, height: 80), xRadius: 12, yRadius: 12).fill() }
// Text lines.
brown.setFill()
for (i, w) in [250.0, 200, 230, 150].enumerated() {
    NSBezierPath(roundedRect: NSRect(x: 310, y: 480 - CGFloat(i) * 70, width: CGFloat(w), height: 30), xRadius: 15, yRadius: 15).fill()
}
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("EventDocMaker.png"))
