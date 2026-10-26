import AppKit
import CoreText
@main struct Probe {
 @MainActor static func main() {
  let board = NSPasteboard.general
  let saved = (board.pasteboardItems ?? []).map { item in item.types.compactMap { type in item.data(forType: type).map { (type, $0) } } }
  defer {
   board.clearContents()
   let items = saved.map { values in let item = NSPasteboardItem(); for (type,data) in values { item.setData(data, forType:type) }; return item }
   board.writeObjects(items)
  }
  let font = CTFontCreateWithName("Helvetica" as CFString, 64, nil)
  GlyphClipboard.copyText("A",font:font)
  precondition(board.string(forType:.string)=="A")
  let rtf = board.data(forType:.rtf)!
  let decoded = NSAttributedString(rtf:rtf,documentAttributes:nil)!
  precondition(decoded.string=="A")
  precondition(decoded.attribute(.font,at:0,effectiveRange:nil) != nil)
  var character:UniChar = 65; var glyph:CGGlyph = 0
  precondition(CTFontGetGlyphsForCharacters(font,&character,&glyph,1))
  GlyphClipboard.copyOutline(font:font,glyph:glyph)
  let pdf=board.data(forType:.pdf)!
  precondition(pdf.starts(with:Data("%PDF".utf8)))
  precondition(CGPDFDocument(CGDataProvider(data:pdf as CFData)!)?.numberOfPages==1)
  print("PASS: text, RTF font data, glyph PDF; clipboard restored")
 }
}
