import AppKit
// Usage: swift GenerateIcon.swift <output folder>  → LayoutMate.png (1024px)
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
// Mustard tile shared with VectorMate, IdBackgroundOff and the other sw_app icons.
let box = NSBezierPath(roundedRect: NSRect(x: 80, y: 80, width: 864, height: 864), xRadius: 220, yRadius: 220)
let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.23); shadow.shadowBlurRadius = 18; shadow.shadowOffset = NSSize(width: 0, height: -7)
NSGraphicsContext.saveGraphicsState(); shadow.set()
NSGradient(starting: NSColor(srgbRed: 1, green: 0.84, blue: 0.19, alpha: 1), ending: NSColor(srgbRed: 0.93, green: 0.69, blue: 0.055, alpha: 1))!.draw(in: box, angle: -75)
NSGraphicsContext.restoreGraphicsState()
NSColor.white.withAlphaComponent(0.35).setStroke(); box.lineWidth = 5; box.stroke()
let brown = NSColor(srgbRed: 0.38, green: 0.27, blue: 0.09, alpha: 1)
let paper = NSColor(srgbRed: 1, green: 0.985, blue: 0.95, alpha: 1)
// A two-page spread (InDesign's facing pages): a placeholder frame on the left page, text lines on the right.
let pages = NSBezierPath(rect: NSRect(x: 196, y: 262, width: 632, height: 500))
NSGraphicsContext.saveGraphicsState(); shadow.set(); paper.setFill(); pages.fill(); NSGraphicsContext.restoreGraphicsState()
brown.setStroke(); pages.lineWidth = 22; pages.lineJoinStyle = .round; pages.stroke()
let spine = NSBezierPath(); spine.move(to: NSPoint(x: 512, y: 262)); spine.line(to: NSPoint(x: 512, y: 762))
spine.lineWidth = 16; spine.stroke()
// Left page: an empty graphics frame with its diagonal cross, and a caption line.
let frame = NSBezierPath(rect: NSRect(x: 262, y: 452, width: 186, height: 236))
frame.lineWidth = 16; frame.stroke()
let cross = NSBezierPath()
cross.move(to: NSPoint(x: 262, y: 452)); cross.line(to: NSPoint(x: 448, y: 688))
cross.move(to: NSPoint(x: 262, y: 688)); cross.line(to: NSPoint(x: 448, y: 452))
cross.lineWidth = 10; cross.stroke()
func line(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat) {
    let path = NSBezierPath(); path.move(to: NSPoint(x: x, y: y)); path.line(to: NSPoint(x: x + width, y: y))
    path.lineWidth = 26; path.lineCapStyle = .round; brown.setStroke(); path.stroke()
}
line(270, 360, 170)
// Right page: a heading and text lines.
line(578, 670, 186)
for (index, width) in [CGFloat(186), 186, 186, 120].enumerated() { line(578, 588 - CGFloat(index) * 76, width) }
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("LayoutMate.png"))
