import AppKit
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
let rect = NSRect(x: 80, y: 80, width: 864, height: 864)
let shape = NSBezierPath(roundedRect: rect, xRadius: 200, yRadius: 200)
NSGradient(starting: NSColor(srgbRed: 1, green: 0.82, blue: 0.13, alpha: 1), ending: NSColor(srgbRed: 0.94, green: 0.70, blue: 0.04, alpha: 1))!.draw(in: shape, angle: -90)
NSColor(srgbRed: 1, green: 0.91, blue: 0.43, alpha: 1).setStroke(); shape.lineWidth = 9; shape.stroke()
let paper = NSBezierPath(roundedRect: NSRect(x: 235, y: 230, width: 470, height: 565), xRadius: 44, yRadius: 44)
NSColor(srgbRed: 1, green: 0.99, blue: 0.96, alpha: 1).setFill(); paper.fill()
let ink = NSColor(srgbRed: 0.36, green: 0.25, blue: 0.08, alpha: 1)
for (y,w) in [(690.0,280.0),(605,245),(520,275),(435,150)] {
 ink.setFill(); NSBezierPath(roundedRect: NSRect(x: 300,y: y,width:w,height:24),xRadius:12,yRadius:12).fill()
}
let lens = NSBezierPath(ovalIn: NSRect(x: 485,y: 230,width:260,height:260))
NSColor(srgbRed: 1, green: 0.95, blue: 0.73, alpha: 0.9).setFill(); lens.fill(); ink.setStroke(); lens.lineWidth=32; lens.stroke()
let handle=NSBezierPath();handle.move(to:NSPoint(x:711,y:262));handle.line(to:NSPoint(x:798,y:170));handle.lineWidth=49;handle.lineCapStyle = .round;handle.stroke()
("A" as NSString).draw(at:NSPoint(x:555,y:280),withAttributes:[.font:NSFont.systemFont(ofSize:145,weight:.bold),.foregroundColor:ink])
image.unlockFocus()
let data=NSBitmapImageRep(data:image.tiffRepresentation!)!.representation(using:.png,properties:[:])!
try data.write(to:URL(fileURLWithPath:CommandLine.arguments[1]))
