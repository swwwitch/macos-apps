import AppKit
// Usage: swift GenerateIcon.swift <output folder>  → SiteMirror.png (1024px)
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
// Mustard tile shared with the other sw_app icons (same as SettingsCourier).
let box = NSBezierPath(roundedRect: NSRect(x: 54, y: 54, width: 916, height: 916), xRadius: 220, yRadius: 220)
let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.10); shadow.shadowBlurRadius = 0; shadow.shadowOffset = NSSize(width: 0, height: -12)
NSGraphicsContext.saveGraphicsState(); shadow.set()
NSGradient(starting: NSColor(srgbRed: 0.99, green: 0.79, blue: 0.095, alpha: 1), ending: NSColor(srgbRed: 0.97, green: 0.75, blue: 0.075, alpha: 1))!.draw(in: box, angle: -75)
NSGraphicsContext.restoreGraphicsState()
let brown = NSColor(srgbRed: 0.36, green: 0.25, blue: 0.085, alpha: 1)
let paper = NSColor(srgbRed: 1, green: 0.985, blue: 0.95, alpha: 1)
let accent = NSColor(srgbRed: 0.93, green: 0.69, blue: 0.055, alpha: 1)
// Browser window: the site being saved.
let frame = NSRect(x: 180, y: 230, width: 600, height: 540)
let window = NSBezierPath(roundedRect: frame, xRadius: 52, yRadius: 52)
NSGraphicsContext.saveGraphicsState(); shadow.set(); paper.setFill(); window.fill(); NSGraphicsContext.restoreGraphicsState()
brown.setStroke(); window.lineWidth = 30; window.stroke()
let bar = NSBezierPath(); bar.move(to: NSPoint(x: frame.minX, y: 660)); bar.line(to: NSPoint(x: frame.maxX, y: 660))
bar.lineWidth = 26; bar.stroke()
for x in [250.0, 310.0, 370.0] {
    brown.setFill(); NSBezierPath(ovalIn: NSRect(x: x - 20, y: 695, width: 40, height: 40)).fill()
}
// Globe inside the window.
let center = NSPoint(x: 450, y: 450)
let radius: CGFloat = 150
let globe = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
globe.lineWidth = 24; globe.stroke()
let meridian = NSBezierPath(ovalIn: NSRect(x: center.x - 62, y: center.y - radius, width: 124, height: radius * 2))
meridian.lineWidth = 20; meridian.stroke()
for (y, half) in [(center.y, radius), (center.y + 75, 130.0), (center.y - 75, 130.0)] {
    let line = NSBezierPath(); line.move(to: NSPoint(x: center.x - half, y: y)); line.line(to: NSPoint(x: center.x + half, y: y))
    line.lineWidth = 20; line.stroke()
}
let axis = NSBezierPath(); axis.move(to: NSPoint(x: center.x, y: center.y - radius)); axis.line(to: NSPoint(x: center.x, y: center.y + radius))
axis.lineWidth = 20; axis.stroke()
// Download badge at the lower right: saved to this Mac.
let badgeRect = NSRect(x: 600, y: 170, width: 270, height: 270)
let badge = NSBezierPath(ovalIn: badgeRect)
NSGraphicsContext.saveGraphicsState(); shadow.set(); accent.setFill(); badge.fill(); NSGraphicsContext.restoreGraphicsState()
brown.setStroke(); badge.lineWidth = 26; badge.stroke()
let arrow = NSBezierPath()
let cx = badgeRect.midX
arrow.move(to: NSPoint(x: cx, y: 390)); arrow.line(to: NSPoint(x: cx, y: 245))
arrow.move(to: NSPoint(x: cx - 62, y: 305)); arrow.line(to: NSPoint(x: cx, y: 240)); arrow.line(to: NSPoint(x: cx + 62, y: 305))
arrow.lineWidth = 38; arrow.lineCapStyle = .round; arrow.lineJoinStyle = .round; arrow.stroke()
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("SiteMirror.png"))
