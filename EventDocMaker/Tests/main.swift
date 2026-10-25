import Foundation

var failures = 0
func check(_ condition: Bool, _ message: String) {
    if !condition { failures += 1; print("FAIL:", message) }
}

// Sheet parsing: tabs, full-width colon, Excel quoting with line breaks.
let sheet = "種別\tCSS Nite\nイベント名\t武器になるHTML\nタイトル（abc）\tweapon-html\n仮の日付\t20260208\n日付（Doorkeeper）\t2026-02-08 13:00\n" +
    "プロフィール\t\"1行目\n\n2行目\"\nDoorkeeperのURL\thttps://cssnite.doorkeeper.jp/events/123456\n開始時刻：13:00\n現在の人数\t6000\n" +
    "配信URL\thttps://youtu.be/abc?feature=share\nTwitterハッシュタグ\t#cssnite\nDoorkeeper購入者数（個人）\t64\nDoorkeeper購入者数（銀振）\t1\nDoorkeeper購入者数（法人）\t10\n" +
    "出演者名（2人目）\t-\nふりがな\tやまだ\nアーカイブ視聴\tyes\nnote（後日の販売）\thttps://note.com/x\n"
let fields = EventFields.parse(sheet)
check(fields["種別"] == "CSS Nite", "tab field")
check(fields["開始時刻"] == "13:00", "colon field")
check(fields["プロフィール"] == "1行目\n\n2行目", "quoted multi-line: \(fields["プロフィール"] ?? "nil")")

var read: [String] = []
let event = EventVariables(fields: fields, today: Date(timeIntervalSince1970: 0)) { path in read.append(path); return path.hasPrefix("Footer") ? "footer %Variable%EventName%" : nil }
check(event["EventCategoryShort"] == "cssnite" && event.isCSSNite, "category short")
check(event["EventSender"] == "seminar@cssnite.jp", "sender")
check(event["EventPath"] == "cssnite-20260208-weapon-html", "path: \(event["EventPath"])")
check(event["EventDate"] == "2026年2月8日（日）", "date: \(event["EventDate"])")
check(event["DayAfter"] == "2月9日", "day after")
check(event["EventDoorkeeperNum"] == "123456", "doorkeeper number")
check(event["EventContactFormURL"] == "https://cssnite.doorkeeper.jp/contact/new?event_id=123456", "contact URL")
check(event["EventNumParticipants"] == "6,000", "localized number")
check(event["EventNumViewers"] == "0", "empty number is 0 like Number('')")
check(event["EventYouTubeChatURL"] == "https://www.youtube.com/live_chat?is_popout=1&v=abc", "chat URL: \(event["EventYouTubeChatURL"])")
check(event["EventTwitterHashtagEncode"] == "%23cssnite" && event["EventLiveHashTagURL"].contains("q=%23cssnite"), "hashtag")
check(event["EventDoorkeeperPurchasedSum"] == "253,330" && event["EventDoorkeeperPurchasedNumSum"] == "75", "sales sum")
check(event["EventSpeaker2"] == "", "speaker2 dash")
check(event["EventSpeakerFurigana"] == "（やまだ）", "furigana")
check(event["EventSpeakerProfileEdit"] == "1行目\n2行目", "profile edit: \(event["EventSpeakerProfileEdit"])")
check(event["EventArchiveNoteInfo"].contains("https://note.com/x") && event["EventArchiveNoteInfo"].contains("34%OFF"), "archive note")
check(event["EventFooter"] == "footer 武器になるHTML", "doc read and tokens expanded")
check(event.missingDocs.contains("Guide/EventLiveStreamGuide-YouTube-cssnite.txt"), "missing doc reported")
check(event.missingRequired.isEmpty, "required present")
check(EventVariables(fields: [:], readDoc: { _ in "" }).missingRequired == ["種別", "仮の日付", "タイトル（abc）"], "required missing")

// Tokens
check(Tokens.expand("a %Variable%X% b %Variable%Nope% c %X% d %Unknown% 100%%", ["X": "1"]) == "a 1 b  c 1 d %Unknown% 100%", "tokens")
check(Tokens.names(in: "%Variable%A% %Variable%B%") == ["A", "B"], "names")

// QR
check(Generator.qrPNG("https://example.com", size: 500)?.count ?? 0 > 100, "qr png")

// Generation into a temporary folder.
let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("EventDocMakerTest-\(UUID().uuidString)")
let places = Locations(root: tmp.appendingPathComponent("root").path, eventDoc: tmp.appendingPathComponent("EventDoc").path, recent: tmp.appendingPathComponent("recent").path)
try! FileManager.default.createDirectory(at: places.templates.appendingPathComponent("backup"), withIntermediateDirectories: true)
try! FileManager.default.createDirectory(atPath: places.recent, withIntermediateDirectories: true)
try! "%Variable%EventName% %Variable%EventDate% %Variable%EventEmptyOne%".write(to: places.templates.appendingPathComponent("01-a.md"), atomically: true, encoding: .utf8)
try! "stores %Variable%EventNameABC%".write(to: places.templates.appendingPathComponent("99-stores.txt"), atomically: true, encoding: .utf8)
try! "x".write(to: places.templates.appendingPathComponent(".DS_Store"), atomically: true, encoding: .utf8)
do {
    let result = try Generator.run(event, at: places, makeQR: true)
    let docs = result.folder.appendingPathComponent("docs")
    check(result.written == ["01-a.md", "99-stores.txt"], "written: \(result.written)")
    check((try? String(contentsOf: docs.appendingPathComponent("01-a.md"), encoding: .utf8)) == "武器になるHTML 2026年2月8日（日） ", "expanded template")
    check(result.storesCopy == "CeeBeeDee-20260208-weapon-html.txt", "stores copy")
    check(result.qrCodes.sorted() == ["qr-Doorkeeper-cssnite-20260208-weapon-html.png", "qr-YouTube-cssnite-20260208-weapon-html.png"], "qr: \(result.qrCodes)")
    check(result.emptyVariables == ["EventEmptyOne"], "empty variables")
    check((try? FileManager.default.destinationOfSymbolicLink(atPath: places.recent + "/cssnite-20260208-weapon-html")) == result.folder.path, "recent link")
    _ = try Generator.run(event, at: places, makeQR: false)  // Running again replaces the files and the link.
    check(FileManager.default.fileExists(atPath: docs.appendingPathComponent("CeeBeeDee-20260208-weapon-html.txt").path), "rerun")
} catch { check(false, "generation threw \(error)") }
try? FileManager.default.removeItem(at: tmp)

if failures == 0 { print("PASS: sheet parsing, variables, tokens, QR, generation") } else { print("\(failures) failure(s)"); exit(1) }
