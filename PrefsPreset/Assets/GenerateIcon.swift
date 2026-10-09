import AppKit
// Usage: swift GenerateIcon.swift <output folder>  → PrefsPreset.png (1024px)
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
let mustard = NSColor(srgbRed: 0.97, green: 0.75, blue: 0.075, alpha: 1)
// Cream settings panel.
let panel = NSBezierPath(roundedRect: NSRect(x: 200, y: 215, width: 624, height: 594), xRadius: 96, yRadius: 96)
NSGraphicsContext.saveGraphicsState(); shadow.set(); paper.setFill(); panel.fill(); NSGraphicsContext.restoreGraphicsState()
// Three sliders: the settings the app reads and applies.
for (y, knobX) in [(660.0, 600.0), (512.0, 400.0), (364.0, 680.0)] {
    let track = NSBezierPath(); track.move(to: NSPoint(x: 300, y: y)); track.line(to: NSPoint(x: 724, y: y))
    track.lineWidth = 38; track.lineCapStyle = .round; brown.setStroke(); track.stroke()
    let knob = NSBezierPath(ovalIn: NSRect(x: knobX - 62, y: y - 62, width: 124, height: 124))
    mustard.setFill(); knob.fill()
    knob.lineWidth = 30; brown.setStroke(); knob.stroke()
}
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("PrefsPreset.png"))
