import AppKit
// Mustard base shared with the other apps (same as SettingsHop). Motif: a clapperboard (a take) whose slate is a screen with a pointer (a lone red dot on a screen read as the Japanese flag).
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

let red = NSColor(srgbRed: 0.85, green: 0.2, blue: 0.13, alpha: 1)
func soft(_ draw: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let s = NSShadow(); s.shadowColor = NSColor.black.withAlphaComponent(0.2); s.shadowBlurRadius = 16; s.shadowOffset = NSSize(width: 0, height: -8); s.set()
    draw(); NSGraphicsContext.restoreGraphicsState()
}
// Slate: a cream screen with a brown frame and a small REC dot.
let slate = NSBezierPath(roundedRect: NSRect(x: 190, y: 230, width: 644, height: 420), xRadius: 40, yRadius: 40)
soft { cream.setFill(); slate.fill() }
brown.setStroke(); slate.lineWidth = 26; slate.stroke()
red.setFill(); NSBezierPath(ovalIn: NSRect(x: 250, y: 300, width: 70, height: 70)).fill()
// Clapper: a brown striped stick opened at the hinge.
let context = NSGraphicsContext.current!.cgContext
context.saveGState(); context.translateBy(x: 190, y: 690); context.rotate(by: 0.16)
brown.setFill(); NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: 644, height: 110), xRadius: 24, yRadius: 24).fill()
cream.setFill()
for i in 0..<4 {
    let x = 40 + CGFloat(i) * 150
    let stripe = NSBezierPath()
    stripe.move(to: NSPoint(x: x, y: 18)); stripe.line(to: NSPoint(x: x + 60, y: 18)); stripe.line(to: NSPoint(x: x + 110, y: 92)); stripe.line(to: NSPoint(x: x + 50, y: 92)); stripe.close()
    stripe.fill()
}
context.restoreGState()
brown.setFill(); NSBezierPath(ovalIn: NSRect(x: 172, y: 640, width: 56, height: 56)).fill()
// Pointer: cream body, brown outline (the pointer layer is a feature of the app).
let tip = NSPoint(x: 520, y: 560), k: CGFloat = 1.25
let outline: [(CGFloat, CGFloat)] = [(0, 0), (0, -200), (48, -154), (82, -232), (118, -216), (86, -140), (150, -140)]
let pointer = NSBezierPath()
for (i, q) in outline.enumerated() { let p = NSPoint(x: tip.x + q.0 * k, y: tip.y + q.1 * k); i == 0 ? pointer.move(to: p) : pointer.line(to: p) }
pointer.close(); pointer.lineJoinStyle = .round
soft { cream.setFill(); pointer.fill() }
brown.setStroke(); pointer.lineWidth = 22 * k; pointer.stroke()
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("ScreenTake.png"))
