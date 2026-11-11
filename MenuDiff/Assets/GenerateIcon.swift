import AppKit
// Mustard base shared with the other apps (same as EventDocMaker). Motif: two menus side by side, the right one with a highlighted (changed) row.
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
func panel(_ rect: NSRect, highlight: Int?) {
    let p = NSBezierPath(roundedRect: rect, xRadius: 34, yRadius: 34)
    NSGraphicsContext.saveGraphicsState()
    let s = NSShadow(); s.shadowColor = NSColor.black.withAlphaComponent(0.18); s.shadowBlurRadius = 14; s.shadowOffset = NSSize(width: 0, height: -6); s.set()
    cream.setFill(); p.fill()
    NSGraphicsContext.restoreGraphicsState()
    brown.setStroke(); p.lineWidth = 20; p.stroke()
    // Menu title bar.
    brown.setFill()
    NSBezierPath(roundedRect: NSRect(x: rect.minX, y: rect.maxY - 90, width: rect.width, height: 90), xRadius: 34, yRadius: 34).fill()
    NSBezierPath(rect: NSRect(x: rect.minX, y: rect.maxY - 90, width: rect.width, height: 45)).fill()
    // Rows.
    for i in 0..<5 {
        let y = rect.maxY - 160 - CGFloat(i) * 80
        if i == highlight {
            brown.setFill()
            NSBezierPath(roundedRect: NSRect(x: rect.minX + 26, y: y - 22, width: rect.width - 52, height: 64), xRadius: 18, yRadius: 18).fill()
            cream.setFill()
        } else {
            brown.setFill()
        }
        let w = [170.0, 130, 190, 110, 150][i]
        NSBezierPath(roundedRect: NSRect(x: rect.minX + 50, y: y, width: CGFloat(w), height: 22), xRadius: 11, yRadius: 11).fill()
    }
}
panel(NSRect(x: 190, y: 250, width: 300, height: 540), highlight: nil)
panel(NSRect(x: 534, y: 250, width: 300, height: 540), highlight: 2)
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("MenuDiff.png"))
