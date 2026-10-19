import AppKit
// BreaklineTrimmer icon: KageTrimmer's mustard tile and palette (as YohakuTrimmer); motif = a picture cut across
// with a wavy edge, the two parts closed up with a gap, and brown break lines along both cut edges.
let S: CGFloat = 1024
let mustard = NSColor(srgbRed: 0xF7/255, green: 0xCB/255, blue: 0x2B/255, alpha: 1)
let ivory = NSColor(srgbRed: 0xFB/255, green: 0xFA/255, blue: 0xF7/255, alpha: 1)
let brown = NSColor(srgbRed: 0x6E/255, green: 0x51/255, blue: 0x22/255, alpha: 1)
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(S), pixelsHigh: Int(S), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let tile = NSRect(x: 64, y: 48, width: 912, height: 912)
mustard.setFill(); NSBezierPath(roundedRect: tile, xRadius: 200, yRadius: 200).fill()

// The picture card, cut across the middle by one period of a wave (the Flag style).
let card = NSRect(x: 214, y: 210, width: 596, height: 580)
let left = card.minX, right = card.maxX
let cutCenter: CGFloat = 512, amplitude: CGFloat = 34, gap: CGFloat = 70
func wave(_ x: CGFloat, _ center: CGFloat) -> CGFloat { center - amplitude * sin((x - left) / (right - left) * .pi * 2) }
func waveLine(_ center: CGFloat, reversed: Bool) -> [NSPoint] {
    let points = (0...80).map { index -> NSPoint in
        let x = left + (right - left) * CGFloat(index) / 80
        return NSPoint(x: x, y: wave(x, center))
    }
    return reversed ? points.reversed() : points
}
let upperEdge = cutCenter + gap / 2, lowerEdge = cutCenter - gap / 2
let radius: CGFloat = 34
func part(top: Bool) -> NSBezierPath {
    let path = NSBezierPath()
    if top {
        // From the cut edge (left to right) up and around the rounded top corners.
        let edge = waveLine(upperEdge, reversed: false)
        path.move(to: edge[0]); edge.dropFirst().forEach { path.line(to: $0) }
        path.line(to: NSPoint(x: right, y: card.maxY - radius))
        path.appendArc(withCenter: NSPoint(x: right - radius, y: card.maxY - radius), radius: radius, startAngle: 0, endAngle: 90)
        path.line(to: NSPoint(x: left + radius, y: card.maxY))
        path.appendArc(withCenter: NSPoint(x: left + radius, y: card.maxY - radius), radius: radius, startAngle: 90, endAngle: 180)
    } else {
        let edge = waveLine(lowerEdge, reversed: true)
        path.move(to: edge[0]); edge.dropFirst().forEach { path.line(to: $0) }
        path.line(to: NSPoint(x: left, y: card.minY + radius))
        path.appendArc(withCenter: NSPoint(x: left + radius, y: card.minY + radius), radius: radius, startAngle: 180, endAngle: 270)
        path.line(to: NSPoint(x: right - radius, y: card.minY))
        path.appendArc(withCenter: NSPoint(x: right - radius, y: card.minY + radius), radius: radius, startAngle: 270, endAngle: 360)
    }
    path.close()
    return path
}
let upper = part(top: true), lower = part(top: false)
ivory.setFill(); upper.fill(); lower.fill()

// Picture content: a sun in the upper part, mountains in the lower part.
brown.setFill()
NSBezierPath(ovalIn: NSRect(x: right - 190, y: card.maxY - 190, width: 100, height: 100)).fill()
NSGraphicsContext.saveGraphicsState(); lower.addClip()
let mountains = NSBezierPath()
mountains.move(to: NSPoint(x: left - 10, y: card.minY))
mountains.line(to: NSPoint(x: left + 170, y: card.minY + 210))
mountains.line(to: NSPoint(x: left + 300, y: card.minY + 90))
mountains.line(to: NSPoint(x: left + 400, y: card.minY + 170))
mountains.line(to: NSPoint(x: right + 10, y: card.minY))
mountains.close(); mountains.fill()
NSGraphicsContext.restoreGraphicsState()

// Break lines along both cut edges.
brown.setStroke()
for center in [upperEdge, lowerEdge] {
    let line = NSBezierPath(); line.lineWidth = 26; line.lineCapStyle = .round; line.lineJoinStyle = .round
    let points = waveLine(center, reversed: false)
    line.move(to: points[0]); points.dropFirst().forEach { line.line(to: $0) }
    line.stroke()
}
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
