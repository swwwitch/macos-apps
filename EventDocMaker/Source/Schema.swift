import Foundation

/// One input field of an event. `key` is unique; `excelLabel` is the label in column A of the sheet
/// (several rows share a label, told apart by `occurrence`). The key is also the label handed to EventVariables.
struct Field: Identifiable, Hashable {
    enum Tab: String, CaseIterable { case before, after }
    enum Kind { case text, multiline, compactDate, isoDate, time, number }
    /// How the sheet's formatting column turned an empty value into text for the documents.
    /// .omit: the sheet never passed these on (outside its export range), so an empty one stays empty.
    enum Empty { case dash, zero, preparing, omit }
    let key: String
    let excelLabel: String
    let occurrence: Int
    let tab: Tab
    let group: String
    let kind: Kind
    let empty: Empty
    var id: String { key }
}

enum Schema {
    private static func f(_ key: String, _ tab: Field.Tab, _ group: String, _ kind: Field.Kind = .text, excel: String? = nil, occurrence: Int = 1, empty: Field.Empty = .dash) -> Field {
        Field(key: key, excelLabel: excel ?? key, occurrence: occurrence, tab: tab, group: group, kind: kind, empty: empty)
    }
    /// In the order of the sheet's rows 3–129.
    static let fields: [Field] = [
        f("#", .before, "basic", .number),
        f("フォルダー名", .before, "basic"),
        f("種別", .before, "basic"),
        f("仮の日付", .before, "basic", .compactDate),
        f("タイトル（abc）", .before, "basic"),
        f("タイトル＋講演者", .before, "basic", excel: "　タイトル＋講演者"),
        f("イベント名", .before, "basic"),
        f("概要", .before, "basic", .multiline),
        f("DoorkeeperのURL", .before, "schedule"),
        f("日付（Doorkeeper）", .before, "schedule"),
        f("OGP", .before, "basic"),
        f("Notion", .before, "basic"),
        f("配信方法", .before, "streaming"),
        f("配信URL", .before, "streaming"),
        f("Twitterハッシュタグ", .before, "streaming"),
        f("Togetter", .after, "videos"),
        f("参加費", .before, "schedule"),
        f("開始時刻", .before, "schedule", .time),
        f("終了時刻", .before, "schedule", .time),
        f("現在の人数", .before, "schedule", .number),
        f("出演者名（1人目）", .before, "speaker"),
        f("出演者名（姓）", .before, "speaker"),
        f("Twitterアカウント", .before, "speaker"),
        f("Twitterアカウント@", .before, "speaker"),
        f("開始時のフォロワー数", .before, "speaker", .number),
        f("終了時のフォロワー数", .after, "speakerAfter", .number),
        f("差分", .after, "speakerAfter", .number),
        f("メールアドレス", .before, "speaker"),
        f("出演者名（2人目）", .before, "speaker"),
        f("出演者名（姓）（2人目）", .before, "speaker"),
        f("Twitterアカウント（2人目）", .before, "speaker"),
        f("Twitterアカウント@（2人目）", .before, "speaker"),
        f("講演者への申し送りNotion", .before, "speaker"),
        f("Notion（配信）", .before, "streaming"),
        f("Slido管理画面", .before, "streaming"),
        f("Slido入力", .before, "streaming"),
        f("サブスク対象本数", .before, "sales", .number),
        f("STORES（経費）", .before, "sales"),
        f("STORES（法人）", .before, "sales"),
        f("note（後日の販売）", .before, "sales"),
        f("BOOTH", .before, "sales"),
        f("アンケート（参加者向け）", .before, "survey"),
        f("アンケート（編集）", .before, "survey"),
        f("アンケート（回答一覧）", .before, "survey"),
        f("アンケート回答期限", .before, "survey", .isoDate, empty: .preparing),
        f("Zoom", .before, "streaming"),
        f("Zoomパスコード", .before, "streaming"),
        f("アンケート回答者向けフォローアップ", .before, "survey"),
        f("アンケート回答特典", .before, "survey"),
        f("CommentScreen#", .before, "streaming"),
        f("CommentScreen", .before, "streaming"),
        f("Miro", .before, "streaming"),
        f("参加者属性", .after, "results"),
        f("Facebookイベント", .before, "schedule"),
        f("字幕URL", .before, "streaming"),
        f("字幕（Twitterスペース）", .before, "streaming"),
        f("ヨガあり", .before, "streaming"),
        f("アーカイブ視聴", .before, "sales"),
        f("動画A", .after, "videos"),
        f("動画B", .after, "videos"),
        f("動画（アフタートーク）", .after, "videos"),
        f("動画予備", .after, "videos"),
        f("動画（フル版）", .after, "videos"),
        f("YouTubeアーカイブA", .after, "videos"),
        f("YouTubeアーカイブB", .after, "videos"),
        f("YouTubeアーカイブC", .after, "videos"),
        f("YouTubeアーカイブD", .after, "videos"),
        f("YouTubeアーカイブ通し", .after, "videos"),
        f("最終人数", .after, "results", .number),
        f("総視聴数", .after, "results", .number),
        f("うちTwitter", .after, "results", .number),
        f("X：DTP Transit", .after, "x", .number),
        f("X：CSS Nite", .after, "x", .number),
        f("X：swwwitch", .after, "x", .number),
        f("Spend", .after, "xAds", .number),
        f("Impression", .after, "xAds", .number),
        f("Unique Impressions", .after, "xAds", .number),
        f("Impression Frequency", .after, "xAds", .number),
        f("Cost Per 1k Impressions", .after, "xAds", .number),
        f("Engagements", .after, "xAds", .number),
        f("Engagement Rate", .after, "xAds", .number),
        f("CSS Nite：Impression", .after, "cssAds", .number),
        f("CSS Nite：Spend", .after, "cssAds", .number, excel: "Spend", occurrence: 2),
        f("CSS Nite：Unique Impressions", .after, "cssAds", .number, excel: "Unique Impressions", occurrence: 2),
        f("CSS Nite：Impression Frequency", .after, "cssAds", .number, excel: "Impression Frequency", occurrence: 2),
        f("CSS Nite：Cost Per 1k Impressions", .after, "cssAds", .number, excel: "Cost Per 1k Impressions", occurrence: 2),
        f("CSS Nite：Engagements", .after, "cssAds", .number, excel: "Engagements", occurrence: 2),
        f("CSS Nite：Engagement Rate", .after, "cssAds", .number, excel: "Engagement Rate", occurrence: 2),
        f("同時接続数", .after, "results", .number),
        f("平均接続数", .after, "results", .number),
        f("視聴率", .after, "results", .number),
        f("YouTubeコメント数", .after, "youtube", .number),
        f("YouTubeコメント人数", .after, "youtube", .number),
        f("GOOD", .after, "youtube", .number),
        f("開演後のお申し込み人数", .after, "results", .number),
        f("開演後の比率", .after, "results", .number),
        f("Doorkeeper購入者数（個人）", .after, "sales", .number, empty: .zero),
        f("Doorkeeper購入者数（銀振）", .after, "sales", .number, empty: .zero),
        f("Doorkeeper購入者数（法人）", .after, "sales", .number, empty: .zero),
        f("Doorkeeper購入者数", .after, "sales", .number, empty: .zero),
        f("Doorkeeper売上", .after, "sales", .number, empty: .zero),
        f("Doorkeeper購入者数（一括）", .after, "sales", .number),
        f("Doorkeeper売上（一括）", .after, "sales", .number),
        f("STORES購入者数", .after, "sales", .number),
        f("STORES売上", .after, "sales", .number),
        f("スパチャ件数", .after, "sales", .number),
        f("スパチャ売上", .after, "sales", .number),
        f("アーカイブ売上", .after, "sales", .number),
        f("note売上", .after, "sales", .number),
        f("note売上件数", .after, "sales", .number),
        f("アンケート回答数", .after, "surveyResults", .number),
        f("アンケート回答比率", .after, "surveyResults", .number),
        f("ギャラ計算（概算）", .after, "surveyResults", .number),
        f("お名前", .before, "profile"),
        f("ふりがな", .before, "profile"),
        f("プロフィール画像", .before, "profile"),
        f("所属", .before, "profile"),
        f("Twitterアカウント（プロフィール）", .before, "profile", excel: "Twitterアカウント", occurrence: 2),
        f("プロフィール参照リンク1", .before, "profile"),
        f("プロフィール参照リンク1URL", .before, "profile"),
        f("プロフィール参照リンク2", .before, "profile"),
        f("プロフィール参照リンク2URL", .before, "profile"),
        f("プロフィール参照リンク3", .before, "profile"),
        f("プロフィール参照リンク3URL", .before, "profile"),
        f("セッション概要", .before, "profile", .multiline, empty: .omit),
        f("プロフィール", .before, "profile", .multiline, empty: .omit),
    ]
    static let groupsBefore = ["basic", "schedule", "streaming", "speaker", "profile", "sales", "survey"]
    static let groupsAfter = ["results", "youtube", "videos", "speakerAfter", "x", "xAds", "cssAds", "sales", "surveyResults"]
    static func field(_ key: String) -> Field? { fields.first { $0.key == key } }

    /// The text the sheet's formatting column produced for each row, which the documents were made from:
    /// empty or 0 → "-" (some rows "0" or 準備中), the survey deadline as "M月d日(aaa) 21:00", the profile followed by "∥".
    static func sheetValues(_ values: [String: String]) -> [String: String] {
        var out: [String: String] = [:]
        for field in fields where field.key != "#" {
            let raw = (values[field.key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let blank = raw.isEmpty || raw == "0"
            switch field.empty {
            case .zero: out[field.key] = raw.isEmpty ? "0" : raw
            case .preparing where blank: out[field.key] = "準備中"
            case .dash where blank: out[field.key] = "-"
            case .omit where blank: continue
            default: out[field.key] = raw
            }
            if field.key == "アンケート回答期限", !blank { out[field.key] = deadline(raw) }
            if field.key == "プロフィール", !blank { out[field.key] = raw + "∥" }
        }
        return out
    }
    static func deadline(_ iso: String) -> String {
        let input = DateFormatter(); input.locale = Locale(identifier: "en_US_POSIX"); input.dateFormat = "yyyy-MM-dd"
        guard let date = input.date(from: iso) else { return iso }
        let output = DateFormatter(); output.locale = Locale(identifier: "ja_JP"); output.calendar = Calendar(identifier: .gregorian); output.dateFormat = "M月d日(EEE) "
        return output.string(from: date) + "21:00"
    }
}
