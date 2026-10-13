import AppKit
// FolderMaker icon: the family's mustard tile (as LinkMaker), a white folder with a brown outline and a name label,
// and a brown badge with a white plus — a new folder named from the dialog box.
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
let mustard = NSColor(calibratedRed: 0.96, green: 0.74, blue: 0.08, alpha: 1)

func line(_ a: NSPoint, _ b: NSPoint, width: CGFloat, color: NSColor = brown) {
    let p = NSBezierPath(); p.move(to: a); p.line(to: b)
    p.lineWidth = width; p.lineCapStyle = .round; color.setStroke(); p.stroke()
}

// Folder: a tab on the upper left, then the body.
let body = NSRect(x: 165, y: 250, width: 640, height: 470)
let folder = NSBezierPath()
folder.move(to: NSPoint(x: body.minX, y: body.maxY - 40))
folder.line(to: NSPoint(x: body.minX, y: body.maxY + 70))
folder.appendArc(from: NSPoint(x: body.minX, y: body.maxY + 110), to: NSPoint(x: body.minX + 40, y: body.maxY + 110), radius: 40)
folder.line(to: NSPoint(x: body.minX + 200, y: body.maxY + 110))
folder.line(to: NSPoint(x: body.minX + 260, y: body.maxY + 40))
folder.appendArc(from: NSPoint(x: body.maxX, y: body.maxY + 40), to: NSPoint(x: body.maxX, y: body.minY), radius: 50)
folder.appendArc(from: NSPoint(x: body.maxX, y: body.minY), to: NSPoint(x: body.minX, y: body.minY), radius: 50)
folder.appendArc(from: NSPoint(x: body.minX, y: body.minY), to: NSPoint(x: body.minX, y: body.maxY), radius: 50)
folder.close()
folder.lineJoinStyle = .round
NSGraphicsContext.saveGraphicsState()
let cardShadow = NSShadow(); cardShadow.shadowColor = brown.withAlphaComponent(0.25)
cardShadow.shadowBlurRadius = 12; cardShadow.shadowOffset = NSSize(width: 0, height: -9); cardShadow.set()
white.setFill(); folder.fill()
NSGraphicsContext.restoreGraphicsState()
// Front flap line.
line(NSPoint(x: body.minX + 10, y: body.maxY - 50), NSPoint(x: body.maxX - 10, y: body.maxY - 50), width: 22)
brown.setStroke(); folder.lineWidth = 22; folder.stroke()
// Name label: client-region-date.
let label = NSBezierPath(roundedRect: NSRect(x: body.minX + 70, y: body.maxY - 200, width: 360, height: 80), xRadius: 24, yRadius: 24)
mustard.setFill(); label.fill()
line(NSPoint(x: body.minX + 110, y: body.maxY - 160), NSPoint(x: body.minX + 390, y: body.maxY - 160), width: 22, color: brown)
line(NSPoint(x: body.minX + 70, y: body.maxY - 280), NSPoint(x: body.minX + 330, y: body.maxY - 280), width: 26)

// Badge: brown disc with a white plus.
let center = NSPoint(x: 735, y: 300)
let radius: CGFloat = 165
let disc = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
NSGraphicsContext.saveGraphicsState()
let discShadow = NSShadow(); discShadow.shadowColor = brown.withAlphaComponent(0.3)
discShadow.shadowBlurRadius = 12; discShadow.shadowOffset = NSSize(width: 0, height: -8); discShadow.set()
brown.setFill(); disc.fill()
NSGraphicsContext.restoreGraphicsState()
white.setStroke(); disc.lineWidth = 16; disc.stroke()
line(NSPoint(x: center.x - 80, y: center.y), NSPoint(x: center.x + 80, y: center.y), width: 44, color: white)
line(NSPoint(x: center.x, y: center.y - 80), NSPoint(x: center.x, y: center.y + 80), width: 44, color: white)

image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
