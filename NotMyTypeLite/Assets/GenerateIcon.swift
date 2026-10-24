import AppKit
// Usage: swift GenerateIcon.swift <output folder>  → NotMyType.png (1024px)
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
// Mustard tile shared with the other sw_app icons (same as SettingsCourier and SiteMirror).
let box = NSBezierPath(roundedRect: NSRect(x: 54, y: 54, width: 916, height: 916), xRadius: 220, yRadius: 220)
let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.10); shadow.shadowBlurRadius = 0; shadow.shadowOffset = NSSize(width: 0, height: -12)
NSGraphicsContext.saveGraphicsState(); shadow.set()
NSGradient(starting: NSColor(srgbRed: 0.99, green: 0.79, blue: 0.095, alpha: 1), ending: NSColor(srgbRed: 0.97, green: 0.75, blue: 0.075, alpha: 1))!.draw(in: box, angle: -75)
NSGraphicsContext.restoreGraphicsState()
let brown = NSColor(srgbRed: 0.36, green: 0.25, blue: 0.085, alpha: 1)
let paper = NSColor(srgbRed: 1, green: 0.985, blue: 0.95, alpha: 1)
let accent = NSColor(srgbRed: 0.93, green: 0.69, blue: 0.055, alpha: 1)
// Type specimen card with "あa": Japanese and Latin fonts managed side by side.
let card = NSRect(x: 170, y: 220, width: 684, height: 584)
let cardPath = NSBezierPath(roundedRect: card, xRadius: 64, yRadius: 64)
NSGraphicsContext.saveGraphicsState(); shadow.set(); paper.setFill(); cardPath.fill(); NSGraphicsContext.restoreGraphicsState()
brown.setStroke(); cardPath.lineWidth = 30; cardPath.stroke()
let kana = NSAttributedString(string: "あ", attributes: [
    .font: NSFont(name: "HiraMinProN-W6", size: 360) ?? NSFont.boldSystemFont(ofSize: 360), .foregroundColor: brown])
let latin = NSAttributedString(string: "a", attributes: [
    .font: NSFont(name: "Georgia-Bold", size: 340) ?? NSFont.boldSystemFont(ofSize: 340), .foregroundColor: brown])
let glyphs = NSMutableAttributedString(attributedString: kana)
glyphs.append(latin)
let glyphSize = glyphs.size()
glyphs.draw(at: NSPoint(x: card.midX - glyphSize.width / 2, y: card.midY - glyphSize.height / 2 + 4))
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("NotMyType.png"))
