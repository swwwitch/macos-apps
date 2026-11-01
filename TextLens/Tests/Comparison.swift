import AppKit
import Vision
import VisionKit
@main struct Compare {
 @MainActor static func main() async throws {
    print("VisionKit supported: \(ImageAnalyzer.isSupported)")
    let columns = ["日本語の縦組み認識", "文字を正しく読み取る"]
    for vertical in [false, true] {
      let image=NSImage(size:NSSize(width:1100,height:1000));image.lockFocus()
      NSColor.white.setFill();NSRect(x:0,y:0,width:1100,height:1000).fill()
      let attrs:[NSAttributedString.Key:Any]=[.font:NSFont(name:"HiraginoSans-W3",size:56)!, .foregroundColor:NSColor.black]
      for (i,line) in columns.enumerated() {
        if vertical {
          for (j,char) in line.enumerated() { (String(char) as NSString).draw(at:NSPoint(x:850-i*110,y:850-j*73),withAttributes:attrs) }
        } else { (line as NSString).draw(at:NSPoint(x:80,y:750-i*120),withAttributes:attrs) }
      }
      image.unlockFocus()
      let data=NSBitmapImageRep(data:image.tiffRepresentation!)!.representation(using:.png,properties:[:])!
      let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : NSTemporaryDirectory())
      try data.write(to: out.appendingPathComponent("textlens-\(vertical ? "vertical" : "horizontal").png"))
      var rect=NSRect(origin:.zero,size:image.size);let cg=image.cgImage(forProposedRect:&rect,context:nil,hints:nil)!
      let legacy = try TextRecognizer.recognizeLegacy(cg)
      let result = try await TextRecognizer.recognize(cg)
      print("\(vertical ? "VERTICAL" : "HORIZONTAL") Vision: " + legacy.replacingOccurrences(of:"\n",with:" | "))
      print("\(vertical ? "VERTICAL" : "HORIZONTAL") VisionKit: " + result.replacingOccurrences(of:"\n",with:" | "))
      let compact = result.filter { !$0.isWhitespace }
      if ImageAnalyzer.isSupported {
        precondition(compact == columns.joined(), "Full text and reading order must match: \(result)")
      } else {
        print("SKIP: VisionKit unsupported; vertical recognition not asserted")
      }

    }
 }
}
