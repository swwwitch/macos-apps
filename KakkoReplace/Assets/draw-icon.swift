import AppKit
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
let rect = NSRect(x: 72, y: 72, width: 880, height: 880)
let path = NSBezierPath(roundedRect: rect, xRadius: 210, yRadius: 210)
let shadow = NSShadow(); shadow.shadowColor = .black.withAlphaComponent(0.2); shadow.shadowBlurRadius = 14; shadow.shadowOffset = NSSize(width: 0, height: -7)
NSGraphicsContext.saveGraphicsState(); shadow.set()
NSColor(calibratedRed: 0.96, green: 0.76, blue: 0.08, alpha: 1).setFill(); path.fill(); NSGraphicsContext.restoreGraphicsState()
NSGradient(starting: NSColor(calibratedRed: 1, green: 0.82, blue: 0.14, alpha: 1), ending: NSColor(calibratedRed: 0.94, green: 0.72, blue: 0.06, alpha: 1))!.draw(in: path, angle: -65)
NSColor.white.withAlphaComponent(0.45).setStroke(); path.lineWidth = 7; path.stroke()
// Brackets changing shape: square pair at upper left, round pair at lower right.
// Native paths keep the family motif crisp and reproducible at every size.
let cream = NSColor(calibratedRed: 1, green: 0.99, blue: 0.96, alpha: 1)
let brown = NSColor(calibratedRed: 0.38, green: 0.27, blue: 0.08, alpha: 1)
func stroke(_ points: [NSPoint], color: NSColor, width: CGFloat) {
    let p = NSBezierPath(); p.move(to: points[0])
    for point in points.dropFirst() { p.line(to: point) }
    p.lineWidth = width; p.lineJoinStyle = .round; p.lineCapStyle = .round
    color.setStroke(); p.stroke()
}
NSGraphicsContext.saveGraphicsState()
let motifShadow = NSShadow(); motifShadow.shadowColor = brown.withAlphaComponent(0.16)
motifShadow.shadowBlurRadius = 3; motifShadow.shadowOffset = NSSize(width: 0, height: -5); motifShadow.set()
stroke([NSPoint(x: 344,y: 764),NSPoint(x: 266,y: 764),NSPoint(x: 266,y: 550),NSPoint(x: 344,y: 550)], color: cream, width: 62)
stroke([NSPoint(x: 430,y: 764),NSPoint(x: 508,y: 764),NSPoint(x: 508,y: 550),NSPoint(x: 430,y: 550)], color: cream, width: 62)
for right in [false, true] {
    let p = NSBezierPath()
    let outer: CGFloat = right ? 798 : 458
    let inner: CGFloat = right ? 722 : 534
    p.move(to: NSPoint(x: inner, y: 468))
    p.curve(to: NSPoint(x: inner, y: 232), controlPoint1: NSPoint(x: outer, y: 412), controlPoint2: NSPoint(x: outer, y: 288))
    p.lineWidth = 70; p.lineCapStyle = .round; cream.setStroke(); p.stroke()
}
NSGraphicsContext.restoreGraphicsState()
let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 626,y: 728))
arrow.curve(to: NSPoint(x: 794,y: 560), controlPoint1: NSPoint(x: 758,y: 728), controlPoint2: NSPoint(x: 794,y: 696))
arrow.lineWidth = 48; arrow.lineCapStyle = .round; brown.setStroke(); arrow.stroke()
stroke([NSPoint(x: 743,y: 602),NSPoint(x: 794,y: 549),NSPoint(x: 847,y: 602)], color: brown, width: 43)
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
