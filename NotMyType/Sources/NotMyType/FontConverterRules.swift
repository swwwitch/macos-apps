import Foundation

/// 「Illustratorのフォントを統一」の変換ルール。ai-scripts の AiFontConverter.jsx（v1.1.8）の名前の分解・組み立てを写したもの。
/// Illustrator の中の操作（使われているフォントを集める・置き換える）は IllustratorFontConverter.swift の JSX で行う
struct ConverterSettings: Equatable {
    enum Target: String, CaseIterable { case selection, document, artboard }
    /// 現状維持・なし・あり
    enum Switch: String, CaseIterable { case keep, off, on }

    var target: Target = .selection
    /// nil は現状維持。Std / Pro / Pr5 / Pr6
    var charset: String?
    var n: Switch = .keep
    var nt: Switch = .keep
    var ud: Switch = .keep
    var p: Switch = .keep
    /// Max・MaxN を押した（AXIS を ProN に寄せる）。文字セット・N を手で変えたら外す
    var maxPreset = false
    var integrateGakusan = true
    var includeStyles = true
    var includeLocked = false
    var includeHidden = false

    /// スタイルの変更はドキュメント全体のときだけ（範囲外で同じスタイルを使うテキストまで変わるため）
    var appliesToStyles: Bool { target == .document && includeStyles }
}

enum FontConverterRules {
    struct Family {
        let label: String
        let baseName: String
        let pattern: String
        var supportsP: Bool { pattern.contains("(P)") }
        var supportsUD: Bool { pattern.contains("(UD)") }
        var supportsNT: Bool { pattern.contains("(NT)") }
    }

    /// 変換するファミリー（AiFontConverter の FONT_FAMILIES）。最後のグループがウェイト、それ以外は値（P / UD / NT / 文字セット / N）で見分ける
    static let families: [Family] = [
        Family(label: "見出ミンMA31", baseName: "MidashiMinMA31", pattern: #"^(P)?MidashiMinMA31(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "見出ゴMB31", baseName: "MidashiGoMB31", pattern: #"^(P)?MidashiGoMB31(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "太ミンA101", baseName: "FutoMinA101", pattern: #"^(P)?FutoMinA101(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "ゴシックMB101", baseName: "GothicMB101", pattern: #"^(P)?GothicMB101(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "UD新ゴ コンデンス90", baseName: "ShinGoCOniz", pattern: #"^(P)?(UD)?ShinGoCOniz(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "UD新ゴ コンデンス80", baseName: "ShinGoCOeiz", pattern: #"^(P)?(UD)?ShinGoCOeiz(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "UD新ゴ コンデンス70", baseName: "ShinGoCOsez", pattern: #"^(P)?(UD)?ShinGoCOsez(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "UD新ゴ コンデンス60", baseName: "ShinGoCOsiz", pattern: #"^(P)?(UD)?ShinGoCOsiz(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "UD新ゴ コンデンス50", baseName: "ShinGoCOfiz", pattern: #"^(P)?(UD)?ShinGoCOfiz(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "見出ミン", baseName: "MidashiMin", pattern: #"^MidashiMin(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "太ゴB101", baseName: "FutoGoB101", pattern: #"^(P)?FutoGoB101(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "新正楷書CBSK1", baseName: "ShinseiKai", pattern: #"^ShinseiKai(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "凸版文久明朝", baseName: "BunkyuMin", pattern: #"^(P)?BunkyuMin(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "中ゴシックBBB", baseName: "GothicBBB", pattern: #"^(P)?GothicBBB(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "見出ゴ", baseName: "MidashiGo", pattern: #"^MidashiGo(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "正楷書CB1", baseName: "SeiKaiCB1", pattern: #"^(P)?SeiKaiCB1(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "黎ミンY10", baseName: "ReimYonz", pattern: #"^(P)?ReimYonz(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "黎ミンY20", baseName: "ReimYtwz", pattern: #"^(P)?ReimYtwz(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "黎ミンY30", baseName: "ReimYthz", pattern: #"^(P)?ReimYthz(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "黎ミンY40", baseName: "ReimYfoz", pattern: #"^(P)?ReimYfoz(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "秀英明朝", baseName: "ShueiMin", pattern: #"^(P)?ShueiMin(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "凸版文久ゴシック", baseName: "BunkyuGo", pattern: #"^(P)?BunkyuGo(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "新丸ゴ", baseName: "ShinMGo", pattern: #"^(P)?(UD)?ShinMGo(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "リュウミン", baseName: "Ryumin", pattern: #"^(P)?Ryumin(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "新ゴ / 新ゴNT", baseName: "ShinGo", pattern: #"^(P)?(UD)?ShinGo(NT)?(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "UD黎ミン", baseName: "Reimin", pattern: #"^(P)?(UD)?Reimin(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "游明朝体", baseName: "YuMin", pattern: #"^YuMin(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "黎ミン", baseName: "Reim", pattern: #"^(P)?Reim(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "游ゴシック体", baseName: "YuGo", pattern: #"^YuGo(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "セザンヌ", baseName: "Cezanne", pattern: #"^(P)?Cezanne(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "DNP 秀英明朝", baseName: "FOT_DNPShueiMin", pattern: #"^(P)?FOT_DNPShueiMin(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "ハミング", baseName: "Humming", pattern: #"^(P)?Humming(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "マティス", baseName: "Matisse", pattern: #"^(P)?Matisse(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "モード明朝Aラージ", baseName: "ModeMinALarge", pattern: #"^(P)?ModeMinALarge(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "モード明朝Bラージ", baseName: "ModeMinBLarge", pattern: #"^(P)?ModeMinBLarge(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "ニューセザンヌ", baseName: "NewCezanne", pattern: #"^(P)?NewCezanne(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "ニューグレコ", baseName: "NewGreco", pattern: #"^(P)?NewGreco(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "ニューロダン", baseName: "NewRodin", pattern: #"^(P)?NewRodin(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "ロダン", baseName: "Rodin", pattern: #"^(P)?Rodin(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "スーラ", baseName: "Seurat", pattern: #"^(P)?Seurat(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "スキップ", baseName: "Skip", pattern: #"^(P)?Skip(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "テロップ明朝", baseName: "TelopMin", pattern: #"^(P)?TelopMin(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "筑紫A見出ミン", baseName: "TsukuAMDMin", pattern: #"^(P)?TsukuAMDMin(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "筑紫Aオールド明朝", baseName: "TsukuAOldMin", pattern: #"^(P)?TsukuAOldMin(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "筑紫Aヴィンテージ明L", baseName: "TsukuAVintageMinL", pattern: #"^(P)?TsukuAVintageMinL(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "筑紫Aヴィンテージ明S", baseName: "TsukuAVintageMinS", pattern: #"^(P)?TsukuAVintageMinS(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "筑紫B見出ミン", baseName: "TsukuBMDMin", pattern: #"^(P)?TsukuBMDMin(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "筑紫B明朝", baseName: "TsukuBMin", pattern: #"^(P)?TsukuBMin(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "筑紫Bオールド明朝", baseName: "TsukuBOldMin", pattern: #"^(P)?TsukuBOldMin(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "筑紫Bヴィンテージ明L", baseName: "TsukuBVintageMinL", pattern: #"^(P)?TsukuBVintageMinL(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "筑紫Bヴィンテージ明S", baseName: "TsukuBVintageMinS", pattern: #"^(P)?TsukuBVintageMinS(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "筑紫C見出ミン", baseName: "TsukuCMDMin", pattern: #"^(P)?TsukuCMDMin(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "筑紫Cオールド明朝", baseName: "TsukuCOldMin", pattern: #"^(P)?TsukuCOldMin(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "筑紫Cヴィンテージ明L", baseName: "TsukuCVintageMinL", pattern: #"^(P)?TsukuCVintageMinL(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "筑紫Cヴィンテージ明S", baseName: "TsukuCVintageMinS", pattern: #"^(P)?TsukuCVintageMinS(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "筑紫ゴシック", baseName: "TsukuGo", pattern: #"^(P)?TsukuGo(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "筑紫明朝", baseName: "TsukuMin", pattern: #"^(P)?TsukuMin(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "筑紫新聞明朝", baseName: "TsukuNewsMin", pattern: #"^(P)?TsukuNewsMin(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "UD角ゴ_ラージ", baseName: "UDKakugo_Large", pattern: #"^(P)?UDKakugo_Large(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "UD角ゴ_スモール", baseName: "UDKakugo_Small", pattern: #"^(P)?UDKakugo_Small(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "UD丸ゴ_ラージ", baseName: "UDMarugo_Large", pattern: #"^(P)?UDMarugo_Large(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "UD丸ゴ_スモール", baseName: "UDMarugo_Small", pattern: #"^(P)?UDMarugo_Small(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),
        Family(label: "UD明朝", baseName: "UDMincho", pattern: #"^(P)?UDMincho(?:(Pro|Pr5|Pr6|Std)(N)?)?-(.+)$"#),    ]

    /// AXIS：1=幅（Basic・Cond・Comp）2=文字セット（Std・Pro・Joyo）3=N 4=ウェイト
    static let axisPattern = #"^Axis(Basic|Cond|Comp)?(Std|Pro|Joyo)?(N)?-(.+)$"#

    /// 太さが同じメンバーを PostScript 名で結ぶシリーズ（A1明朝は Std が Bold だけで、A P-OTF StdN の Regular と同じ太さ）
    static let specialSeries: [[String: String]] = [
        ["Std": "A1MinchoStd-Bold", "StdN": "PA1MinchoStdN-Regular"],
    ]

    /// G-OTF の学参・常改・K書体の接頭辞（長い順に試す）
    static let gakusanPrefixes = ["GJ", "G", "K"]
    /// CID（文字セットの表記なし）を OTF にするとき、文字セットが現状維持なら補う文字セット
    static let cidFallbackCharset = "Pr6"
    /// 近いウェイトを探す並び（軽い → 重い）
    static let weightOrder = ["Light", "Regular", "Medium", "DemiBold", "Demi", "DeBold", "Bold", "ExtraBold", "ExBold",
                              "Heavy", "ExtraHeavy", "ExHeavy", "Ultra"]

    private nonisolated(unsafe) static var compiled: [String: NSRegularExpression] = [:]
    private static let lock = NSLock()

    private static func groups(_ pattern: String, _ name: String) -> [String?]? {
        let regex: NSRegularExpression? = lock.withLock {
            if let cached = compiled[pattern] { return cached }
            let made = try? NSRegularExpression(pattern: pattern)
            compiled[pattern] = made
            return made
        }
        guard let regex, let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)) else { return nil }
        return (0..<match.numberOfRanges).map { index in
            Range(match.range(at: index), in: name).map { String(name[$0]) }
        }
    }

    /// 変換先の候補。series は特殊シリーズの決まった名前、nameHead はウェイトの前まで（末尾は「-」）
    struct Plan {
        var desired: String
        var nameHead: String?
        var weight: String?
    }

    /// 旧名から変換先を決める。変換しない・変化しないときは nil
    static func plan(_ oldName: String, _ settings: ConverterSettings) -> Plan? {
        // Swift 6.4 の最適化（-O）が if let / guard let を重ねた形で SIL の検証に落ちるので、分けて書く
        for series in specialSeries {
            for (sourceKey, member) in series where member == oldName {
                let target = series[seriesTargetKey(sourceKey, settings)] ?? oldName
                return target == oldName ? nil : Plan(desired: target)
            }
        }
        if let axis = groups(axisPattern, oldName) {
            return axisPlan(oldName, axis, settings)
        }
        guard let parsed = parse(oldName, settings) else { return nil }
        return plan(oldName, head: nameHead(parsed, settings), weight: parsed.weight)
    }

    private static func axisPlan(_ oldName: String, _ axis: [String?], _ settings: ConverterSettings) -> Plan? {
        let width = axis[1] ?? ""
        let charset = axis[2] ?? ""
        let weight = axis[4] ?? ""
        let head = axisNameHead(width: width, charset: charset, hasN: axis[3] != nil, settings)
        return plan(oldName, head: head, weight: weight)
    }

    private static func plan(_ oldName: String, head: String, weight: String) -> Plan? {
        let desired = head + weight
        return desired == oldName ? nil : Plan(desired: desired, nameHead: head, weight: weight)
    }

    /// Illustrator にあるか確かめる名前：変換先と、同じ頭で別のウェイトのもの
    static func probeNames(_ plan: Plan) -> [String] {
        guard let head = plan.nameHead else { return [plan.desired] }
        return [plan.desired] + weightOrder.map { head + $0 }
    }

    enum Change: Hashable {
        case direct(old: String, new: String)
        case nearestWeight(old: String, new: String, oldWeight: String, newWeight: String)
        case missing(old: String, new: String)

        var old: String {
            switch self { case .direct(let old, _), .nearestWeight(let old, _, _, _), .missing(let old, _): return old }
        }
        var new: String {
            switch self { case .direct(_, let new), .nearestWeight(_, let new, _, _), .missing(_, let new): return new }
        }
    }

    /// あるフォントの名前の集合（Illustrator に問い合わせた結果）で、そのまま・近いウェイト・未インストールに分ける
    static func classify(_ oldName: String, _ plan: Plan, installed: Set<String>) -> Change {
        if installed.contains(plan.desired) { return .direct(old: oldName, new: plan.desired) }
        if let head = plan.nameHead, let weight = plan.weight, let index = weightOrder.firstIndex(of: weight) {
            // 同じ距離なら重い方を先に
            for distance in 1..<weightOrder.count {
                for candidate in [index + distance, index - distance] where weightOrder.indices.contains(candidate) {
                    if installed.contains(head + weightOrder[candidate]) {
                        return .nearestWeight(old: oldName, new: head + weightOrder[candidate], oldWeight: weight, newWeight: weightOrder[candidate])
                    }
                }
            }
        }
        return .missing(old: oldName, new: plan.desired)
    }

    // MARK: 名前の分解・組み立て

    struct Parsed {
        var family: Family
        var isP = false, isUD = false, isNT = false, hasN = false
        var charset = ""
        var weight = ""
    }

    static func parse(_ name: String, _ settings: ConverterSettings) -> Parsed? {
        if let parsed = parseKnown(name) { return parsed }
        guard settings.integrateGakusan else { return nil }
        for prefix in gakusanPrefixes where name.hasPrefix(prefix) {
            if let parsed = parseKnown(String(name.dropFirst(prefix.count))) { return parsed }
        }
        return nil
    }

    private static func parseKnown(_ name: String) -> Parsed? {
        for family in families {
            guard let matched = groups(family.pattern, name) else { continue }
            var parsed = Parsed(family: family)
            parsed.weight = matched.last.flatMap { $0 } ?? ""
            for value in matched.dropFirst().dropLast().compactMap({ $0 }) {
                switch value {
                case "P": parsed.isP = true
                case "UD": parsed.isUD = true
                case "NT": parsed.isNT = true
                case "N": parsed.hasN = true
                case "Pro", "Pr5", "Pr6", "Std": parsed.charset = value
                default: break
                }
            }
            return parsed
        }
        return nil
    }

    private static func apply(_ value: Bool, _ mode: ConverterSettings.Switch) -> Bool {
        switch mode { case .keep: return value; case .off: return false; case .on: return true }
    }

    static func nameHead(_ parsed: Parsed, _ settings: ConverterSettings) -> String {
        let family = parsed.family
        // CID（文字セットの表記なし）は OTF にする。現状維持なら Pr6 を補う
        let wanted = settings.charset ?? ""
        let original = parsed.charset.isEmpty ? cidFallbackCharset : parsed.charset
        let charset = String(wanted.isEmpty ? original : wanted)
        let isP = family.supportsP && apply(parsed.isP, settings.p)
        let isUD = family.supportsUD && apply(parsed.isUD, settings.ud)
        let isNT = family.supportsNT && apply(parsed.isNT, settings.nt)
        let hasN = apply(parsed.hasN, settings.n)
        return (isP ? "P" : "") + (isUD ? "UD" : "") + family.baseName + (isNT ? "NT" : "")
            + (charset.isEmpty ? "" : charset + (hasN ? "N" : "")) + "-"
    }

    static func axisNameHead(width: String, charset: String, hasN: Bool, _ settings: ConverterSettings) -> String {
        // Max・MaxN のときは AXIS の収録最多の ProN に寄せる（AXIS は Std と ProN だけ）
        if settings.maxPreset { return "Axis" + width + "ProN-" }
        // Joyo は別体系なのでそのまま
        if charset == "Joyo" { return "Axis" + width + "Joyo-" }
        // AXIS は Std・Pro だけ。Pr5・Pr6・現状維持はそのまま
        // 設定の文字セットと元の文字セットのどちらかを選ぶ形にすると -O で SIL の検証に落ちるので、条件を真偽値に分ける
        let wanted = settings.charset ?? ""
        let useWanted = wanted == "Std" || wanted == "Pro"
        let target = String(useWanted ? wanted : charset)
        let withN = apply(hasN, settings.n)
        return "Axis" + width + (target.isEmpty ? "" : target + (withN ? "N" : "")) + "-"
    }

    private static func seriesTargetKey(_ sourceKey: String, _ settings: ConverterSettings) -> String {
        let sourceHasN = sourceKey.hasSuffix("N")
        let base = sourceHasN ? String(sourceKey.dropLast()) : sourceKey
        let wanted = settings.charset ?? ""
        return String(wanted.isEmpty ? base : wanted) + (apply(sourceHasN, settings.n) ? "N" : "")
    }
}
