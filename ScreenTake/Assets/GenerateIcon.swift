import AppKit
// Mustard base shared with the other apps (same as SettingsHop). Motif: a screen with a record dot above a timeline strip.
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

// Screen: cream display with a brown frame.
let screen = NSBezierPath(roundedRect: NSRect(x: 200, y: 400, width: 624, height: 400), xRadius: 44, yRadius: 44)
NSGraphicsContext.saveGraphicsState()
let screenShadow = NSShadow(); screenShadow.shadowColor = NSColor.black.withAlphaComponent(0.2); screenShadow.shadowBlurRadius = 16; screenShadow.shadowOffset = NSSize(width: 0, height: -8); screenShadow.set()
cream.setFill(); screen.fill()
NSGraphicsContext.restoreGraphicsState()
brown.setStroke(); screen.lineWidth = 26; screen.stroke()
// Record dot.
NSColor(srgbRed: 0.85, green: 0.2, blue: 0.13, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 422, y: 510, width: 180, height: 180)).fill()
// Timeline strip: brown bar with clips and a playhead.
brown.setFill(); NSBezierPath(roundedRect: NSRect(x: 200, y: 220, width: 624, height: 120), xRadius: 30, yRadius: 30).fill()
cream.setFill()
for (x, w) in [(232.0, 200.0), (452, 140), (612, 180)] { NSBezierPath(roundedRect: NSRect(x: x, y: 248, width: w, height: 64), xRadius: 16, yRadius: 16).fill() }
NSColor(srgbRed: 0.85, green: 0.2, blue: 0.13, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 520, y: 196, width: 18, height: 168), xRadius: 9, yRadius: 9).fill()
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("ScreenTake.png"))
