import AppKit
let image = NSImage(size: NSSize(width: 1000, height: 220))
image.lockFocus()
NSColor.white.setFill(); NSRect(x: 0, y: 0, width: 1000, height: 220).fill()
("InputMaestro 12345" as NSString).draw(at: NSPoint(x: 40, y: 80), withAttributes: [.font: NSFont.systemFont(ofSize: 64), .foregroundColor: NSColor.black])
image.unlockFocus()
var rect = NSRect(origin: .zero, size: image.size)
let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: nil)!
let result = try TextRecognizer.recognize(cg)
precondition(result.contains("12345"), "OCR fixture: \(result)")
print("PASS: Vision OCR recognized rendered text: \(result)")
