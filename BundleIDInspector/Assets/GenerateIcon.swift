import AppKit
// Usage: swift GenerateIcon.swift <output folder>  → BundleIDInspector.png (1024px)
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
// Mustard tile shared with the other sw_app icons (same as IdBackgroundOff).
let box = NSBezierPath(roundedRect: NSRect(x: 80, y: 80, width: 864, height: 864), xRadius: 220, yRadius: 220)
let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.23); shadow.shadowBlurRadius = 18; shadow.shadowOffset = NSSize(width: 0, height: -7)
NSGraphicsContext.saveGraphicsState(); shadow.set()
NSGradient(starting: NSColor(srgbRed: 1, green: 0.84, blue: 0.19, alpha: 1), ending: NSColor(srgbRed: 0.93, green: 0.69, blue: 0.055, alpha: 1))!.draw(in: box, angle: -75)
NSGraphicsContext.restoreGraphicsState()
NSColor.white.withAlphaComponent(0.35).setStroke(); box.lineWidth = 5; box.stroke()
let brown = NSColor(srgbRed: 0.38, green: 0.27, blue: 0.09, alpha: 1)
let paper = NSColor(srgbRed: 1, green: 0.985, blue: 0.95, alpha: 1)
// App tile: the inspected application.
let tile = NSBezierPath(roundedRect: NSRect(x: 215, y: 300, width: 470, height: 470), xRadius: 110, yRadius: 110)
NSGraphicsContext.saveGraphicsState(); shadow.set(); paper.setFill(); tile.fill(); NSGraphicsContext.restoreGraphicsState()
brown.setStroke(); tile.lineWidth = 17; tile.stroke()
// "ID" names what the app reads.
let label = NSAttributedString(string: "ID", attributes: [.font: NSFont.systemFont(ofSize: 250, weight: .heavy), .foregroundColor: brown, .kern: -4])
let labelSize = label.size()
label.draw(at: NSPoint(x: 450 - labelSize.width / 2, y: 545 - labelSize.height / 2))
// Magnifying glass over the lower right corner.
let lens = NSRect(x: 520, y: 215, width: 250, height: 250)
let handle = NSBezierPath(); handle.move(to: NSPoint(x: 735, y: 250)); handle.line(to: NSPoint(x: 850, y: 135))
handle.lineWidth = 62; handle.lineCapStyle = .round; brown.setStroke(); handle.stroke()
NSGraphicsContext.saveGraphicsState(); shadow.set(); paper.setFill(); NSBezierPath(ovalIn: lens).fill(); NSGraphicsContext.restoreGraphicsState()
let ring = NSBezierPath(ovalIn: lens); ring.lineWidth = 34; ring.stroke()
NSColor(srgbRed: 0.93, green: 0.69, blue: 0.055, alpha: 0.35).setFill(); NSBezierPath(ovalIn: lens.insetBy(dx: 40, dy: 40)).fill()
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("BundleIDInspector.png"))
