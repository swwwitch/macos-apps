import Foundation

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

/// Rows copied from the event sheet: "label<TAB>value" (or "label：value"), one per line.
/// Excel quotes cells that hold line breaks ("…"), so quoted values may span lines.
enum EventFields {
    static func parse(_ text: String) -> [String: String] {
        var result: [String: String] = [:]
        for row in rows(text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")) {
            guard let label = row.first?.trimmingCharacters(in: .whitespaces), !label.isEmpty else { continue }
            var value: String?
            if row.count >= 2 { value = row[1] }
            else if let range = label.range(of: "：") { value = String(label[range.upperBound...]); result[String(label[..<range.lowerBound])] = value; continue }
            // The first row with a label wins, as the original workflow searched from the top (Spend etc. appear twice).
            if let value, result[label] == nil { result[label] = value }
        }
        return result
    }

    /// Tab-separated rows with Excel's quoting ("" inside quotes is one quote).
    static func rows(_ text: String) -> [[String]] {
        var rows: [[String]] = [], row: [String] = [], cell = "", quoted = false
        var chars = Array(text)[...]
        while let c = chars.popFirst() {
            if quoted {
                if c == "\"" {
                    if chars.first == "\"" { cell.append("\""); chars.removeFirst() } else { quoted = false }
                } else { cell.append(c) }
            } else if c == "\"" && cell.isEmpty {
                quoted = true
            } else if c == "\t" {
                row.append(cell); cell = ""
            } else if c == "\n" {
                row.append(cell); rows.append(row); row = []; cell = ""
            } else { cell.append(c) }
        }
        if !cell.isEmpty || !row.isEmpty { row.append(cell); rows.append(row) }
        return rows
    }
}

/// %Variable%Name% (and %Name% for a known variable), as Keyboard Maestro's token processing does for these templates.
enum Tokens {
    static func expand(_ text: String, _ vars: [String: String]) -> String {
        guard text.contains("%") else { return text }
        let regex = try! NSRegularExpression(pattern: #"%%|%Variable%([^%\n]+)%|%([A-Za-z_][A-Za-z0-9_]*)%"#)
        let ns = text as NSString
        var out = "", last = 0
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            out += ns.substring(with: NSRange(location: last, length: match.range.location - last))
            let whole = ns.substring(with: match.range)
            if whole == "%%" { out += "%" }
            else if match.range(at: 1).location != NSNotFound { out += vars[ns.substring(with: match.range(at: 1))] ?? "" }
            else { let name = ns.substring(with: match.range(at: 2)); out += vars[name] ?? whole }
            last = match.range.location + match.range.length
        }
        out += ns.substring(from: last)
        return out
    }
    /// Variable names a template uses.
    static func names(in text: String) -> Set<String> {
        let regex = try! NSRegularExpression(pattern: #"%Variable%([^%\n]+)%"#)
        let ns = text as NSString
        return Set(regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range(at: 1)) })
    }
}

/// Builds the Event… variables from the sheet, in the same order and with the same texts as the original workflow.
struct EventVariables {
    private(set) var vars: [String: String] = [:]
    let fields: [String: String]
    /// Reads a file under the EventDoc folder (Guide/…, Footer/…); nil when missing.
    let readDoc: (String) -> String?
    var missingDocs: [String] = []

    subscript(_ name: String) -> String { vars[name] ?? "" }
    private mutating func set(_ name: String, _ template: String) { vars[name] = Tokens.expand(template, vars) }
    private mutating func field(_ label: String, _ name: String) { if let value = fields[label] { vars[name] = value } }
    private mutating func doc(_ path: String) -> String {
        if let text = readDoc(path) { return text }
        missingDocs.append(path); return ""
    }
    private static func grouped(_ text: String) -> String {
        text.replacingOccurrences(of: #"(\d{1,3})(?=(?:\d{3})+(?!\d))"#, with: "$1,", options: .regularExpression)
    }
    /// JavaScript's Number(x).toLocaleString(): "6000" → "6,000". Text that is not a number is kept as is.
    private static func localized(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return "0" }
        guard let number = Double(trimmed.replacingOccurrences(of: ",", with: "")) else { return text }
        let formatter = NumberFormatter(); formatter.numberStyle = .decimal; formatter.locale = Locale(identifier: "en_US"); formatter.maximumFractionDigits = 3
        return formatter.string(from: NSNumber(value: number)) ?? text
    }
    private static func date(_ date: Date, _ format: String) -> String {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "ja_JP"); formatter.calendar = Calendar(identifier: .gregorian); formatter.dateFormat = format
        return formatter.string(from: date)
    }

    init(fields: [String: String], today: Date = Date(), readDoc: @escaping (String) -> String?) {
        self.fields = fields; self.readDoc = readDoc
        build(today: today)
    }

    var isCSSNite: Bool { self["EventCategoryShort"] == "cssnite" }

    private mutating func build(today: Date) {
        set("EventDateToday", Self.date(today, "yyyy年M月d日[EEE]"))
        // Date
        field("日付（Doorkeeper）", "EventDateDoorkeeper")
        let doorkeeperDate = self["EventDateDoorkeeper"]
        if let match = doorkeeperDate.range(of: #"^(\d{4})-(\d{2})-(\d{2})"#, options: .regularExpression) {
            let parts = doorkeeperDate[match].split(separator: "-").map(String.init)
            vars["EventYear"] = parts[0]; vars["EventMonth"] = parts[1]; vars["EventDay"] = parts[2]
            var components = DateComponents(); components.year = Int(parts[0]); components.month = Int(parts[1]); components.day = Int(parts[2])
            let calendar = Calendar(identifier: .gregorian)
            if let day = calendar.date(from: components) {
                set("EventDate", Self.date(day, "yyyy年M月d日（eee）"))
                set("EventDateYMD", Self.date(day, "yyyy年M月d日"))
                set("EventWeekDay", Self.date(day, "eee"))
                set("EventDateOnly", Self.date(day, "yyyy年M月d日"))
                set("EventDateOnlyShort", Self.date(day, "M月d日"))
                if let next = calendar.date(byAdding: .day, value: 1, to: day) { set("DayAfter", Self.date(next, "M月d日")) }
                set("EventDateShort", Self.date(day, "M月d日[eee]"))
                set("EventDateShortParenthesis", Self.date(day, "M月d日（eee）"))
                set("EventMonthShort", Self.date(day, "M"))
            }
        }
        // Event
        field("タイトル（abc）", "EventDirectoryBase")
        field("種別", "EventCategory")
        vars["EventCategoryShort"] = self["EventCategory"].lowercased().replacingOccurrences(of: " ", with: "")
        vars["EventSenderAnother"] = self["EventCategoryShort"] + "@gmail.com"
        if isCSSNite {
            set("EventSender", "seminar@cssnite.jp")
            set("EventGuidance", "https://swwwitch.notion.site/CSS-Nite-759db2680bdc48c89db4a1bd217fc199")
            set("EventCategoryCounter", "DTP Transit")
        } else {
            set("EventSender", "seminar@dtp-transit.jp")
            set("EventGuidance", "https://swwwitch.notion.site/DTP-Transit-9de21d6afebf43389435edb74704662c")
            set("EventCategoryCounter", "CSS Nite")
        }
        field("イベント名", "EventName")
        field("タイトル（abc）", "EventNameABC")
        field("DoorkeeperのURL", "EventDoorkeeper")
        vars["EventDoorkeeperNum"] = self["EventDoorkeeper"].replacingOccurrences(of: #"^.+?\/events\/"#, with: "", options: .regularExpression)
        for (label, name) in [("OGP", "EventOPG"), ("概要", "EventDesription"), ("参加費", "EventFee"), ("開始時刻", "EventStart"), ("終了時刻", "EventEnd"),
                              ("出演者名（1人目）", "EventSpeaker"), ("出演者名（姓）", "EventSpeakerShort"), ("出演者名（2人目）", "EventSpeaker2")] { field(label, name) }
        // Kept as the original workflow left it: "-" clears it, anything else ends up as "さん".
        vars["EventSpeaker2"] = self["EventSpeaker2"] == "-" ? "" : "さん"
        field("メールアドレス", "EventSpeakerMail1")
        field("メールアドレス（2人目）", "EventSpeakerMail2")
        field("Twitterアカウント", "EventSpeakerTwitter")
        vars["EventSpeakerTwitterShort"] = self["EventSpeakerTwitter"].replacingOccurrences(of: "https://twitter.com/", with: "@", options: .caseInsensitive)
        field("Twitterアカウント（2人目）", "EventSpeakerTwitter2")
        vars["EventSpeakerTwitterShort2"] = self["EventSpeakerTwitter2"].replacingOccurrences(of: "https://twitter.com/", with: "@", options: .caseInsensitive)
        field("参加者属性", "EventParticipants")
        field("開演後のお申し込み人数", "EventParticipantsAfterOpen")
        if fields["配信URL"] != nil {
            field("配信URL", "EventYouTubeURL")
            vars["EventYouTubeChatURL"] = self["EventYouTubeURL"]
                .replacingOccurrences(of: "https://youtu.be/", with: "https://www.youtube.com/live_chat?is_popout=1&v=", options: .caseInsensitive)
                .replacingOccurrences(of: "https://youtube.com/live/", with: "https://www.youtube.com/live_chat?is_popout=1&v=", options: .caseInsensitive)
                .replacingOccurrences(of: "?feature=share", with: "", options: .caseInsensitive)
        }
        field("Zoom", "EventZoomURL")
        field("Zoomパスコード", "EventZoomPass")
        field("CommentScreen#", "EventCommentScreenTag")
        if fields["CommentScreenのURL"] == nil { field("CommentScreen", "EventCommentScreen") }
        vars["EventCommentScreenManage"] = self["EventCommentScreen"].replacingOccurrences(of: "comments?", with: "rooms/view?", options: .caseInsensitive)
        if fields["Twitterハッシュタグ"] != nil {
            field("Twitterハッシュタグ", "EventTwitterHashtag")
            vars["EventTwitterHashtagEncode"] = self["EventTwitterHashtag"].addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")) ?? ""
            set("EventLiveHashTagURL", "https://twitter.com/search?q=%Variable%EventTwitterHashtagEncode%&src=typed_query&f=live")
        }
        for (label, name) in [("Twitterスペース", "EventTwitterSpace"), ("アンケート（参加者向け）", "EventQuestionnaire"), ("アンケート（編集）", "EventQuestionnaireEdit"),
                              ("アンケート（回答一覧）", "EventQuestionnaireReview"), ("アンケート回答期限", "EventQuestionnaireDeadline"),
                              ("アンケート回答者向けフォローアップ", "EventQuestionnaireFollowup"), ("講演者への申し送りNotion", "EventNotionInfo"), ("Notion", "EventNotion"),
                              ("Togetter", "EventTogetter"), ("動画A", "EventMovieA"), ("動画B", "EventMovieB"), ("動画（アフタートーク）", "EventMovieAfterTalk"),
                              ("動画（フル版）", "EventMovieFull"), ("動画予備", "EventMovieMisc"), ("YouTubeアーカイブA", "EventMovieYTA"), ("YouTubeアーカイブB", "EventMovieYTB"),
                              ("YouTubeアーカイブC", "EventMovieYTC"), ("BOOTH", "EventBooth"), ("note（後日の販売）", "EventNote"), ("STORES（法人）", "EventStoresCompany"),
                              ("STORES（経費）", "EventStoresFreelance"), ("現在の人数", "EventNumParticipants"), ("アンケート回答者向けフォローアップ", "EventSpecialFollowupURL"),
                              ("アンケート回答特典", "EventQuestionnairePresent"), ("同時接続数", "EventNumYouTubeMaxStreamer"), ("平均接続数", "EventNumYouTubeAverageStreamer"),
                              ("最終人数", "EventNumParticipantsLast"), ("総視聴数", "EventNumViewers"), ("うちTwitter", "EventNumViewersTw"), ("Impression", "EventNumViewersImp"),
                              ("Spend", "EventNumViewersSpend")] { field(label, name) }
        vars["EventMovieA"] = self["EventMovieA"].trimmingCharacters(in: CharacterSet(charactersIn: "\u{200B}\u{FEFF}").union(.whitespacesAndNewlines))
        for name in ["EventNumParticipants", "EventNumParticipantsLast", "EventNumViewers", "EventNumViewersTw", "EventNumYouTubeMaxStreamer", "EventNumYouTubeAverageStreamer"] {
            vars[name] = Self.localized(self[name])
        }
        set("EventCategoryTwitterURL", isCSSNite ? "https://twitter.com/cssnite" : "https://twitter.com/DTP_Transit")
        field("字幕URL", "EventCCURL")
        field("字幕（Twitterスペース）", "EventCCTwSpaceURL")
        set("EventCC", "## 字幕\n\n文字情報が必要な方はブラウザーでご利用ください\n（スマホやタブレットなどの別デバイスでもOK）。\n\n%Variable%EventCCURL%\n\n※UDトークを使っています。精度、タイムラグはご容赦ください。")
        field("サブスク対象本数", "EventSubscriptionNum")
        field("Facebookイベント", "EventFacebookEventURL")
        // Streaming guide
        field("配信方法", "EventLiveStream")
        if self["EventLiveStream"] == "Zoomウェビナー" {
            set("EventLiveStreamGuide", doc("Guide/EventLiveStreamGuide-Zoom.txt"))
            set("EventLiveStreamGuideAlternative", "【参加者用のZoom URL】\n%Variable%EventZoomURL%")
            set("EventLiveStreamGuideHow2Q", "《質問》\n\nZoomの［Q&A］から入力してください。\n\n- 質問は匿名で送信できます。\n- 送信された質問は、参加者全員が見られます。\n- 「自分も聞きたい」とき、投票できます。\n- 質問には、補足や回答などをコメントできます（匿名にはできません）。\n- リアルタイムに拾うことはできません。<br />休憩の前後やアフタートークにて取り上げます（またはフォローアップにて）。\n\nCommentScreenを使う場合には、［質問として投稿］オプションをONにしてコメントを入力ください。")
            set("EventLiveStreamGuideHow2Qmd", "### 質問\n\nZoomの［Q&A］に入力してください。\n\n- 質問は匿名で送信できます。\n- 送信された質問は、参加者全員が見られます。\n- 「自分も聞きたい」とき、投票できます。\n- 質問には、補足や回答などをコメントできます（コメントは匿名にはできません）。\n- リアルタイムに拾うことはできません。休憩の前後やアフタートーク（またはフォローアップにて）にて取り上げます。\n\nCommentScreenを使う場合には、［質問として投稿］オプションをONにしてコメントを入力ください。")
        } else {
            set("EventLiveStreamGuideHow2Q", "- 流れてしまった後でも確認しやすいように、チャットのコメントに【質問】と添えて記入ください！\n- 現在、Slido、CommentScreenでの質問は受け付けていません。\n\n取り上げるタイミングなど：\n\n- できる限りリアルタイムに拾っていきます。\n- すべてはカバーできません。おわかりの方がいればサポートくださいますと助かります。\n- 質問だけでなく「自分はこうやっている」など、広がりのあるコメント、大歓迎です!!!")
            set("EventLiveStreamGuide", doc(isCSSNite ? "Guide/EventLiveStreamGuide-YouTube-cssnite.txt" : "Guide/EventLiveStreamGuide-YouTube.txt"))
            set("EventLiveStreamGuideAlternative", "%Variable%EventYouTubeURL%\n\n《YouTubeが重い場合》\n\nZoomをご利用ください。\n%Variable%EventZoomURL%\n\n・基本的にはYouTube Liveでご覧ください。\n・パスコードを求められる場合には「%Variable%EventZoomPass%」を入力してください\n\n《質問》\n\nZoomウェビナーのコメントに【質問】と添えて記入ください！（細かいことでも）\n\nリアルタイムにはお答えできませんが、アフタートークやフォローアップにて回答していきます。\n\n※「名前入り」で質問を書きにくい場合には、宛先を「ホストおよびパネリスト」にしてもOKです。\n")
        }
        // Archive
        field("アーカイブ視聴", "EventArchiveTicket")
        if self["EventArchiveTicket"] == "yes" {
            set("EventArchiveTicketInfo", "## STORESでアーカイブを購入された方\n\n① 各アイテムを購入いただくと、テキストファイルをダウンロードできます。\n② テキストファイルにはNotionのURLを掲載しています。\n③ そのNotionにスライドや動画へのURLを掲載していきます。\n\nスライドや動画はイベント終了後、五月雨で追加されていきます。\n\n### 備考\n\n- アーカイブ視聴のURLは、配信用のURL（当日のみ）とは異なります。\n- インボイス対応の領収書については[note](https://note.com/dtp_tranist/n/n6a84983155d2)をご覧ください。\n")
            set("EventArchiveTicketInfoAfter", "## STORESでアーカイブを購入された方\n\n① 各アイテムを購入いただくと、テキストファイルをダウンロードできます。\n② テキストファイルにはNotionのURLを掲載しています。\n③ そのNotionにスライドや動画へのURLを掲載していきます。\n\nスライドや動画はイベント終了後、五月雨で追加されていきます。\n\n### 備考\n\n- アーカイブ視聴のURLは、配信用のURL（当日のみ）とは異なります。\n- インボイス対応の領収書のダウンロードについてもお知らせします（[詳細](https://note.com/dtp_tranist/n/n6a84983155d2)）。\n")
            set("EventArchiveNoteInfo", "## アーカイブ動画\n\n「やっぱり、アーカイブを購入をしたい」、「じっくり復習したい」方のためにSTORESにてアーカイブを単品購入できます。\n%Variable%EventNote%\n\n後日の購入も可能ですが、終演時刻までは34%OFFです。")
            set("EventArchiveNoteInfoAfter", "## アーカイブ動画\n\n「やっぱり、アーカイブを購入をしたい」、「じっくり復習したい」方のためにSTORESにてアーカイブを単品購入できます。\n%Variable%EventNote%\n\n### Circle（サブスク）\n\n2024年以降の開催のすべてのイベントのアーカイブが見放題になるサブスクもあります。\nhttps://www.ceebeedee.space/c/archives/\n")
            set("EventArchiveTicketInfo2", "## アーカイブ動画\n\n「やっぱり、アーカイブを購入をしたい」、「じっくり復習したい」方のためにSTORESにてアーカイブを単品購入できます。\n%Variable%EventNote%\n\n後日の購入も可能ですが、終演時刻までは34%OFFです。\n\n### Circle（サブスク）\n\n2024年以降の開催のすべてのイベントのアーカイブが見放題になるサブスクもあります。\nhttps://www.ceebeedee.space/c/archives/")
        } else {
            for name in ["EventArchiveTicketInfo", "EventArchiveTicketInfoAfter", "EventArchiveNoteInfo", "EventArchiveTicketInfo2"] { vars[name] = "" }
            set("EventArchiveMovieInfo", "すでに動画も掲載しています。")
        }
        // Shared texts in the EventDoc folder
        set("EventFooter", doc(isCSSNite ? "Footer/EventFooter-cssnite.txt" : "Footer/EventFooter-dtptransit.txt"))
        vars["EventComingInfo"] = doc(isCSSNite ? "ComingInfo/ComingInfo-cssnite.md" : "ComingInfo/ComingInfo-dtptransit.md")
        vars["EventComingInfoSub"] = doc(isCSSNite ? "ComingInfo/ComingInfo-dtptransit.md" : "ComingInfo/ComingInfo-cssnite.md")
        vars["EventComingInfoTxt"] = doc(isCSSNite ? "ComingInfo/ComingInfo-cssnite-text.txt" : "ComingInfo/ComingInfo-dtptransit-text.txt")
        vars["EventArchiveAll"] = doc(isCSSNite ? "Archive/archive-cssnite.md" : "Archive/archive-dtptranist.md")
        vars["EventComingInfoURLcssnite"] = doc("ComingInfo/ComingInfo-cssnite-URL.txt")
        vars["EventComingInfoURLdtptransit"] = doc("ComingInfo/ComingInfo-dtptransit-URL.txt")
        set("EventComingInfoURL", isCSSNite ? "%Variable%EventComingInfoURLcssnite%\n\n%Variable%EventComingInfoURLdtptransit%" : "%Variable%EventComingInfoURLdtptransit%\n\n%Variable%EventComingInfoURLcssnite%")
        set("EventOrganizer", isCSSNite ? "- 主催：[CSS Nite](https://cssnite.jp/about/organizer.html)\n- 共催：[DTP Transit](https://note.com/dtp_tranist/)"
                                        : "- 主催：[DTP Transit](https://note.com/dtp_tranist/)\n- 共催：[CSS Nite](https://cssnite.jp/about/organizer.html)")
        if isCSSNite {
            set("EventMainColor", "#0AF"); set("EventSubColor", "rgb(0, 170, 255, 0.3)")
            set("EventContactFormURL", "https://cssnite.doorkeeper.jp/contact/new?event_id=%Variable%EventDoorkeeperNum%")
            set("EventYouTubeChannelRegistration", "https://www.youtube.com/channel/UCnkDJM9xSphSA_VTibyfWsA?sub_confirmation=1")
        } else {
            set("EventMainColor", "#993366"); set("EventSubColor", "rgba(60%, 20%, 40%, .2)")
            set("EventContactFormURL", "https://dtptransit.doorkeeper.jp/contact/new?event_id=%Variable%EventDoorkeeperNum%")
            set("EventYouTubeChannelRegistration", "http://www.youtube.com/channel/UC5YZ9UHoBWq5mKkQULUB42A?sub_confirmation=1")
        }
        if fields["Slido入力"] != nil {
            field("Slido入力", "EventSlidoURL"); field("Slido管理画面", "EventSlidoAdminURL")
            if self["EventSlidoURL"] == "-" { vars["EventSlidoMemo"] = "" }
            else { set("EventSlidoMemo", "## 質問\n\nSlidoを使います。\n\n- 匿名で送信できます。\n- 「この質問、自分も聞きたい！」に投票できます。\n\n%Variable%EventSlidoURL%") }
        }
        set("EventLiveStreamGuideHow2Qmd", "### 質問\n\n流れてしまった後でも確認しやすいように、YouTubeチャットのコメントには【質問】と添えて記入ください！\n\n- YouTubeチャット\n- アンケートに回答（※終了後）\n\nSlido、CommentScreenは現在、使っていません。\n\n\n《取り上げるタイミングなど》\n\n- できる限りリアルタイムに拾っていきます。\n- すべてはカバーできません。おわかりの方がいればサポートくださいますと助かります。\n- 質問だけでなく、「自分はこうやっている」など、広がりのあるコメント、大歓迎です!!!")
        field("ヨガあり", "EventYoga")
        if self["EventYoga"] == "yes" {
            set("EventYogaTimeline", "- 開演の30分前くらいからテスト配信（カウントダウン）をスタート予定です。\n- 開演の25分前から「椅子ヨガ」を予定しています。")
            set("EventYogaInfo", "## 「椅子ヨガ」を一緒にやりましょう！\n\n開演前と休憩時間に「椅子ヨガ」を予定しています。\nぜひ、ちょっとだけ早くログインして、一緒に「ちょっとメンテ」しましょう!!\n\n担当されるのは札幌でデザイン制作やイラストを描かれている「コモモ先生」です。\nhttps://chotto-maint.com/online-yoga#about\n\n※休憩時間は前後することがあります。\n\n[![](https://cssnite.jp/images/komomo-yoga.png)](https://chotto-maint.com/online-yoga#about)")
        } else {
            set("EventYogaTimeline", "- 15分前くらいからテスト配信（カウントダウン）をスタート予定です。")
            vars["EventYogaInfo"] = ""
        }
        if self["EventFee"] == "当日の視聴は無料" {
            set("EventRegisterDoorkeeper", "《フォローアップ》\nスライドやリンク集、補足はNotionにまとめています。URLはカウントダウンメールをご覧ください。\n（ギリギリに登録された方はフォローアップメールをお待ちください。終演時刻に再送予定）\n\nフォローアップが欲しい方はDoorkeeperにて登録ください。\n%Variable%EventDoorkeeper%\n（登録は終演予定時刻の%Variable%EventEnd%まで）")
        } else {
            set("EventRegisterDoorkeeper", "《フォローアップ》\nスライドやリンク集、補足はNotionにまとめています。\n%Variable%EventNotion%\n\n・本日の配信に関しての詳細情報\n・スライド、リンク集\n・終了後、翌日以降に動画を掲載\n\n")
        }
        // Speaker profile
        field("お名前", "EventSpeakerName")
        if let furigana = fields["ふりがな"] { vars["EventSpeakerFurigana"] = "（\(furigana)）" }
        field("所属", "EventSpeakerCompany")
        field("プロフィール画像", "EventSpeakerPic")
        field("プロフィール参照リンク1", "EventSpeakerProfileLink1"); field("プロフィール参照リンク1URL", "EventSpeakerProfileLinkURL1")
        for n in [2, 3] where fields["プロフィール参照リンク\(n)"] != nil {
            field("プロフィール参照リンク\(n)", "EventSpeakerProfileLink\(n)"); field("プロフィール参照リンク\(n)URL", "EventSpeakerProfileLinkURL\(n)")
            if self["EventSpeakerProfileLink\(n)"] != "-" {
                set("EventSpeakerProfileLink\(n)Text", "・%Variable%EventSpeakerProfileLink\(n)% %Variable%EventSpeakerProfileLinkURL\(n)%")
                set("EventSpeakerProfileLink\(n)Li", "<li><a href=\"%Variable%EventSpeakerProfileLinkURL\(n)%\">%Variable%EventSpeakerProfileLink\(n)%</a></li>")
            } else { vars["EventSpeakerProfileLink\(n)Text"] = ""; vars["EventSpeakerProfileLink\(n)Li"] = "" }
        }
        if let profile = fields["プロフィール"] {
            vars["EventSpeakerProfile"] = profile
            vars["EventSpeakerProfileEdit"] = profile.replacingOccurrences(of: #"\n{2,}"#, with: "〓", options: .regularExpression)
                .replacingOccurrences(of: "\n", with: "<br />").replacingOccurrences(of: "〓", with: "\n")
                .replacingOccurrences(of: #"<br />$"#, with: "", options: .regularExpression)
        }
        field("セッション概要", "EventSpeakerSessionInfo")
        field("Miro", "EventMiro"); field("GOOD", "EventYouTubeGOOD"); field("YouTubeコメント数", "EventYouTubeCommentNum")
        // Sales
        for (label, name) in [("Doorkeeper売上", "EventDoorkeeperEarnings"), ("Doorkeeper購入者数", "EventDoorkeeperPurchasedNum"), ("Doorkeeper購入者数（個人）", "EventDoorkeeperPurchasedNumPsnl"),
                              ("Doorkeeper購入者数（銀振）", "EventDoorkeeperPurchasedNumBank"), ("Doorkeeper購入者数（法人）", "EventDoorkeeperPurchasedNumCompany"),
                              ("STORES売上", "EventStoresEarnings"), ("STORES購入者数", "EventStoresNum"), ("アーカイブ売上", "EventEarningsSum"),
                              ("スパチャ件数", "EventSuperChatNum"), ("スパチャ売上", "EventSuperChatEarnings"), ("note売上", "EventNoteEarnings"), ("note売上件数", "EventNoteNum")] { field(label, name) }
        let psnl = Int(self["EventDoorkeeperPurchasedNumPsnl"]) ?? 0, bank = Int(self["EventDoorkeeperPurchasedNumBank"]) ?? 0, company = Int(self["EventDoorkeeperPurchasedNumCompany"]) ?? 0
        vars["EventDoorkeeperPurchasedSum"] = Self.grouped(String(psnl * 2200 + bank * 2530 + company * 11000))
        vars["EventDoorkeeperPurchasedNumSum"] = Self.grouped(String(psnl + bank + company))
        for name in ["EventDoorkeeperEarnings", "EventStoresEarnings", "EventEarningsSum", "EventSuperChatEarnings", "EventNoteEarnings"] { vars[name] = Self.grouped(self[name]) }
        // Folder
        field("仮の日付", "EventDateTemp")
        set("EventPath", "%Variable%EventCategoryShort%-%Variable%EventDateTemp%-%Variable%EventDirectoryBase%")
        set("EventDocStores", "CeeBeeDee-%Variable%EventDateTemp%-%Variable%EventNameABC%")
    }

    /// What is missing for creating the folder (category, provisional date, title (abc)).
    var missingRequired: [String] {
        [("種別", "EventCategoryShort"), ("仮の日付", "EventDateTemp"), ("タイトル（abc）", "EventDirectoryBase")].filter { self[$0.1].isEmpty }.map(\.0)
    }
}
