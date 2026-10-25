// Approved 2026-10-25: centered kana card; Lite capsule.
import AppKit
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let brown = NSColor(srgbRed: 0.36, green: 0.25, blue: 0.085, alpha: 1)
let paper = NSColor(srgbRed: 1, green: 0.985, blue: 0.95, alpha: 1)
func render(_ size: NSSize, _ draw: () -> Void) -> NSImage {
 let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
 NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
 draw(); NSGraphicsContext.restoreGraphicsState()
 let im = NSImage(size: size); im.addRepresentation(rep); return im
}
func save(_ im: NSImage, _ name: String) throws {
 let rep = NSBitmapImageRep(data: im.tiffRepresentation!)!
 try rep.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent(name))
}
func text(_ value: String, _ font: NSFont, _ center: NSPoint, _ color: NSColor = brown) {
 let s = NSAttributedString(string: value, attributes: [.font: font, .foregroundColor: color]); let z = s.size()
 s.draw(at: NSPoint(x: center.x-z.width/2, y: center.y-z.height/2))
}
func card(_ rect: NSRect, _ fill: NSColor = paper) {
 let p = NSBezierPath(roundedRect: rect, xRadius: 42, yRadius: 42)
 let shadow = NSShadow(); shadow.shadowColor = brown.withAlphaComponent(0.18); shadow.shadowBlurRadius = 12; shadow.shadowOffset = NSSize(width: 0,height: -8)
 NSGraphicsContext.saveGraphicsState(); shadow.set(); fill.setFill(); p.fill(); NSGraphicsContext.restoreGraphicsState()
 brown.setStroke(); p.lineWidth = 24; p.stroke()
}
func icon(_ lite: Bool) -> NSImage {
 render(NSSize(width: 1024,height: 1024)) {
  let tile = NSBezierPath(roundedRect: NSRect(x: 54,y: 54,width: 916,height: 916), xRadius: 220,yRadius: 220)
  let sh = NSShadow(); sh.shadowColor = NSColor.black.withAlphaComponent(0.12); sh.shadowBlurRadius = 12; sh.shadowOffset = NSSize(width: 0,height: -9)
  NSGraphicsContext.saveGraphicsState(); sh.set()
  NSGradient(starting: NSColor(srgbRed: 0.99,green: 0.79,blue: 0.095,alpha: 1), ending: NSColor(srgbRed: 0.97,green: 0.75,blue: 0.075,alpha: 1))!.draw(in: tile, angle: -75)
  NSGraphicsContext.restoreGraphicsState()
  card(NSRect(x: 228,y: 206,width: 568,height: 612))
  text("あ", NSFont(name: "HiraMinProN-W6",size: 350)!, NSPoint(x: 512,y: 512))
  if lite {
   let badge = NSBezierPath(roundedRect: NSRect(x: 534,y: 122,width: 332,height: 146), xRadius: 73,yRadius: 73)
   paper.setStroke(); badge.lineWidth = 16; badge.stroke()
   brown.setFill(); badge.fill()
   text("Lite",NSFont.systemFont(ofSize: 96,weight: .semibold),NSPoint(x:700,y:199),.white)
  }
 }
}

try save(icon(true), "NotMyTypeLite.png")
