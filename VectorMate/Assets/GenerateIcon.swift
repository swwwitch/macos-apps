import AppKit
// Usage: swift GenerateIcon.swift <output folder>  → VectorMate.png (1024px)
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
// Mustard tile shared with CCAutoUpdateOff, IdBackgroundOff and the other sw_app icons.
let box = NSBezierPath(roundedRect: NSRect(x: 80, y: 80, width: 864, height: 864), xRadius: 220, yRadius: 220)
let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.23); shadow.shadowBlurRadius = 18; shadow.shadowOffset = NSSize(width: 0, height: -7)
NSGraphicsContext.saveGraphicsState(); shadow.set()
NSGradient(starting: NSColor(srgbRed: 1, green: 0.84, blue: 0.19, alpha: 1), ending: NSColor(srgbRed: 0.93, green: 0.69, blue: 0.055, alpha: 1))!.draw(in: box, angle: -75)
NSGraphicsContext.restoreGraphicsState()
NSColor.white.withAlphaComponent(0.35).setStroke(); box.lineWidth = 5; box.stroke()
let brown = NSColor(srgbRed: 0.38, green: 0.27, blue: 0.09, alpha: 1)
let paper = NSColor(srgbRed: 1, green: 0.985, blue: 0.95, alpha: 1)
// A paper card with the pair "AV" set tight (proportional metrics), and a spacing bracket under it.
let card = NSBezierPath(roundedRect: NSRect(x: 190, y: 250, width: 644, height: 560), xRadius: 70, yRadius: 70)
NSGraphicsContext.saveGraphicsState(); shadow.set(); paper.setFill(); card.fill(); NSGraphicsContext.restoreGraphicsState()
brown.setStroke(); card.lineWidth = 22; card.stroke()
let font = NSFont(name: "Georgia-Bold", size: 300) ?? NSFont.boldSystemFont(ofSize: 300)
let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: brown, .kern: -40]
let text = NSAttributedString(string: "AV", attributes: attributes)
let size = text.size()
// The kern after the last glyph is part of the measured width, so add it back to center the ink.
text.draw(at: NSPoint(x: 512 - (size.width + 40) / 2, y: 440))
// ⟷ bracket: the spacing that metrics tightens.
let bracket = NSBezierPath()
bracket.move(to: NSPoint(x: 340, y: 430)); bracket.line(to: NSPoint(x: 340, y: 380)); bracket.line(to: NSPoint(x: 684, y: 380)); bracket.line(to: NSPoint(x: 684, y: 430))
brown.setStroke(); bracket.lineWidth = 26; bracket.lineCapStyle = .round; bracket.lineJoinStyle = .round; bracket.stroke()
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("VectorMate.png"))
