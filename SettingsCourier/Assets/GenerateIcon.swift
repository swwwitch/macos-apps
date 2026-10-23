import AppKit
// Usage: swift GenerateIcon.swift <output folder>  → SettingsCourier.png (1024px)
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
// Parcel: the settings being carried to another Mac.
let body = NSRect(x: 350, y: 240, width: 470, height: 400)
let parcel = NSBezierPath(roundedRect: body, xRadius: 44, yRadius: 44)
NSGraphicsContext.saveGraphicsState(); shadow.set(); paper.setFill(); parcel.fill(); NSGraphicsContext.restoreGraphicsState()
// Lid band across the top of the parcel.
let lid = NSBezierPath(roundedRect: NSRect(x: 328, y: 580, width: 514, height: 120), xRadius: 36, yRadius: 36)
NSGraphicsContext.saveGraphicsState(); shadow.set(); paper.setFill(); lid.fill(); NSGraphicsContext.restoreGraphicsState()
brown.setStroke(); parcel.lineWidth = 30; parcel.stroke(); lid.lineWidth = 30; lid.stroke()
// Gear on the front: what is inside is settings.
let accent = NSColor(srgbRed: 0.93, green: 0.69, blue: 0.055, alpha: 1)
let center = NSPoint(x: 585, y: 420)
let gear = NSBezierPath()
let teeth = 8
for i in 0..<(teeth * 2) {
    let outer = i % 2 == 0
    let r: CGFloat = outer ? 128 : 100
    for step in 0...1 {
        let a = (CGFloat(i) + CGFloat(step)) * .pi / CGFloat(teeth) - .pi / CGFloat(teeth * 2)
        let pt = NSPoint(x: center.x + r * cos(a), y: center.y + r * sin(a))
        if i == 0 && step == 0 { gear.move(to: pt) } else { gear.line(to: pt) }
    }
}
gear.close()
gear.lineJoinStyle = .round
accent.setFill(); gear.fill(); brown.setStroke(); gear.lineWidth = 22; gear.stroke()
let hub = NSBezierPath(ovalIn: NSRect(x: center.x - 42, y: center.y - 42, width: 84, height: 84))
paper.setFill(); hub.fill(); hub.lineWidth = 22; hub.stroke()
// Speed lines on the left: on its way.
for (y, length) in [(560.0, 120.0), (440.0, 170.0), (320.0, 100.0)] {
    let line = NSBezierPath(); line.move(to: NSPoint(x: 290 - length, y: y)); line.line(to: NSPoint(x: 290, y: y))
    line.lineWidth = 34; line.lineCapStyle = .round; brown.setStroke(); line.stroke()
}
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("SettingsCourier.png"))
