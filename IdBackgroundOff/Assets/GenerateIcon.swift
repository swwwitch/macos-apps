import AppKit
// Usage: swift GenerateIcon.swift <output folder>  → IdBackgroundOff.png (1024px)
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
// Mustard tile shared with FolderMover and the other sw_app icons.
let box = NSBezierPath(roundedRect: NSRect(x: 80, y: 80, width: 864, height: 864), xRadius: 220, yRadius: 220)
let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.23); shadow.shadowBlurRadius = 18; shadow.shadowOffset = NSSize(width: 0, height: -7)
NSGraphicsContext.saveGraphicsState(); shadow.set()
NSGradient(starting: NSColor(srgbRed: 1, green: 0.84, blue: 0.19, alpha: 1), ending: NSColor(srgbRed: 0.93, green: 0.69, blue: 0.055, alpha: 1))!.draw(in: box, angle: -75)
NSGraphicsContext.restoreGraphicsState()
NSColor.white.withAlphaComponent(0.35).setStroke(); box.lineWidth = 5; box.stroke()
let brown = NSColor(srgbRed: 0.38, green: 0.27, blue: 0.09, alpha: 1)
let paper = NSColor(srgbRed: 1, green: 0.985, blue: 0.95, alpha: 1)
// Document with a folded corner: the exported file.
let page = NSBezierPath()
page.move(to: NSPoint(x: 250, y: 230)); page.line(to: NSPoint(x: 250, y: 800)); page.line(to: NSPoint(x: 580, y: 800))
page.line(to: NSPoint(x: 700, y: 680)); page.line(to: NSPoint(x: 700, y: 230)); page.close()
paper.setFill(); page.fill(); brown.setStroke(); page.lineWidth = 17; page.lineJoinStyle = .round; page.stroke()
let fold = NSBezierPath(); fold.move(to: NSPoint(x: 580, y: 800)); fold.line(to: NSPoint(x: 580, y: 680)); fold.line(to: NSPoint(x: 700, y: 680))
fold.lineWidth = 17; fold.lineJoinStyle = .round; fold.stroke()
// "Id" names the target app (InDesign) on the exported page.
let label = NSAttributedString(string: "Id", attributes: [.font: NSFont.systemFont(ofSize: 330, weight: .heavy), .foregroundColor: brown, .kern: -6])
let labelSize = label.size()
label.draw(at: NSPoint(x: 465 - labelSize.width / 2, y: 470 - labelSize.height / 2))
// Switch in the off position (knob on the left).
let pill = NSBezierPath(roundedRect: NSRect(x: 560, y: 175, width: 310, height: 160), xRadius: 80, yRadius: 80)
NSGraphicsContext.saveGraphicsState(); shadow.set(); paper.setFill(); pill.fill(); NSGraphicsContext.restoreGraphicsState()
pill.lineWidth = 17; pill.stroke()
brown.setFill(); NSBezierPath(ovalIn: NSRect(x: 588, y: 203, width: 104, height: 104)).fill()
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("IdBackgroundOff.png"))
