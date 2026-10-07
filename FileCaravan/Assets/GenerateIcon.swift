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
// Stacked documents entering a receiving folder distinguish bulk movement.
for (x,y) in [(270.0,550.0),(310.0,585.0),(350.0,620.0)] {
 let r = NSBezierPath(roundedRect: NSRect(x:x,y:y,width:280,height:125),xRadius:25,yRadius:25)
 NSColor(srgbRed:1,green:0.985,blue:0.94,alpha:1).setFill();r.fill();brown.setStroke();r.lineWidth=12;r.stroke()
}
let folder=NSBezierPath();folder.move(to:NSPoint(x:240,y:290));folder.line(to:NSPoint(x:240,y:555));folder.curve(to:NSPoint(x:270,y:585),controlPoint1:NSPoint(x:240,y:575),controlPoint2:NSPoint(x:250,y:585));folder.line(to:NSPoint(x:430,y:585));folder.line(to:NSPoint(x:475,y:535));folder.line(to:NSPoint(x:754,y:535));folder.curve(to:NSPoint(x:784,y:505),controlPoint1:NSPoint(x:775,y:535),controlPoint2:NSPoint(x:784,y:525));folder.line(to:NSPoint(x:784,y:290));folder.curve(to:NSPoint(x:754,y:260),controlPoint1:NSPoint(x:784,y:270),controlPoint2:NSPoint(x:774,y:260));folder.line(to:NSPoint(x:270,y:260));folder.close()
NSColor(srgbRed:1,green:0.985,blue:0.95,alpha:1).setFill();folder.fill();brown.setStroke();folder.lineWidth=17;folder.lineJoinStyle = .round;folder.stroke()
let arrow=NSBezierPath();arrow.move(to:NSPoint(x:365,y:400));arrow.line(to:NSPoint(x:650,y:400));arrow.move(to:NSPoint(x:585,y:465));arrow.line(to:NSPoint(x:650,y:400));arrow.line(to:NSPoint(x:585,y:335));arrow.lineWidth=45;arrow.lineCapStyle = .round;arrow.lineJoinStyle = .round;brown.setStroke();arrow.stroke()
image.unlockFocus()
let rep=NSBitmapImageRep(data:image.tiffRepresentation!)!
try rep.representation(using:.png,properties:[:])!.write(to:root.appendingPathComponent("FileCaravan.png"))
