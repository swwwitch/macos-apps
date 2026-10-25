import AppKit
// Mustard base shared with the other apps (same as SettingsHop). Motif: a menu hanging from the menu bar inside viewfinder corners.
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

// Menu bar: a brown strip with a cream highlighted title.
let barRect = NSRect(x: 230, y: 650, width: 564, height: 70)
brown.setFill(); NSBezierPath(roundedRect: barRect, xRadius: 18, yRadius: 18).fill()
cream.setFill(); NSBezierPath(roundedRect: NSRect(x: 300, y: 664, width: 150, height: 42), xRadius: 21, yRadius: 21).fill()

// The menu hanging below the highlighted title.
let menu = NSBezierPath(roundedRect: NSRect(x: 290, y: 270, width: 330, height: 360), xRadius: 34, yRadius: 34)
NSGraphicsContext.saveGraphicsState()
let menuShadow = NSShadow(); menuShadow.shadowColor = NSColor.black.withAlphaComponent(0.2); menuShadow.shadowBlurRadius = 16; menuShadow.shadowOffset = NSSize(width: 0, height: -8); menuShadow.set()
cream.setFill(); menu.fill()
NSGraphicsContext.restoreGraphicsState()
brown.setStroke(); menu.lineWidth = 16; menu.stroke()
// Items: one selected row, then plain lines.
brown.setFill(); NSBezierPath(roundedRect: NSRect(x: 314, y: 540, width: 282, height: 56), xRadius: 16, yRadius: 16).fill()
for y in [470.0, 400, 330] { NSBezierPath(roundedRect: NSRect(x: 340, y: y, width: y == 400 ? 170 : 220, height: 26), xRadius: 13, yRadius: 13).fill() }

// Viewfinder corners around everything.
let corners = NSBezierPath(); corners.lineWidth = 34; corners.lineCapStyle = .round; corners.lineJoinStyle = .round
let (l, r, b, t, arm): (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat) = (180, 844, 190, 790, 120)
for (x, y, dx, dy) in [(l, t, 1.0, -1.0), (r, t, -1, -1), (l, b, 1, 1), (r, b, -1, 1)] {
    corners.move(to: NSPoint(x: x, y: y + dy * arm)); corners.line(to: NSPoint(x: x, y: y)); corners.line(to: NSPoint(x: x + dx * arm, y: y))
}
brown.setStroke(); corners.stroke()
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("MenuShot.png"))
