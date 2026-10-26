import AppKit
// Mustard base shared with the other apps (same as SettingsHop and MenuShot).
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

// Motif: a folder tab with a star, over a list split by a separator (favorites grouped into categories).
let folder = NSBezierPath()
folder.appendRoundedRect(NSRect(x: 220, y: 610, width: 230, height: 120), xRadius: 34, yRadius: 34)
folder.appendRoundedRect(NSRect(x: 220, y: 230, width: 584, height: 440), xRadius: 54, yRadius: 54)
NSGraphicsContext.saveGraphicsState()
let folderShadow = NSShadow(); folderShadow.shadowColor = NSColor.black.withAlphaComponent(0.2); folderShadow.shadowBlurRadius = 16; folderShadow.shadowOffset = NSSize(width: 0, height: -8); folderShadow.set()
cream.setFill(); folder.fill()
NSGraphicsContext.restoreGraphicsState()
// The tab gets the same outline; the body is filled again over its lower edge.
let tab = NSBezierPath(roundedRect: NSRect(x: 220, y: 610, width: 230, height: 120), xRadius: 34, yRadius: 34)
brown.setStroke(); tab.lineWidth = 16; tab.stroke()
cream.setFill(); NSBezierPath(roundedRect: NSRect(x: 220, y: 230, width: 584, height: 440), xRadius: 54, yRadius: 54).fill()
brown.setStroke(); let outline = NSBezierPath(roundedRect: NSRect(x: 220, y: 230, width: 584, height: 440), xRadius: 54, yRadius: 54); outline.lineWidth = 16; outline.stroke()

// Rows: two above the separator, two below; a star on the first row of each group.
func star(center: NSPoint, radius: CGFloat) {
    let path = NSBezierPath()
    for i in 0..<10 {
        let r = i % 2 == 0 ? radius : radius * 0.45, angle = CGFloat(i) * .pi / 5 + .pi / 2
        let point = NSPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
        i == 0 ? path.move(to: point) : path.line(to: point)
    }
    path.close(); path.fill()
}
brown.setFill()
for (y, width, starred) in [(560.0, 330.0, true), (490, 250, false), (350, 300, true), (280, 210, false)] {
    if starred { star(center: NSPoint(x: 300, y: y + 14), radius: 34) }
    else { NSBezierPath(ovalIn: NSRect(x: 286, y: y, width: 28, height: 28)).fill() }
    NSBezierPath(roundedRect: NSRect(x: 352, y: y, width: width, height: 28), xRadius: 14, yRadius: 14).fill()
}
// The separator between the groups, in the mustard orange.
NSColor(srgbRed: 0.85, green: 0.5, blue: 0.05, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 270, y: 432, width: 484, height: 16), xRadius: 8, yRadius: 8).fill()
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("FavoriteFolders.png"))
