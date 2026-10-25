import Foundation

var failures = 0
func check(_ condition: Bool, _ message: String) {
    if !condition { failures += 1; print("FAIL:", message) }
}

check(ShotNaming.isCandidate("Screenshot 2026-10-26 2.31.00.png"), "screenshot is a candidate")
check(!ShotNaming.isCandidate("ss-1920-1080-144-20261026-023100.png"), "renamed is skipped")
check(!ShotNaming.isCandidate("Screenshot.jpg"), "jpg skipped")
check(!ShotNaming.isCandidate(".Screenshot.png"), "hidden skipped")
var parts = DateComponents(); parts.year = 2026; parts.month = 10; parts.day = 26; parts.hour = 2; parts.minute = 31; parts.second = 5
let date = Calendar.current.date(from: parts)!
let info = ImageInfo(width: 1920, height: 1080, dpi: 144)
check(ShotNaming.name(template: ShotNaming.defaultTemplate, info: info, date: date) == "ss-1920-1080-144-20261026-023105.png", "default name")
check(ShotNaming.name(template: "shot/{date}", info: info, date: date) == "shot-20261026-023105.png", "slash replaced")
check(ShotNaming.qrCodeName(ocr: "QRCode #sw-20261026\nスキャンしてください") == "CommentScreen-QRCode-20261026.png", "qr name")
check(ShotNaming.qrCodeName(ocr: "見出し\nQRCode #sw-20261026") == nil, "qr only at start")
let folder = URL(fileURLWithPath: "/tmp/x")
let taken: Set<String> = ["/tmp/x/a.png", "/tmp/x/a 2.png"]
check(ShotNaming.unique("a.png", in: folder, exists: { taken.contains($0.path) }).lastPathComponent == "a 3.png", "unique")

check(OCRText.joinJapanese("日本 語の\n文章 です。 OK and English") == "日本語の文章です。 OK and English", "join: \(OCRText.joinJapanese("日本 語の\n文章 です。 OK and English"))")
check(OCRText.fullwidthParens("注(1)") == "注（1）", "parens")
check(OCRText.clean("a (b)", join: true, parens: false) == "a (b)", "options off")

check(PartialFile.isPartial("a.pdf.download") && PartialFile.isPartial("x.crdownload") && !PartialFile.isPartial("a.pdf"), "partial")

if failures == 0 { print("PASS: naming, OCR text") } else { print("\(failures) failure(s)"); exit(1) }
