import AppKit
// ControlMate icon: the family's mustard tile (as in Shared/DesignAssets/app-icons-mustard-final.png, drawn like FnNumpad),
// a white control keycap with a brown ⌃, and a brown badge with a white text caret — ⌃ keys for editing text.
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
let rect = NSRect(x: 72, y: 72, width: 880, height: 880)
let path = NSBezierPath(roundedRect: rect, xRadius: 210, yRadius: 210)
let shadow = NSShadow(); shadow.shadowColor = .black.withAlphaComponent(0.2); shadow.shadowBlurRadius = 14; shadow.shadowOffset = NSSize(width: 0, height: -7)
NSGraphicsContext.saveGraphicsState(); shadow.set()
NSColor(calibratedRed: 0.96, green: 0.76, blue: 0.08, alpha: 1).setFill(); path.fill(); NSGraphicsContext.restoreGraphicsState()
NSGradient(starting: NSColor(calibratedRed: 1, green: 0.82, blue: 0.14, alpha: 1), ending: NSColor(calibratedRed: 0.94, green: 0.72, blue: 0.06, alpha: 1))!.draw(in: path, angle: -65)
NSColor.white.withAlphaComponent(0.45).setStroke(); path.lineWidth = 7; path.stroke()

let white = NSColor(calibratedRed: 1, green: 0.995, blue: 0.98, alpha: 1)
let brown = NSColor(calibratedRed: 0.35, green: 0.24, blue: 0.07, alpha: 1)

// Keycap: white, brown outline, a large ⌃ and the word "control" underneath.
let cap = NSRect(x: 180, y: 250, width: 580, height: 560)
let capPath = NSBezierPath(roundedRect: cap, xRadius: 90, yRadius: 90)
NSGraphicsContext.saveGraphicsState()
let capShadow = NSShadow(); capShadow.shadowColor = brown.withAlphaComponent(0.25)
capShadow.shadowBlurRadius = 12; capShadow.shadowOffset = NSSize(width: 0, height: -9); capShadow.set()
white.setFill(); capPath.fill()
NSGraphicsContext.restoreGraphicsState()
brown.setStroke(); capPath.lineWidth = 22; capPath.stroke()
// ⌃ drawn as a thick chevron so it does not depend on a font.
let chevron = NSBezierPath()
chevron.move(to: NSPoint(x: cap.midX - 170, y: cap.minY + 300))
chevron.line(to: NSPoint(x: cap.midX, y: cap.minY + 455))
chevron.line(to: NSPoint(x: cap.midX + 170, y: cap.minY + 300))
chevron.lineWidth = 64; chevron.lineCapStyle = .round; chevron.lineJoinStyle = .round
brown.setStroke(); chevron.stroke()
let word = NSAttributedString(string: "control", attributes: [.font: NSFont.systemFont(ofSize: 84, weight: .bold), .foregroundColor: brown])
word.draw(at: NSPoint(x: cap.minX + 64, y: cap.minY + 70))

// Badge: brown disc with a white I-beam caret.
let center = NSPoint(x: 740, y: 280)
let radius: CGFloat = 165
let disc = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
NSGraphicsContext.saveGraphicsState()
let discShadow = NSShadow(); discShadow.shadowColor = brown.withAlphaComponent(0.3)
discShadow.shadowBlurRadius = 12; discShadow.shadowOffset = NSSize(width: 0, height: -8); discShadow.set()
brown.setFill(); disc.fill()
NSGraphicsContext.restoreGraphicsState()
white.setStroke(); disc.lineWidth = 16; disc.stroke()
let beam = NSBezierPath()
beam.move(to: NSPoint(x: center.x, y: center.y - 90)); beam.line(to: NSPoint(x: center.x, y: center.y + 90))
for y in [center.y - 90, center.y + 90] {
    beam.move(to: NSPoint(x: center.x - 50, y: y)); beam.line(to: NSPoint(x: center.x + 50, y: y))
}
beam.lineWidth = 30; beam.lineCapStyle = .round
white.setStroke(); beam.stroke()

image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
