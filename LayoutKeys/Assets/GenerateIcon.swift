import AppKit
// Mustard base shared with the other apps (same as VectorMaestro). Motif: a laid-out page (graphic frame and text) with a keycap (shortcut) at its corner; VectorKeys has a script page (</>) instead.
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

// A layout on the page: an empty graphic frame (box with an X, as InDesign draws it) above lines of text.
let frameBox = NSBezierPath(rect: NSRect(x: 310, y: 560, width: 300, height: 130))
frameBox.lineWidth = 20; frameBox.lineJoinStyle = .round; brown.setStroke(); frameBox.stroke()
let cross = NSBezierPath()
cross.move(to: NSPoint(x: 310, y: 560)); cross.line(to: NSPoint(x: 610, y: 690))
cross.move(to: NSPoint(x: 310, y: 690)); cross.line(to: NSPoint(x: 610, y: 560))
cross.lineWidth = 12; cross.lineCapStyle = .round; cross.stroke()
for (y, right) in [(500, 610), (435, 490), (370, 490), (305, 490)] as [(CGFloat, CGFloat)] {
    let line = NSBezierPath(); line.move(to: NSPoint(x: 310, y: y)); line.line(to: NSPoint(x: right, y: y))
    line.lineWidth = 30; line.lineCapStyle = .round; brown.setStroke(); line.stroke()
}

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
try rep.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("LayoutKeys.png"))
