import Foundation

var failures = 0
func check(_ condition: Bool, _ message: String) {
    if !condition { failures += 1; print("FAIL:", message) }
}

let invoice = SortRule(name: "i", folder: "/d", keywords: ["請求書", "invoice"], destination: "/x")
check(invoice.matches("2026年10月_請求書.pdf"), "keyword")
check(invoice.matches("2026年10月_請求書.pdf".decomposedStringWithCanonicalMapping), "decomposed keyword")
check(invoice.matches("INVOICE-42.pdf"), "case-insensitive")
check(!invoice.matches("receipt.pdf"), "no match")
var off = invoice; off.enabled = false
check(!off.matches("請求書.pdf"), "disabled rule")
let music = SortRule(name: "m", folder: "/d", extensions: ["mp3", ".m4a", "flac"], destination: "/x")
check(music.matches("song.M4A") && music.matches("a.flac") && !music.matches("mp3.txt"), "extensions")
check(SortRule.list("mp3, m4a、flac\n") == ["mp3", "m4a", "flac"], "list parsing")
check(PartialFile.isPartial("a.pdf.download") && PartialFile.isPartial("x.crdownload") && PartialFile.isPartial(".hidden") && !PartialFile.isPartial("a.pdf"), "partial")
let taken: Set<String> = ["/tmp/x/a.pdf", "/tmp/x/a 2.pdf"]
check(FileNames.unique("a.pdf", in: URL(fileURLWithPath: "/tmp/x"), exists: { taken.contains($0.path) }).lastPathComponent == "a 3.pdf", "unique")
check(FileNames.unique("folder", in: URL(fileURLWithPath: "/tmp/x"), exists: { $0.lastPathComponent == "folder" }).lastPathComponent == "folder 2", "unique without extension")

if failures == 0 { print("PASS: sort rules, partial files, unique names") } else { print("\(failures) failure(s)"); exit(1) }
