import AppKit
// SpreadsheetHelper icon: the family's mustard tile (as in Shared/DesignAssets/app-icons-mustard-final.png),
// a white spreadsheet card with brown grid lines and a selected cell, and a brown badge with a crossed-out
// quotation mark (system font glyph) — the " that Excel adds to cells with line breaks, removed on copy.
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

func line(_ a: NSPoint, _ b: NSPoint, width: CGFloat, color: NSColor = brown, cap: NSBezierPath.LineCapStyle = .butt) {
    let p = NSBezierPath(); p.move(to: a); p.line(to: b)
    p.lineWidth = width; p.lineCapStyle = cap; color.setStroke(); p.stroke()
}

// Spreadsheet card: header row + 3 rows × 3 columns.
let card = NSRect(x: 170, y: 250, width: 620, height: 560)
let cardPath = NSBezierPath(roundedRect: card, xRadius: 52, yRadius: 52)
NSGraphicsContext.saveGraphicsState()
let cardShadow = NSShadow(); cardShadow.shadowColor = brown.withAlphaComponent(0.25)
cardShadow.shadowBlurRadius = 12; cardShadow.shadowOffset = NSSize(width: 0, height: -9); cardShadow.set()
white.setFill(); cardPath.fill()
NSGraphicsContext.restoreGraphicsState()
let headerHeight: CGFloat = 130
let header = card.maxY - headerHeight
NSGraphicsContext.saveGraphicsState()
cardPath.addClip()
brown.setFill(); NSRect(x: card.minX, y: header, width: card.width, height: headerHeight).fill()
NSGraphicsContext.restoreGraphicsState()
let columns = [card.minX + card.width / 3, card.minX + card.width * 2 / 3]
for x in columns { line(NSPoint(x: x, y: card.minY), NSPoint(x: x, y: header), width: 14) }
let rowHeight = (header - card.minY) / 3
for i in 1...2 { let y = card.minY + rowHeight * CGFloat(i); line(NSPoint(x: card.minX, y: y), NSPoint(x: card.maxX, y: y), width: 14) }
brown.setStroke(); cardPath.lineWidth = 22; cardPath.stroke()

// Selected cell (middle row, middle column): thick mustard frame inside the grid, like a spreadsheet selection.
let cell = NSRect(x: columns[0], y: card.minY + rowHeight, width: columns[1] - columns[0], height: rowHeight)
let selection = NSBezierPath(rect: cell.insetBy(dx: 4, dy: 4))
selection.lineWidth = 24; mustard.setStroke(); selection.stroke()
line(NSPoint(x: cell.minX + 46, y: cell.midY), NSPoint(x: cell.maxX - 70, y: cell.midY), width: 18, cap: .round)

// Badge: brown disc with a white ” crossed out by a mustard bar.
let center = NSPoint(x: 735, y: 300)
let radius: CGFloat = 165
let disc = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
NSGraphicsContext.saveGraphicsState()
let discShadow = NSShadow(); discShadow.shadowColor = brown.withAlphaComponent(0.3)
discShadow.shadowBlurRadius = 12; discShadow.shadowOffset = NSSize(width: 0, height: -8); discShadow.set()
brown.setFill(); disc.fill()
NSGraphicsContext.restoreGraphicsState()
white.setStroke(); disc.lineWidth = 16; disc.stroke()
// The quotation mark is Georgia Bold's comma-shaped ” as a path (system font fallback), centred on the path's own bounds.
let font = (NSFont(name: "Georgia-Bold", size: 400) ?? NSFont.systemFont(ofSize: 380, weight: .black)) as CTFont
var unichar: UniChar = 0x201D
var glyphID: CGGlyph = 0
CTFontGetGlyphsForCharacters(font, &unichar, &glyphID, 1)
if let outline = CTFontCreatePathForGlyph(font, glyphID, nil), let context = NSGraphicsContext.current?.cgContext {
    let box = outline.boundingBoxOfPath
    context.saveGState()
    context.translateBy(x: center.x - box.midX, y: center.y - box.midY)
    context.addPath(outline); context.setFillColor(white.cgColor); context.fillPath()
    context.restoreGState()
}
let a = NSPoint(x: center.x - 108, y: center.y + 108), b = NSPoint(x: center.x + 108, y: center.y - 108)
line(a, b, width: 42, color: brown, cap: .round)
line(a, b, width: 20, color: mustard, cap: .round)

image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
