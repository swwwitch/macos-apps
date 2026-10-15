import AppKit
// Usage: swift GenerateIcon.swift <output folder>  → ListMatch.png (1024px)
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
// Mustard tile shared with the other sw_app icons.
let box = NSBezierPath(roundedRect: NSRect(x: 80, y: 80, width: 864, height: 864), xRadius: 220, yRadius: 220)
let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.23); shadow.shadowBlurRadius = 18; shadow.shadowOffset = NSSize(width: 0, height: -7)
NSGraphicsContext.saveGraphicsState(); shadow.set()
NSGradient(starting: NSColor(srgbRed: 1, green: 0.84, blue: 0.19, alpha: 1), ending: NSColor(srgbRed: 0.93, green: 0.69, blue: 0.055, alpha: 1))!.draw(in: box, angle: -75)
NSGraphicsContext.restoreGraphicsState()
NSColor.white.withAlphaComponent(0.35).setStroke(); box.lineWidth = 5; box.stroke()
let brown = NSColor(srgbRed: 0.38, green: 0.27, blue: 0.09, alpha: 1)
let paper = NSColor(srgbRed: 1, green: 0.985, blue: 0.95, alpha: 1)
// Two lists side by side. Shared lines are faint; the line only on one side is solid with a dot.
func sheet(x: CGFloat, unique: Int) {
    let rect = NSRect(x: x, y: 230, width: 300, height: 564)
    let path = NSBezierPath(roundedRect: rect, xRadius: 40, yRadius: 40)
    NSGraphicsContext.saveGraphicsState(); shadow.set(); paper.setFill(); path.fill(); NSGraphicsContext.restoreGraphicsState()
    brown.setStroke(); path.lineWidth = 16; path.stroke()
    for row in 0..<5 {
        let y = rect.maxY - 110 - CGFloat(row) * 96
        let line = NSBezierPath(roundedRect: NSRect(x: x + 92, y: y, width: 168, height: 36), xRadius: 18, yRadius: 18)
        let dot = NSBezierPath(ovalIn: NSRect(x: x + 40, y: y - 2, width: 40, height: 40))
        if row == unique {
            brown.setFill(); line.fill(); dot.fill()
        } else {
            brown.withAlphaComponent(0.32).setFill(); line.fill(); dot.fill()
        }
    }
}
sheet(x: 190, unique: 1)
sheet(x: 534, unique: 3)
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("ListMatch.png"))
