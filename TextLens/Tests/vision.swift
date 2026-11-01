import AppKit
import CryptoKit
@main struct Integration {
 static func main() throws {
    let image = NSImage(size: NSSize(width: 1000,height:240));image.lockFocus()
    NSColor.white.setFill();NSRect(x:0,y:0,width:1000,height:240).fill()
    ("TextLens 12345" as NSString).draw(at: NSPoint(x:50,y:100),withAttributes:[.font:NSFont.systemFont(ofSize:64),.foregroundColor:NSColor.black])
    image.unlockFocus()
    let url=FileManager.default.temporaryDirectory.appendingPathComponent("textlens-test-\(UUID()).png")
    defer { try? FileManager.default.removeItem(at:url) }
    let data=NSBitmapImageRep(data:image.tiffRepresentation!)!.representation(using:.png,properties:[:])!
    try data.write(to:url)
    let before=try Data(contentsOf:url)
    let text=try TextRecognizer.recognize(ImageReader.cgImage(url)!)
    guard text.contains("TextLens"),text.contains("12345"),try Data(contentsOf:url)==before else { fatalError("OCR or original preservation: \(text)") }
    guard ImageReader.cgImage(URL(fileURLWithPath:"/does-not-exist.png")) == nil else { fatalError("bad image") }
    print("PASS: Vision recognizes generated image; input bytes preserved; unreadable image rejected")
 }
}
