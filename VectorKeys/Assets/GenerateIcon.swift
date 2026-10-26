import AppKit
// Mustard base shared with the other apps (same as VectorMaestro). Motif: a script page (</>) with a keycap (shortcut) at its corner.
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
let softShadow = NSShadow(); softShadow.shadowColor = NSColor.black.withAlphaComponent(0.18); softShadow.shadowBlurRadius = 14; softShadow.shadowOffset = NSSize(width: 0, height: -6)

// Page with a folded top-right corner.
let fold: CGFloat = 120
let page = NSBezierPath()
page.move(to: NSPoint(x: 230, y: 200))
page.line(to: NSPoint(x: 230, y: 830))
page.line(to: NSPoint(x: 700 - fold, y: 830))
page.line(to: NSPoint(x: 700, y: 830 - fold))
page.line(to: NSPoint(x: 700, y: 200))
page.close(); page.lineJoinStyle = .round
NSGraphicsContext.saveGraphicsState(); softShadow.set(); cream.setFill(); page.fill(); NSGraphicsContext.restoreGraphicsState()
brown.setStroke(); page.lineWidth = 22; page.stroke()
let corner = NSBezierPath()
corner.move(to: NSPoint(x: 700 - fold, y: 830)); corner.line(to: NSPoint(x: 700 - fold, y: 830 - fold)); corner.line(to: NSPoint(x: 700, y: 830 - fold))
corner.lineWidth = 18; corner.lineJoinStyle = .round; corner.stroke()

// </> on the page.
func stroke(_ points: [NSPoint]) {
    let path = NSBezierPath(); path.move(to: points[0]); for p in points.dropFirst() { path.line(to: p) }
    path.lineWidth = 34; path.lineCapStyle = .round; path.lineJoinStyle = .round; brown.setStroke(); path.stroke()
}
stroke([NSPoint(x: 395, y: 640), NSPoint(x: 315, y: 560), NSPoint(x: 395, y: 480)])
stroke([NSPoint(x: 520, y: 640), NSPoint(x: 600, y: 560), NSPoint(x: 520, y: 480)])
stroke([NSPoint(x: 480, y: 665), NSPoint(x: 435, y: 455)])

// Keycap overlapping the lower right corner.
let rim = NSBezierPath(roundedRect: NSRect(x: 540, y: 150, width: 330, height: 320), xRadius: 64, yRadius: 64)
NSGraphicsContext.saveGraphicsState(); softShadow.set(); cream.setFill(); rim.fill(); NSGraphicsContext.restoreGraphicsState()
brown.setStroke(); rim.lineWidth = 20; rim.stroke()
let face = NSBezierPath(roundedRect: NSRect(x: 584, y: 210, width: 242, height: 222), xRadius: 40, yRadius: 40)
NSColor(srgbRed: 0.99, green: 0.95, blue: 0.84, alpha: 1).setFill(); face.fill()
brown.setStroke(); face.lineWidth = 12; face.stroke()
// ⌘ on the keycap.
let command = NSAttributedString(string: "⌘", attributes: [.font: NSFont.systemFont(ofSize: 150, weight: .bold), .foregroundColor: brown])
let size = command.size()
command.draw(at: NSPoint(x: 705 - size.width / 2, y: 321 - size.height / 2))
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("VectorKeys.png"))
