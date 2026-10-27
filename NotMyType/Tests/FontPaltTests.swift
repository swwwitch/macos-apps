import AppKit
import CoreText
@main struct Probe {
 static func main() {
  let font = CTFontCreateWithName("HiraginoSans-W3" as CFString, 32, nil)
  func width(_ enabled: Bool) -> Double {
   let result = FontParagraphLayout.make(text: "あいうえお、。カタカナ", font: font, width: 1000, columns: 1, lineHeight: 1, palt: enabled)
   let lines = CTFrameGetLines(result.frames[0]) as! [CTLine]
   return CTLineGetTypographicBounds(lines[0], nil, nil, nil)
  }
  let off = width(false), on = width(true)
  precondition(on < off)
  print("PASS palt: off=\(off), on=\(on); original font retained")
 }
}
