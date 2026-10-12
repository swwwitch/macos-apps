import AppKit
// DocklessLauncher icon: the family's mustard tile (Shared/DesignAssets/app-icons-mustard-final.png), a white key cap
// seen slightly from above, and on its face a 2×2 grid of app tiles — one key opens one app.
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
let cream = NSColor(calibratedRed: 0.93, green: 0.89, blue: 0.80, alpha: 1)
let brown = NSColor(calibratedRed: 0.35, green: 0.24, blue: 0.07, alpha: 1)
let mustard = NSColor(calibratedRed: 0.96, green: 0.74, blue: 0.08, alpha: 1)

// Key cap: a darker base (the side) and the white top face.
let base = NSRect(x: 196, y: 176, width: 632, height: 632)
let basePath = NSBezierPath(roundedRect: base, xRadius: 120, yRadius: 120)
NSGraphicsContext.saveGraphicsState()
let capShadow = NSShadow(); capShadow.shadowColor = brown.withAlphaComponent(0.3)
capShadow.shadowBlurRadius = 16; capShadow.shadowOffset = NSSize(width: 0, height: -12); capShadow.set()
cream.setFill(); basePath.fill()
NSGraphicsContext.restoreGraphicsState()
brown.setStroke(); basePath.lineWidth = 22; basePath.stroke()
let face = NSRect(x: 246, y: 262, width: 532, height: 500)
let facePath = NSBezierPath(roundedRect: face, xRadius: 88, yRadius: 88)
white.setFill(); facePath.fill()
brown.setStroke(); facePath.lineWidth = 14; facePath.stroke()

// 2×2 app tiles on the face; the lower-left one is lit in mustard (the app the key opens).
let tile: CGFloat = 158, gap: CGFloat = 52
let origin = NSPoint(x: face.midX - tile - gap / 2, y: face.midY - tile - gap / 2)
for row in 0..<2 {
    for column in 0..<2 {
        let r = NSRect(x: origin.x + CGFloat(column) * (tile + gap), y: origin.y + CGFloat(row) * (tile + gap), width: tile, height: tile)
        let p = NSBezierPath(roundedRect: r, xRadius: 40, yRadius: 40)
        if row == 0 && column == 0 {
            mustard.setFill(); p.fill()
            brown.setStroke(); p.lineWidth = 16; p.stroke()
        } else {
            brown.setFill(); p.fill()
        }
    }
}

image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
