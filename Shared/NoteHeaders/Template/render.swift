import AppKit
let args = CommandLine.arguments
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1280, pixelsHigh: 670, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
bitmap.size = NSSize(width: 1280, height: 670)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)!
NSColor(calibratedRed: 0.997, green: 0.997, blue: 0.982, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: 1280, height: 670).fill()
let icon = NSImage(contentsOfFile: args[2])!
icon.draw(in: NSRect(x: 94, y: 157, width: 376, height: 376))
let ink = NSColor(calibratedRed: 0.13, green: 0.085, blue: 0.025, alpha: 1)
func text(_ value: String, x: CGFloat, y: CGFloat, size: CGFloat, weight: NSFont.Weight) {
    (value as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: ink])
}
text("小さなMacアプリ工房", x: 510, y: 480, size: 36, weight: .bold)
NSColor(calibratedRed: 0.96, green: 0.76, blue: 0.09, alpha: 1).setFill()
NSRect(x: 510, y: 465, width: 288, height: 5).fill()
let lines = args[3].components(separatedBy: "|")
for (index, line) in lines.enumerated() {
    var size: CGFloat = 112
    while (line as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: .black)]).width > 690 { size -= 1 }
    text(line, x: 504, y: 337 - CGFloat(index)*118, size: size, weight: .black)
}
text(args[4], x: 510, y: 150, size: 34, weight: .bold)
NSGraphicsContext.current?.flushGraphics()
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[1]))
