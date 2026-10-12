import AppKit
// Usage: swift GenerateIcon.swift <output folder>  → HotkeyHound.png (1024px)
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
// Mustard tile shared with the other sw_app icons (same as BundleIDInspector).
let box = NSBezierPath(roundedRect: NSRect(x: 54, y: 54, width: 916, height: 916), xRadius: 220, yRadius: 220)
let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.10); shadow.shadowBlurRadius = 0; shadow.shadowOffset = NSSize(width: 0, height: -12)
NSGraphicsContext.saveGraphicsState(); shadow.set()
NSGradient(starting: NSColor(srgbRed: 0.99, green: 0.79, blue: 0.095, alpha: 1), ending: NSColor(srgbRed: 0.97, green: 0.75, blue: 0.075, alpha: 1))!.draw(in: box, angle: -75)
NSGraphicsContext.restoreGraphicsState()
let brown = NSColor(srgbRed: 0.36, green: 0.25, blue: 0.085, alpha: 1)
let paper = NSColor(srgbRed: 1, green: 0.985, blue: 0.95, alpha: 1)
// Keycap: a cream key with a thicker lower edge.
let capBase = NSBezierPath(roundedRect: NSRect(x: 205, y: 290, width: 490, height: 490), xRadius: 105, yRadius: 105)
NSGraphicsContext.saveGraphicsState(); shadow.set(); NSColor(srgbRed: 0.90, green: 0.86, blue: 0.78, alpha: 1).setFill(); capBase.fill(); NSGraphicsContext.restoreGraphicsState()
let capTop = NSBezierPath(roundedRect: NSRect(x: 235, y: 335, width: 430, height: 425), xRadius: 85, yRadius: 85)
paper.setFill(); capTop.fill()
// ⌘ names what the app looks up.
let label = NSAttributedString(string: "⌘", attributes: [.font: NSFont.systemFont(ofSize: 300, weight: .bold), .foregroundColor: brown])
let labelSize = label.size()
label.draw(at: NSPoint(x: 450 - labelSize.width / 2, y: 548 - labelSize.height / 2))
// Magnifying glass over the lower right corner.
let lens = NSRect(x: 530, y: 205, width: 250, height: 250)
let handle = NSBezierPath(); handle.move(to: NSPoint(x: 745, y: 240)); handle.line(to: NSPoint(x: 860, y: 125))
handle.lineWidth = 62; handle.lineCapStyle = .round; brown.setStroke(); handle.stroke()
NSGraphicsContext.saveGraphicsState(); shadow.set(); paper.setFill(); NSBezierPath(ovalIn: lens).fill(); NSGraphicsContext.restoreGraphicsState()
let ring = NSBezierPath(ovalIn: lens); ring.lineWidth = 34; ring.stroke()
NSColor(srgbRed: 0.93, green: 0.69, blue: 0.055, alpha: 0.35).setFill(); NSBezierPath(ovalIn: lens.insetBy(dx: 40, dy: 40)).fill()
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("HotkeyHound.png"))
