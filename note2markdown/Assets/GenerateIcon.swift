import AppKit
// Usage: swift GenerateIcon.swift <output folder>  → note2markdown.png (1024px)
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
// Mustard tile shared with the other sw_app icons.
let box = NSBezierPath(roundedRect: NSRect(x: 80, y: 80, width: 864, height: 864), xRadius: 220, yRadius: 220)
let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.23); shadow.shadowBlurRadius = 18; shadow.shadowOffset = NSSize(width: 0, height: -7)
NSGraphicsContext.saveGraphicsState(); shadow.set()
NSGradient(starting: NSColor(srgbRed: 1, green: 0.84, blue: 0.19, alpha: 1), ending: NSColor(srgbRed: 0.93, green: 0.69, blue: 0.055, alpha: 1))!.draw(in: box, angle: -75)
NSGraphicsContext.restoreGraphicsState()
NSColor.white.withAlphaComponent(0.35).setStroke(); box.lineWidth = 5; box.stroke()
let brown = NSColor(srgbRed: 0.38, green: 0.27, blue: 0.09, alpha: 1)
let paper = NSColor(srgbRed: 1, green: 0.985, blue: 0.95, alpha: 1)
// Sheet with a folded corner, as in dutiGUI and QuickIconExporter.
let sheet = NSBezierPath()
sheet.move(to: NSPoint(x: 250, y: 170))
sheet.line(to: NSPoint(x: 250, y: 830))
sheet.line(to: NSPoint(x: 640, y: 830))
sheet.line(to: NSPoint(x: 774, y: 696))
sheet.line(to: NSPoint(x: 774, y: 170))
sheet.close()
NSGraphicsContext.saveGraphicsState(); shadow.set(); paper.setFill(); sheet.fill(); NSGraphicsContext.restoreGraphicsState()
let fold = NSBezierPath()
fold.move(to: NSPoint(x: 640, y: 830)); fold.line(to: NSPoint(x: 640, y: 696)); fold.line(to: NSPoint(x: 774, y: 696)); fold.close()
NSColor(srgbRed: 0.93, green: 0.88, blue: 0.76, alpha: 1).setFill(); fold.fill()
// A heading mark (#) and text lines: a Markdown document.
let hash = NSBezierPath()
hash.lineWidth = 34; hash.lineCapStyle = .round
hash.move(to: NSPoint(x: 345, y: 590)); hash.line(to: NSPoint(x: 375, y: 770))
hash.move(to: NSPoint(x: 435, y: 590)); hash.line(to: NSPoint(x: 465, y: 770))
hash.move(to: NSPoint(x: 315, y: 725)); hash.line(to: NSPoint(x: 505, y: 725))
hash.move(to: NSPoint(x: 305, y: 640)); hash.line(to: NSPoint(x: 495, y: 640))
brown.setStroke(); hash.stroke()
for (y, right) in [(500.0, 690.0), (420.0, 560.0), (340.0, 520.0)] {
    let line = NSBezierPath(roundedRect: NSRect(x: 320, y: y, width: right - 320, height: 34), xRadius: 17, yRadius: 17)
    brown.withAlphaComponent(0.55).setFill(); line.fill()
}
// Download arrow badge at the lower right: written out to a file.
let badge = NSBezierPath(ovalIn: NSRect(x: 590, y: 150, width: 270, height: 270))
NSGraphicsContext.saveGraphicsState(); shadow.set(); brown.setFill(); badge.fill(); NSGraphicsContext.restoreGraphicsState()
let arrow = NSBezierPath()
arrow.lineWidth = 34; arrow.lineCapStyle = .round; arrow.lineJoinStyle = .round
arrow.move(to: NSPoint(x: 725, y: 360)); arrow.line(to: NSPoint(x: 725, y: 230))
arrow.move(to: NSPoint(x: 668, y: 288)); arrow.line(to: NSPoint(x: 725, y: 228)); arrow.line(to: NSPoint(x: 782, y: 288))
paper.setStroke(); arrow.stroke()
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("note2markdown.png"))
