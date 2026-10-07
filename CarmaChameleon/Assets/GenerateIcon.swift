import AppKit
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let image = NSImage(size: NSSize(width: 1024,height: 1024))
image.lockFocus()
let box = NSBezierPath(roundedRect: NSRect(x: 80,y: 80,width: 864,height: 864), xRadius: 220,yRadius: 220)
let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.23); shadow.shadowBlurRadius = 18; shadow.shadowOffset = NSSize(width: 0,height: -7)
NSGraphicsContext.saveGraphicsState(); shadow.set()
NSGradient(starting: NSColor(srgbRed: 1,green: 0.84,blue: 0.19,alpha: 1), ending: NSColor(srgbRed: 0.93,green: 0.69,blue: 0.055,alpha: 1))!.draw(in: box, angle: -75)
NSGraphicsContext.restoreGraphicsState()
NSColor.white.withAlphaComponent(0.35).setStroke(); box.lineWidth = 5; box.stroke()
let brown = NSColor(srgbRed: 0.38,green: 0.27,blue: 0.09,alpha: 1)
// Two document sheets and a conversion arrow.
for (x,y) in [(230.0,360.0),(480.0,265.0)] {
 let page=NSBezierPath(roundedRect:NSRect(x:x,y:y,width:310,height:410),xRadius:28,yRadius:28)
 NSColor(srgbRed:1,green:0.985,blue:0.95,alpha:1).setFill();page.fill();brown.setStroke();page.lineWidth=15;page.stroke()
 for dy in [110.0,160.0,210.0] { let line=NSBezierPath();line.move(to:NSPoint(x:x+60,y:y+dy));line.line(to:NSPoint(x:x+240,y:y+dy));line.lineWidth=16;line.lineCapStyle = .round;line.stroke() }
}
let arrow=NSBezierPath();arrow.move(to:NSPoint(x:310,y:530));arrow.line(to:NSPoint(x:665,y:530));arrow.move(to:NSPoint(x:580,y:615));arrow.line(to:NSPoint(x:665,y:530));arrow.line(to:NSPoint(x:580,y:445));arrow.lineWidth=47;arrow.lineCapStyle = .round;arrow.lineJoinStyle = .round;brown.setStroke();arrow.stroke()
image.unlockFocus()
let rep=NSBitmapImageRep(data:image.tiffRepresentation!)!
try rep.representation(using:.png,properties:[:])!.write(to:root.appendingPathComponent("CarmaChameleon.png"))
