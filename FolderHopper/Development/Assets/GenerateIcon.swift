import AppKit

// A geometric, editable AppKit source; render each icon size directly.
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
}
func render(_ pixels: Int, to url: URL) throws {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let scale = CGFloat(pixels) / 1024
    let transform = NSAffineTransform(); transform.scale(by: scale); transform.concat()
    let tile = NSBezierPath(roundedRect: NSRect(x: 72, y: 72, width: 880, height: 880), xRadius: 194, yRadius: 194)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.16)
    shadow.shadowBlurRadius = 22; shadow.shadowOffset = NSSize(width: 0, height: -9); shadow.set()
    color(0.93, 0.94, 0.96).setFill(); tile.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: color(0.985, 0.99, 1), ending: color(0.87, 0.89, 0.92))!.draw(in: tile, angle: -90)
    NSColor.white.withAlphaComponent(0.75).setStroke(); tile.lineWidth = 3; tile.stroke()

    let back = NSBezierPath()
    back.move(to: NSPoint(x: 208, y: 352))
    back.line(to: NSPoint(x: 208, y: 718))
    back.curve(to: NSPoint(x: 250, y: 760), controlPoint1: NSPoint(x: 208, y: 748), controlPoint2: NSPoint(x: 223, y: 760))
    back.line(to: NSPoint(x: 370, y: 760))
    back.curve(to: NSPoint(x: 435, y: 716), controlPoint1: NSPoint(x: 398, y: 760), controlPoint2: NSPoint(x: 407, y: 716))
    back.line(to: NSPoint(x: 774, y: 716))
    back.curve(to: NSPoint(x: 816, y: 674), controlPoint1: NSPoint(x: 803, y: 716), controlPoint2: NSPoint(x: 816, y: 702))
    back.line(to: NSPoint(x: 816, y: 352)); back.close()
    NSGradient(starting: color(0.23, 0.72, 1), ending: color(0.06, 0.42, 0.86))!.draw(in: back, angle: -90)
    let paper = NSBezierPath(roundedRect: NSRect(x: 229, y: 352, width: 566, height: 343), xRadius: 26, yRadius: 26)
    color(0.84, 0.94, 1).setFill(); paper.fill()
    let front = NSBezierPath(roundedRect: NSRect(x: 208, y: 272, width: 608, height: 400), xRadius: 44, yRadius: 44)
    NSGraphicsContext.saveGraphicsState()
    let folderShadow = NSShadow(); folderShadow.shadowColor = color(0.03, 0.17, 0.33).withAlphaComponent(0.2)
    folderShadow.shadowBlurRadius = 20; folderShadow.shadowOffset = NSSize(width: 0, height: -12); folderShadow.set()
    color(0.08, 0.48, 0.9).setFill(); front.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: color(0.15, 0.65, 1), ending: color(0.025, 0.39, 0.86))!.draw(in: front, angle: -90)
    NSColor.white.withAlphaComponent(0.22).setStroke(); front.lineWidth = 2; front.stroke()

    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 337, y: 472)); arrow.line(to: NSPoint(x: 680, y: 472))
    arrow.move(to: NSPoint(x: 574, y: 578)); arrow.line(to: NSPoint(x: 680, y: 472)); arrow.line(to: NSPoint(x: 574, y: 366))
    arrow.lineWidth = 58; arrow.lineCapStyle = .round; arrow.lineJoinStyle = .round
    NSColor.white.setStroke(); arrow.stroke()
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: url)
}
let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    try render(size, to: root.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(size * 2, to: root.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
