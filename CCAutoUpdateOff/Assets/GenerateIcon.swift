import AppKit
// Usage: swift GenerateIcon.swift <output folder>  → CCAutoUpdateOff.png (1024px)
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
// Mustard tile shared with IdBackgroundOff and the other sw_app icons.
let box = NSBezierPath(roundedRect: NSRect(x: 80, y: 80, width: 864, height: 864), xRadius: 220, yRadius: 220)
let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.23); shadow.shadowBlurRadius = 18; shadow.shadowOffset = NSSize(width: 0, height: -7)
NSGraphicsContext.saveGraphicsState(); shadow.set()
NSGradient(starting: NSColor(srgbRed: 1, green: 0.84, blue: 0.19, alpha: 1), ending: NSColor(srgbRed: 0.93, green: 0.69, blue: 0.055, alpha: 1))!.draw(in: box, angle: -75)
NSGraphicsContext.restoreGraphicsState()
NSColor.white.withAlphaComponent(0.35).setStroke(); box.lineWidth = 5; box.stroke()
let brown = NSColor(srgbRed: 0.38, green: 0.27, blue: 0.09, alpha: 1)
let paper = NSColor(srgbRed: 1, green: 0.985, blue: 0.95, alpha: 1)
// Generic cloud: three puffs on a flat rounded base (not any vendor's logo).
let cloud = NSBezierPath()
cloud.appendRoundedRect(NSRect(x: 190, y: 400, width: 640, height: 210), xRadius: 105, yRadius: 105)
cloud.appendOval(in: NSRect(x: 250, y: 470, width: 250, height: 250))
cloud.appendOval(in: NSRect(x: 390, y: 520, width: 330, height: 330))
cloud.appendOval(in: NSRect(x: 600, y: 450, width: 220, height: 220))
cloud.windingRule = .nonZero
// Union outline: stroke first (thick), then fill over it so inner overlaps vanish.
NSGraphicsContext.saveGraphicsState(); shadow.set(); brown.setFill()
let outline = cloud.copy() as! NSBezierPath
brown.setStroke(); outline.lineWidth = 34; outline.lineJoinStyle = .round; outline.stroke()
NSGraphicsContext.restoreGraphicsState()
paper.setFill(); cloud.fill()
// Update arrows inside the cloud.
let center = NSPoint(x: 512, y: 585), radius: CGFloat = 92
func arrow(from start: CGFloat, to end: CGFloat) {
    let arc = NSBezierPath()
    arc.appendArc(withCenter: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
    brown.setStroke(); arc.lineWidth = 30; arc.lineCapStyle = .round; arc.stroke()
    let a = end * .pi / 180
    let tip = NSPoint(x: center.x + radius * cos(a), y: center.y + radius * sin(a))
    let along = NSPoint(x: -sin(a), y: cos(a)), out = NSPoint(x: cos(a), y: sin(a))
    let head = NSBezierPath()
    head.move(to: NSPoint(x: tip.x + along.x * 52, y: tip.y + along.y * 52))
    head.line(to: NSPoint(x: tip.x + out.x * 46, y: tip.y + out.y * 46))
    head.line(to: NSPoint(x: tip.x - out.x * 46, y: tip.y - out.y * 46))
    head.close(); brown.setFill(); head.fill()
}
arrow(from: 30, to: 150)
arrow(from: 210, to: 330)
// Switch in the off position (knob on the left), as in IdBackgroundOff.
let pill = NSBezierPath(roundedRect: NSRect(x: 560, y: 175, width: 310, height: 160), xRadius: 80, yRadius: 80)
NSGraphicsContext.saveGraphicsState(); shadow.set(); paper.setFill(); pill.fill(); NSGraphicsContext.restoreGraphicsState()
brown.setStroke(); pill.lineWidth = 17; pill.stroke()
brown.setFill(); NSBezierPath(ovalIn: NSRect(x: 588, y: 203, width: 104, height: 104)).fill()
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("CCAutoUpdateOff.png"))
