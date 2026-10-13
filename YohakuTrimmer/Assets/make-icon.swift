import AppKit
// YohakuTrimmer icon: KageTrimmer's mustard tile and palette; motif = crop marks closing in on a picture.
let S: CGFloat = 1024
let mustard = NSColor(srgbRed: 0xF7/255, green: 0xCB/255, blue: 0x2B/255, alpha: 1)
let ivory = NSColor(srgbRed: 0xFB/255, green: 0xFA/255, blue: 0xF7/255, alpha: 1)
let brown = NSColor(srgbRed: 0x6E/255, green: 0x51/255, blue: 0x22/255, alpha: 1)
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(S), pixelsHigh: Int(S), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let tile = NSRect(x: 64, y: 48, width: 912, height: 912)
mustard.setFill(); NSBezierPath(roundedRect: tile, xRadius: 200, yRadius: 200).fill()
// The margin that gets removed: a dashed ivory frame.
let outer = NSRect(x: 196, y: 180, width: 632, height: 632)
let dash = NSBezierPath(roundedRect: outer, xRadius: 26, yRadius: 26)
dash.lineWidth = 16; dash.setLineDash([40, 30], count: 2, phase: 0); dash.lineCapStyle = .round
ivory.withAlphaComponent(0.85).setStroke(); dash.stroke()
// The picture that remains.
let card = NSRect(x: 312, y: 296, width: 400, height: 400)
ivory.setFill(); NSBezierPath(roundedRect: card, xRadius: 30, yRadius: 30).fill()
let clip = NSBezierPath(roundedRect: card.insetBy(dx: 36, dy: 36), xRadius: 14, yRadius: 14)
NSGraphicsContext.saveGraphicsState(); clip.addClip()
brown.setFill()
let m = NSBezierPath(); let b = card.insetBy(dx: 36, dy: 36)
m.move(to: NSPoint(x: b.minX, y: b.minY)); m.line(to: NSPoint(x: b.minX + 120, y: b.minY + 170)); m.line(to: NSPoint(x: b.minX + 200, y: b.minY + 70))
m.line(to: NSPoint(x: b.minX + 245, y: b.minY + 120)); m.line(to: NSPoint(x: b.maxX, y: b.minY)); m.close(); m.fill()
NSBezierPath(ovalIn: NSRect(x: b.maxX - 120, y: b.maxY - 120, width: 76, height: 76)).fill()
NSGraphicsContext.restoreGraphicsState()
// Crop marks hugging the picture.
brown.setStroke()
let g: CGFloat = 26, len: CGFloat = 120
for (x, y, sx, sy) in [(card.minX - g, card.minY - g, 1.0, 1.0), (card.maxX + g, card.minY - g, -1.0, 1.0), (card.minX - g, card.maxY + g, 1.0, -1.0), (card.maxX + g, card.maxY + g, -1.0, -1.0)] {
    let p = NSBezierPath(); p.lineWidth = 34; p.lineCapStyle = .round; p.lineJoinStyle = .round
    p.move(to: NSPoint(x: x + sx * len, y: y)); p.line(to: NSPoint(x: x, y: y)); p.line(to: NSPoint(x: x, y: y + sy * len)); p.stroke()
}
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
