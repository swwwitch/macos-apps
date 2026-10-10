import AppKit
// Usage: swift GenerateIcon.swift <output folder>  → BundleIDInspector.png (1024px)
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
// Mustard tile shared with the other sw_app icons (same as IdBackgroundOff).
let box = NSBezierPath(roundedRect: NSRect(x: 54, y: 54, width: 916, height: 916), xRadius: 220, yRadius: 220)
let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.10); shadow.shadowBlurRadius = 0; shadow.shadowOffset = NSSize(width: 0, height: -12)
NSGraphicsContext.saveGraphicsState(); shadow.set()
NSGradient(starting: NSColor(srgbRed: 0.99, green: 0.79, blue: 0.095, alpha: 1), ending: NSColor(srgbRed: 0.97, green: 0.75, blue: 0.075, alpha: 1))!.draw(in: box, angle: -75)
NSGraphicsContext.restoreGraphicsState()
// No glossy rim: matches the existing flat mustard icon family.
let brown = NSColor(srgbRed: 0.36, green: 0.25, blue: 0.085, alpha: 1)
let paper = NSColor(srgbRed: 1, green: 0.985, blue: 0.95, alpha: 1)
// App tile: the inspected application.
let tile = NSBezierPath(roundedRect: NSRect(x: 215, y: 300, width: 470, height: 470), xRadius: 110, yRadius: 110)
NSGraphicsContext.saveGraphicsState(); shadow.set(); paper.setFill(); tile.fill(); NSGraphicsContext.restoreGraphicsState()
brown.setStroke(); tile.lineWidth = 0; // Cream app tile without a heavy outer outline.
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
