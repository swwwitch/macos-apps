import AppKit
// Mustard base shared with the other apps (same as KeynoteSweeper / SettingsHop). Motif: a clipboard with a sparkle (tidied text).
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

// Clipboard board.
let board = NSBezierPath(roundedRect: NSRect(x: 270, y: 210, width: 420, height: 560), xRadius: 56, yRadius: 56)
NSGraphicsContext.saveGraphicsState()
let boardShadow = NSShadow(); boardShadow.shadowColor = NSColor.black.withAlphaComponent(0.18); boardShadow.shadowBlurRadius = 14; boardShadow.shadowOffset = NSSize(width: 0, height: -6); boardShadow.set()
cream.setFill(); board.fill()
NSGraphicsContext.restoreGraphicsState()
brown.setStroke(); board.lineWidth = 22; board.stroke()
// Clip at the top.
let clip = NSBezierPath(roundedRect: NSRect(x: 380, y: 720, width: 200, height: 96), xRadius: 30, yRadius: 30)
brown.setFill(); clip.fill()
// Text lines, neatly aligned.
for (i, width) in [260.0, 210, 240, 150].enumerated() {
    let line = NSBezierPath(roundedRect: NSRect(x: 340, y: 600 - CGFloat(i) * 90, width: CGFloat(width), height: 34), xRadius: 17, yRadius: 17)
    line.fill()
}
// Sparkle (four-point star) at the lower right, overlapping the board.
func star(_ c: NSPoint, _ r: CGFloat, _ inner: CGFloat) -> NSBezierPath {
    let p = NSBezierPath()
    for i in 0..<8 {
        let a = Double(i) * .pi / 4 + .pi / 2
        let radius = i % 2 == 0 ? r : inner
        let pt = NSPoint(x: c.x + CGFloat(cos(a)) * radius, y: c.y + CGFloat(sin(a)) * radius)
        i == 0 ? p.move(to: pt) : p.line(to: pt)
    }
    p.close(); p.lineJoinStyle = .round
    return p
}
let big = star(NSPoint(x: 720, y: 300), 175, 52)
cream.setFill(); big.fill(); big.lineWidth = 22; brown.setStroke(); big.stroke()
let small = star(NSPoint(x: 820, y: 500), 70, 22)
brown.setFill(); small.fill()
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("ClipTidy.png"))
