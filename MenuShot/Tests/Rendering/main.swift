import AppKit

func bitmap(_ image: CGImage) -> NSBitmapImageRep { NSBitmapImageRep(cgImage: image) }
func gray(_ rep: NSBitmapImageRep, _ x: Int, _ y: Int) -> CGFloat {
    rep.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!.redComponent
}
let c = CGContext(data: nil, width: 40, height: 40, bitsPerComponent: 8, bytesPerRow: 0,
                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
c.setFillColor(CGColor(gray: 0.95, alpha: 1))
c.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: 40, height: 40), cornerWidth: 8, cornerHeight: 8, transform: nil)); c.fillPath()
let menu = c.makeImage()!
for scale: CGFloat in [1, 2] {
    for shadow in [false, true] {
        let barFrame = CGRect(x: 0, y: 0, width: 40 / scale, height: 10 / scale)
        let menuFrame = CGRect(x: 0, y: 12 / scale, width: 40 / scale, height: 40 / scale)
        let shots = [MenuCapture.Shot(frame: barFrame, image: menu, isMenu: false),
                     MenuCapture.Shot(frame: menuFrame, image: menu, isMenu: true)]
        let image = MenuCapture.compose(shots, crop: CGRect(x: 0, y: 0, width: 40 / scale, height: 52 / scale), scale: scale, shadow: shadow)!
        let rep = bitmap(image)
        precondition(gray(rep, 20, 9) < 0.9, "bar separator")
        precondition(gray(rep, 20, 8) > 0.9, "bar separator is only one pixel")
        precondition(gray(rep, 20, 12) < 0.8, "menu border")
        precondition(gray(rep, 20, 13) > 0.9, "menu border is only one pixel")
        if !shadow { precondition(rep.colorAt(x: 0, y: 12)!.alphaComponent == 0, "rounded corner stays transparent") }
    }
}
print("PASS: menu outline and bar separator are 1 output pixel at 1x/2x, shadows on/off; transparent corners preserved")
