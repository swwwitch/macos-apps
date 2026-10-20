import AppKit
let root=URL(fileURLWithPath:CommandLine.arguments[1])
let brown=NSColor(srgbRed:0.36,green:0.25,blue:0.085,alpha:1)
let mustard=NSColor(srgbRed:0.98,green:0.77,blue:0.085,alpha:1)
func draw() {
 let p=NSBezierPath();p.move(to:.init(x:220,y:80));p.line(to:.init(x:804,y:80));p.curve(to:.init(x:844,y:120),controlPoint1:.init(x:830,y:80),controlPoint2:.init(x:844,y:94));p.line(to:.init(x:844,y:770));p.line(to:.init(x:670,y:944));p.line(to:.init(x:220,y:944));p.curve(to:.init(x:180,y:904),controlPoint1:.init(x:194,y:944),controlPoint2:.init(x:180,y:930));p.line(to:.init(x:180,y:120));p.curve(to:.init(x:220,y:80),controlPoint1:.init(x:180,y:94),controlPoint2:.init(x:194,y:80));p.close()
 let shadow=NSShadow();shadow.shadowColor=NSColor.black.withAlphaComponent(0.2);shadow.shadowBlurRadius=16;shadow.shadowOffset=NSSize(width:0,height:-8)
 NSGraphicsContext.saveGraphicsState();shadow.set();NSColor(srgbRed:1,green:0.985,blue:0.95,alpha:1).setFill();p.fill();NSGraphicsContext.restoreGraphicsState()
 brown.withAlphaComponent(0.3).setStroke();p.lineWidth=5;p.stroke()
 let fold=NSBezierPath();fold.move(to:.init(x:670,y:944));fold.line(to:.init(x:670,y:798));fold.curve(to:.init(x:698,y:770),controlPoint1:.init(x:670,y:778),controlPoint2:.init(x:678,y:770));fold.line(to:.init(x:844,y:770));fold.close();NSColor(srgbRed:0.93,green:0.88,blue:0.78,alpha:1).setFill();fold.fill()
 ("#" as NSString).draw(at:NSPoint(x:266,y:490),withAttributes:[.font:NSFont.systemFont(ofSize:320,weight:.heavy),.foregroundColor:brown])
 func bar(_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ h:CGFloat,_ c:NSColor){c.setFill();NSBezierPath(roundedRect:NSRect(x:x,y:y,width:w,height:h),xRadius:h/2,yRadius:h/2).fill()}
 bar(280,470,460,48,brown);bar(330,390,410,40,mustard);bar(330,320,320,40,mustard)
 mustard.setFill();NSBezierPath(roundedRect:NSRect(x:260,y:128,width:504,height:132),xRadius:24,yRadius:24).fill()
 let t=NSAttributedString(string:"MD",attributes:[.font:NSFont.systemFont(ofSize:100,weight:.heavy),.foregroundColor:brown]);t.draw(at:NSPoint(x:512-t.size().width/2,y:194-t.size().height/2))
}
func render(_ size:Int)->Data {
 let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:size,pixelsHigh:size,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
 NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:rep);let t=NSAffineTransform();t.scale(by:CGFloat(size)/1024);t.concat();draw();NSGraphicsContext.restoreGraphicsState()
 return rep.representation(using:.png,properties:[:])!
}
for size in [16,32,128,256,512] {
 try render(size).write(to:root.appendingPathComponent("MarkdownKitchenDocument.iconset/icon_\(size)x\(size).png"))
 try render(size*2).write(to:root.appendingPathComponent("MarkdownKitchenDocument.iconset/icon_\(size)x\(size)@2x.png"))
}
try render(1024).write(to:root.appendingPathComponent("MarkdownKitchenDocument.png"))
