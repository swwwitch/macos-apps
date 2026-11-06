import Foundation
import PDFKit

let snapshot = PDFTextSnapshot(text: "A😀\n\n\n\nBeta\n\n", pageRanges: [NSRange(location: 0, length: 3), NSRange(location: 5, length: 0), NSRange(location: 7, length: 4)], emptyPages: 1)
assert(snapshot.page(at: 2) == 1)
assert(snapshot.page(at: 3) == nil)
assert(snapshot.page(at: 7) == 3)
assert(snapshot.page(at: 11) == nil)
assert(snapshot.pageCount == 3 && snapshot.emptyPages == 1)
do {
    _ = try PDFTextSnapshot.read(URL(fileURLWithPath: "/nonexistent/TermTally-test.pdf"))
    fatalError("Missing PDF must fail")
} catch PDFTextSnapshot.Failure.unavailable {} catch { fatalError("Unexpected error: \(error)") }
if CommandLine.arguments.count > 1 {
    let url = URL(fileURLWithPath: CommandLine.arguments[1])
    let before = try Data(contentsOf: url)
    let result = try PDFTextSnapshot.read(url)
    assert(result.pageCount > 0 && !result.text.isEmpty)
    for (index, range) in result.pageRanges.enumerated() where range.length > 0 {
        assert(result.page(at: range.location) == index + 1)
        assert(result.page(at: NSMaxRange(range) - 1) == index + 1)
    }
    let after = try Data(contentsOf: url)
    assert(before == after)
    print("PDF integration PASS: pages=\(result.pageCount), empty=\(result.emptyPages), UTF16=\((result.text as NSString).length); original unchanged")
}
print("PASS: PDF page offsets, UTF16, empty pages, unavailable file")
