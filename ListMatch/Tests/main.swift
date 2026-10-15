import Foundation

var failures = 0
var count = 0
func check<T: Equatable>(_ name: String, _ actual: T, _ expected: T) {
    count += 1
    if actual != expected {
        failures += 1
        print("FAIL \(name)\n--- expected\n\(expected)\n--- actual\n\(actual)")
    }
}
typealias Options = ListComparison.Options

// Basic: only on one side, order kept
var r = ListComparison.compare("a@x.jp\nb@x.jp\nc@x.jp", "c@x.jp\nd@x.jp\na@x.jp")
check("leftOnly", r.leftOnly, ["b@x.jp"])
check("rightOnly", r.rightOnly, ["d@x.jp"])
check("common", r.commonCount, 2)

// Trimming, empty lines, CRLF, BOM
r = ListComparison.compare("\u{FEFF}  a@x.jp \r\n\r\n\tb@x.jp\r\n", "a@x.jp\n\n")
check("trim leftOnly", r.leftOnly, ["b@x.jp"])
check("trim rightOnly", r.rightOnly, [])
check("trim items", r.left.items, ["a@x.jp", "b@x.jp"])

// Case
r = ListComparison.compare("A@X.jp", "a@x.jp")
check("ignore case", r.leftOnly, [])
r = ListComparison.compare("A@X.jp", "a@x.jp", options: Options(ignoreCase: false))
check("case sensitive left", r.leftOnly, ["A@X.jp"])
check("case sensitive right", r.rightOnly, ["a@x.jp"])

// Width
r = ListComparison.compare("ＡＢＣ１", "abc1")
check("width off", r.leftOnly, ["ＡＢＣ１"])
r = ListComparison.compare("ＡＢＣ１\nｶﾞｷ", "abc1\nガキ", options: Options(ignoreWidth: true))
check("width on", r.leftOnly, [])
check("width on right", r.rightOnly, [])

// Duplicates: first occurrence kept, counted
r = ListComparison.compare("b\na\nB\nb\nc", "c")
check("dup items", r.left.items, ["b", "a"] + ["c"])
check("dup count", r.left.duplicateCount, 2)
check("dup leftOnly", r.leftOnly, ["b", "a"])

// Separators
r = ListComparison.compare("a@x.jp, b@x.jp,c@x.jp\td@x.jp", "b@x.jp\nd@x.jp", options: Options(splitAtCommas: true))
check("commas", r.leftOnly, ["a@x.jp", "c@x.jp\td@x.jp"])
r = ListComparison.compare("a@x.jp, b@x.jp,c@x.jp\td@x.jp", "b@x.jp\nd@x.jp", options: Options(splitAtCommas: true, splitAtTabs: true))
check("commas+tabs", r.leftOnly, ["a@x.jp", "c@x.jp"])
r = ListComparison.compare("りんご みかん　ぶどう\tもも", "みかん", options: Options(splitAtSpaces: true))
check("spaces", r.leftOnly, ["りんご", "ぶどう\tもも"])
r = ListComparison.compare("a，b", "b", options: Options(splitAtCommas: true))
check("full-width comma", r.leftOnly, ["a"])
r = ListComparison.compare("a, b", "a", options: Options())
check("no separators", r.leftOnly, ["a, b"])

// Sorting
r = ListComparison.compare("item10\nitem2\nItem1", "", options: Options(sortResults: true))
check("sorted", r.leftOnly, ["Item1", "item2", "item10"])
r = ListComparison.compare("item10\nitem2\nItem1", "")
check("original order", r.leftOnly, ["item10", "item2", "Item1"])

// Empty
r = ListComparison.compare("", "")
check("empty", r, ListComparison())

// Japanese names
r = ListComparison.compare("キウイフルーツ\nメロン\nいちご\nりんご", "メロン\nいちご")
check("japanese", r.leftOnly, ["キウイフルーツ", "りんご"])

// E-mail only
let mail = Options(emailOnly: true)
r = ListComparison.compare("""
名前,メール
山田 太郎 <Taro.Yamada@example.co.jp>
"Hanako" <hanako+news@example.com>, jiro@example.org; saburo@example.net
mailto:shiro@example.jp.
メモ：アドレスなし
ｇｏｒｏ＠ｅｘａｍｐｌｅ．ｃｏｍ
""", "taro.yamada@example.co.jp\njiro@example.org\nnew@example.com", options: mail)
check("mail left items", r.left.items, ["Taro.Yamada@example.co.jp", "hanako+news@example.com", "jiro@example.org", "saburo@example.net", "shiro@example.jp", "goro@example.com"])
check("mail skipped", r.left.skippedCount, 2)
check("mail leftOnly", r.leftOnly, ["hanako+news@example.com", "saburo@example.net", "shiro@example.jp", "goro@example.com"])
check("mail rightOnly", r.rightOnly, ["new@example.com"])
check("mail common", r.commonCount, 2)
r = ListComparison.compare("a@x.jp a@x.jp\nA@X.JP", "", options: mail)
check("mail duplicates", r.left.duplicateCount, 2)
r = ListComparison.compare("not-an-address@\n@example.com\nuser@localhost\nuser@x.c", "", options: mail)
check("mail invalid", r.left.items, [])
check("mail invalid skipped", r.left.skippedCount, 4)
r = ListComparison.compare("a@x.jp", "a@x.jp")
check("lines mode skipped", r.left.skippedCount, 0)

// Split into lines for display
check("split spaces", ListComparison.splitIntoLines("@a @b\n@c  @d\n", Options(splitAtSpaces: true)) ?? "nil", "@a\n@b\n@c\n@d\n")
check("split none chosen", ListComparison.splitIntoLines("@a @b", Options()) ?? "nil", "nil")
check("split nothing to do", ListComparison.splitIntoLines("a\nb\n", Options(splitAtCommas: true)) ?? "nil", "nil")
check("split keeps repeats", ListComparison.splitIntoLines("a,a，b", Options(splitAtCommas: true)) ?? "nil", "a\na\nb\n")
check("split email mode", ListComparison.splitIntoLines("a b", Options(splitAtSpaces: true, emailOnly: true)) ?? "nil", "nil")

// Ranges of common items (for dimming)
func texts(_ text: String, _ ranges: [NSRange]) -> [String] { ranges.map { (text as NSString).substring(with: $0) } }
var lt = "  a\nB\nc\nb\n", rt = "b\nd"
r = ListComparison.compare(lt, rt)
check("common ranges left", texts(lt, r.left.commonRanges), ["B", "b"])
check("common ranges right", texts(rt, r.right.commonRanges), ["b"])
lt = "😀 x, y"; rt = "y"
r = ListComparison.compare(lt, rt, options: Options(splitAtCommas: true))
check("ranges after emoji", texts(lt, r.left.commonRanges), ["y"])
lt = "山田 <ｔａｒｏ＠ｘ．ｊｐ>, b@x.jp\nメモ\n"; rt = "taro@x.jp"
r = ListComparison.compare(lt, rt, options: mail)
check("mail ranges", texts(lt, r.left.commonRanges), ["ｔａｒｏ＠ｘ．ｊｐ"])
check("mail fullwidth item", r.left.items, ["taro@x.jp", "b@x.jp"])
check("mail skipped lines", r.left.skippedCount, 1)

// Common list
r = ListComparison.compare("c\nA\nb", "a\nc\nd")
check("common", r.common, ["c", "A"])
check("common count", r.commonCount, 2)

// Column mode
let csv = Options(splitAtCommas: true, column: 2, skipHeader: true)
r = ListComparison.compare("名前,メール\n山田,a@x.jp\n\"鈴木, 花子\",\"b@x.jp\"\n佐藤\n", "メール\nb@x.jp\nc@x.jp", options: Options(splitAtCommas: true, column: 1, skipHeader: true))
check("column mismatch sides use same options", r.left.items.count, 3)
r = ListComparison.compare("名前,メール\n山田,a@x.jp\n\"鈴木, 花子\",\"b@x.jp\"\n佐藤\n", "", options: csv)
check("column items", r.left.items, ["a@x.jp", "b@x.jp"])
check("column skipped", r.left.skippedCount, 1)
let csvText = "名前,メール\n山田,a@x.jp\n"
r = ListComparison.compare(csvText, "メール\nx,a@x.jp", options: csv)
check("column ranges", texts(csvText, r.left.commonRanges), ["a@x.jp"])
r = ListComparison.compare("h\tx\n1\ty\n", "", options: Options(splitAtTabs: true, column: 2))
check("column no header skip", r.left.items, ["x", "y"])
check("column needs separators", Options(column: 2).usesColumn, false)
check("column off in email mode", Options(splitAtCommas: true, emailOnly: true, column: 2).usesColumn, false)
check("no split into lines in column mode", ListComparison.splitIntoLines("a,b", csv) ?? "nil", "nil")

var rightPlain = csv; rightPlain.column = 0
r = ListComparison.compare("名前,メール\n山田,a@x.jp\n鈴木,b@x.jp\n", "b@x.jp\nc@x.jp", options: csv, rightOptions: rightPlain)
check("column left, plain right: common", r.common, ["b@x.jp"])
check("column left, plain right: right only", r.rightOnly, ["c@x.jp"])

// Remove duplicates
check("dedupe lines", ListComparison.removingDuplicates("a\r\nB\r\n\r\nb\r\nc\r\na", Options()) ?? "nil", "a\r\nB\r\n\r\nc\r\n")
check("dedupe nothing", ListComparison.removingDuplicates("a\nb\n", Options()) ?? "nil", "nil")
check("dedupe separators", ListComparison.removingDuplicates("a b a\nc b", Options(splitAtSpaces: true)) ?? "nil", "a\nb\nc\n")
check("dedupe mail", ListComparison.removingDuplicates("山田 <a@x.jp>\nメモ\nA@X.JP, b@x.jp\n佐藤 a@x.jp\n", mail) ?? "nil", "山田 <a@x.jp>\nメモ\nA@X.JP, b@x.jp\n")
check("dedupe column", ListComparison.removingDuplicates("名前,メール\n山田,a@x.jp\n山田2,a@x.jp\n", csv) ?? "nil", "名前,メール\n山田,a@x.jp\n")

// Locate an item
check("firstRange", ListComparison.firstRange(of: "B", in: "a\n  b\n", Options()).map { NSStringFromRange($0) } ?? "nil", "{4, 1}")
check("firstRange missing", ListComparison.firstRange(of: "z", in: "a", Options()).map { NSStringFromRange($0) } ?? "nil", "nil")

// Merge
r = ListComparison.compare("c\nA\nb\na", "B\nd\nc\ne")
check("merged", r.merged, ["c", "A", "b", "d", "e"])
r = ListComparison.compare("c\nA\nb", "d\nB", options: Options(sortResults: true))
check("merged sorted", r.merged, ["A", "b", "c", "d"])
r = ListComparison.compare("山田 <A@x.jp>, b@x.jp", "a@x.jp\nc@x.jp", options: mail)
check("merged mail", r.merged, ["A@x.jp", "b@x.jp", "c@x.jp"])

// Files: encodings, write-back, backups
let folder = FileManager.default.temporaryDirectory.appendingPathComponent("ListMatchTests-\(ProcessInfo.processInfo.processIdentifier)")
try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
let sjis = folder.appendingPathComponent("名簿.csv")
try! "山田,a@x.jp\r\n鈴木,b@x.jp\r\n".data(using: .shiftJIS)!.write(to: sjis)
let read = try! ListFile.read(sjis)
check("read sjis text", read.text, "山田,a@x.jp\r\n鈴木,b@x.jp\r\n")
check("read sjis encoding", read.encoding, .shiftJIS)
let utf8 = folder.appendingPathComponent("list.txt")
try! "\u{FEFF}a\nb\n".data(using: .utf8)!.write(to: utf8)
check("read utf8", try! ListFile.read(utf8).encoding, .utf8)
let backupsBefore = Set((try? FileManager.default.contentsOfDirectory(atPath: ListFile.backupFolder.path)) ?? [])
check("write keeps sjis", try! ListFile.write("佐藤,c@x.jp\r\n", to: sjis, encoding: .shiftJIS), .shiftJIS)
check("written sjis", String(data: try! Data(contentsOf: sjis), encoding: .shiftJIS)!, "佐藤,c@x.jp\r\n")
check("falls back to utf8", try! ListFile.write("😀\n", to: sjis, encoding: .shiftJIS), .utf8)
let backupsAfter = Set((try? FileManager.default.contentsOfDirectory(atPath: ListFile.backupFolder.path)) ?? []).subtracting(backupsBefore)
check("backed up", backupsAfter.contains { $0.hasPrefix("名簿-") && $0.hasSuffix(".csv") }, true)
for name in backupsAfter { try? FileManager.default.removeItem(at: ListFile.backupFolder.appendingPathComponent(name)) }
var linked = LinkedFile(url: utf8, encoding: .utf8, date: ListFile.modificationDate(utf8))
check("not changed on disk", linked.changedOnDisk, false)
try! FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(60)], ofItemAtPath: utf8.path)
check("changed on disk", linked.changedOnDisk, true)
linked.url = folder.appendingPathComponent("missing.txt")
check("missing", linked.exists, false)
try? FileManager.default.removeItem(at: folder)

// Large list stays fast
let big = (0..<100_000).map { "user\($0)@example.com" }
let start = Date()
r = ListComparison.compare(big.joined(separator: "\n"), big.dropFirst(10).joined(separator: "\n") + "\nnew@example.com")
check("big leftOnly", r.leftOnly.count, 10)
check("big rightOnly", r.rightOnly, ["new@example.com"])
let elapsed = Date().timeIntervalSince(start)
check("big fast (<2s)", elapsed < 2, true)
let mailStart = Date()
r = ListComparison.compare(big.map { "User \($0) <\($0)>" }.joined(separator: "\n"), big.joined(separator: "\n"), options: mail)
check("big mail common", r.commonCount, 100_000)
let mailElapsed = Date().timeIntervalSince(mailStart)
check("big mail fast (<3s)", mailElapsed < 3, true)

print("\(count - failures)/\(count) passed (100k lines: \(String(format: "%.2f", elapsed))s, e-mail mode: \(String(format: "%.2f", mailElapsed))s)")
exit(failures == 0 ? 0 : 1)
