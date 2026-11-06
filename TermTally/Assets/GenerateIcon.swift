import AppKit
// Mustard base shared with the other apps. Motif: a page with tally marks (four strokes and a slash), the counting this app does.
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
let fold: CGFloat = 130
let left: CGFloat = 230, right: CGFloat = 794, top: CGFloat = 838, bottom: CGFloat = 186
let page = NSBezierPath()
page.move(to: NSPoint(x: left, y: bottom))
page.line(to: NSPoint(x: left, y: top))
page.line(to: NSPoint(x: right - fold, y: top))
page.line(to: NSPoint(x: right, y: top - fold))
page.line(to: NSPoint(x: right, y: bottom))
page.close(); page.lineJoinStyle = .round
NSGraphicsContext.saveGraphicsState(); softShadow.set(); cream.setFill(); page.fill(); NSGraphicsContext.restoreGraphicsState()
brown.setStroke(); page.lineWidth = 22; page.stroke()
let corner = NSBezierPath()
corner.move(to: NSPoint(x: right - fold, y: top)); corner.line(to: NSPoint(x: right - fold, y: top - fold)); corner.line(to: NSPoint(x: right, y: top - fold))
corner.lineWidth = 18; corner.lineJoinStyle = .round; corner.stroke()

// A line of text above the tally.
let line = NSBezierPath()
line.move(to: NSPoint(x: 310, y: 700)); line.line(to: NSPoint(x: 590, y: 700))
line.lineWidth = 26; line.lineCapStyle = .round; brown.withAlphaComponent(0.45).setStroke(); line.stroke()

// Four strokes and a slash.
let tally = NSBezierPath()
for index in 0..<4 {
    let x = 352 + CGFloat(index) * 94
    tally.move(to: NSPoint(x: x, y: 268)); tally.line(to: NSPoint(x: x, y: 590))
}
tally.lineWidth = 40; tally.lineCapStyle = .round; brown.setStroke(); tally.stroke()
let slash = NSBezierPath()
slash.move(to: NSPoint(x: 290, y: 300)); slash.line(to: NSPoint(x: 700, y: 556))
slash.lineWidth = 40; slash.lineCapStyle = .round
NSColor(srgbRed: 0.8, green: 0.32, blue: 0.1, alpha: 1).setStroke(); slash.stroke()
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("TermTally.png"))
