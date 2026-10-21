import AppKit
// FnNumpad icon: the family's mustard tile (as in Shared/DesignAssets/app-icons-mustard-final.png),
// a white keypad with brown keys, and a brown badge with a white "fn" — keypad keys typed with Fn.
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

// Keypad: white body with a 3×4 grid of brown keys (the bottom row is a wide 0 and a dot).
let body = NSRect(x: 190, y: 170, width: 560, height: 680)
let bodyPath = NSBezierPath(roundedRect: body, xRadius: 64, yRadius: 64)
NSGraphicsContext.saveGraphicsState()
let bodyShadow = NSShadow(); bodyShadow.shadowColor = brown.withAlphaComponent(0.25)
bodyShadow.shadowBlurRadius = 12; bodyShadow.shadowOffset = NSSize(width: 0, height: -9); bodyShadow.set()
white.setFill(); bodyPath.fill()
NSGraphicsContext.restoreGraphicsState()
brown.setStroke(); bodyPath.lineWidth = 22; bodyPath.stroke()
let inset: CGFloat = 62, gap: CGFloat = 34
let key = (body.width - inset * 2 - gap * 2) / 3
func keyCap(_ column: CGFloat, _ row: CGFloat, span: CGFloat = 1) {
    let frame = NSRect(x: body.minX + inset + column * (key + gap), y: body.minY + inset + row * (key + gap),
                       width: key * span + gap * (span - 1), height: key)
    brown.withAlphaComponent(0.8).setFill(); NSBezierPath(roundedRect: frame, xRadius: 26, yRadius: 26).fill()
}
for row in 1...3 { for column in 0...2 { keyCap(CGFloat(column), CGFloat(row)) } }
keyCap(0, 0, span: 2); keyCap(2, 0)

// Badge: brown disc with a white "fn".
let center = NSPoint(x: 740, y: 290)
let radius: CGFloat = 165
let disc = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
NSGraphicsContext.saveGraphicsState()
let discShadow = NSShadow(); discShadow.shadowColor = brown.withAlphaComponent(0.3)
discShadow.shadowBlurRadius = 12; discShadow.shadowOffset = NSSize(width: 0, height: -8); discShadow.set()
brown.setFill(); disc.fill()
NSGraphicsContext.restoreGraphicsState()
white.setStroke(); disc.lineWidth = 16; disc.stroke()
let label = NSAttributedString(string: "fn", attributes: [.font: NSFont.systemFont(ofSize: 170, weight: .heavy), .foregroundColor: white])
let size = label.size()
label.draw(at: NSPoint(x: center.x - size.width / 2, y: center.y - size.height / 2 + 8))

image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
