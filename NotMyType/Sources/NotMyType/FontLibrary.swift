import CryptoKit
import CoreText
import Foundation

/// フォントファイルに入っている書体1つ（.ttc などは1ファイルに複数）
struct FontFace: Codable, Hashable, Sendable {
    var postScriptName: String
    var family: String
    var style: String
    var fullName: String
    /// 日本語などの表示名（name テーブルのローカライズ名）。無ければ空。古い版のライブラリでは nil
    var localizedFamily: String?
    var localizedStyle: String?

    var displayFamily: String { localizedFamily.flatMap { $0.isEmpty ? nil : $0 } ?? family }
    var displayStyle: String { localizedStyle.flatMap { $0.isEmpty ? nil : $0 } ?? (style.isEmpty ? fullName : style) }
}

/// サイドバーの「種類」
/// サイドバーと検索オプションの「種類」
enum FontKind: String, CaseIterable, Hashable, Sendable {
    case variable, color, kana, icon
    var title: String {
        switch self {
        case .variable: return L("バリアブル")
        case .color: return L("カラーフォント")
        case .kana: return L("かなフォント")
        case .icon: return L("アイコンフォント")
        }
    }
    var symbol: String {
        switch self {
        case .variable: return "slider.horizontal.3"
        case .color: return "paintpalette"
        case .kana: return "character.ja"
        case .icon: return "star.square.on.square"
        }
    }
    func matches(_ file: FontFile) -> Bool {
        switch self {
        case .variable: return file.isVariable == true
        case .color: return file.isColor == true
        case .kana: return file.isKana == true
        case .icon: return file.isIcon == true
        }
    }
}

/// 検索オプションの「ファミリーの書体数」。ファミリーに入っている書体（ウエイト・スタイル）の数で分ける
enum FaceCountRange: Int, CaseIterable, Hashable, Sendable {
    case one, few, several, many
    var bounds: ClosedRange<Int> {
        switch self {
        case .one: return 1...1
        case .few: return 2...4
        case .several: return 5...9
        case .many: return 10...Int.max
        }
    }
    var title: String { self == .many ? L("10書体以上") : bounds.lowerBound == bounds.upperBound ? L("1書体") : L("%d〜%d書体", bounds.lowerBound, bounds.upperBound) }
    func contains(_ count: Int) -> Bool { bounds.contains(count) }
}

/// 検索オプションの書体の違い（AiFontConverter と同じ区分）。あり／なしで絞り込む。当てはまらないファイル（欧文など）は nil で、どちらにも入らない
enum VariantFilter: String, CaseIterable, Hashable, Sendable {
    /// N（JIS2004字形）：文字セットの名前が N で終わるか（StdN・ProN・Pr6N・PlusN）
    case n
    /// UD：日本語のフォントで、名前に UD が入るか
    case ud
    /// AP版：モリサワの A-OTF のうち、プロポーショナルの A P-OTF か
    case ap
    /// 新ゴ：新ゴか新ゴNTか
    case nt

    var title: String {
        switch self {
        case .n: return L("N（JIS2004対応）")
        case .ud: return L("UD")
        case .ap: return L("AP版")
        case .nt: return L("新ゴ")
        }
    }

    /// true・false の選択肢の名前
    func optionTitle(_ value: Bool) -> String {
        switch self {
        case .n: return value ? L("Nあり") : L("Nなし")
        case .ud: return value ? L("UDあり") : L("UDなし")
        case .ap: return value ? L("A P-OTF") : L("A-OTF")
        case .nt: return value ? L("新ゴNT") : L("新ゴ")
        }
    }

    func value(_ file: FontFile) -> Bool? {
        let postScript = file.faces.first?.postScriptName ?? ""
        switch self {
        case .n:
            return FontNaming.charset(file.family).map { $0.hasSuffix("N") }
        case .ud:
            guard file.supportsJapanese == true else { return nil }
            return file.family.contains("UD") || postScript.contains("UD")
        case .ap:
            if file.family.hasPrefix("A P-OTF") { return true }
            return file.family.hasPrefix("A-OTF") ? false : nil
        case .nt:
            guard postScript.contains("ShinGo") else { return nil }
            return postScript.contains("ShinGoNT")
        }
    }
}

/// 検索オプションの「収録文字数」。ファイルの先頭の書体の文字数で分ける
enum CharacterCountRange: Int, CaseIterable, Hashable, Sendable {
    case small, medium, large, larger, largest
    var bounds: ClosedRange<Int> {
        switch self {
        case .small: return 0...999
        case .medium: return 1_000...4_999
        case .large: return 5_000...9_999
        case .larger: return 10_000...14_999
        case .largest: return 15_000...Int.max
        }
    }
    var title: String {
        let format = { (value: Int) in value.formatted(.number) }
        return self == .largest ? L("%@文字以上", format(15_000))
            : L("%@〜%@文字", format(bounds.lowerBound), format(bounds.upperBound))
    }
    func contains(_ count: Int) -> Bool { bounds.contains(count) }
}

/// ライブラリに登録したフォントファイル。ファイルは動かさず、場所だけを覚える
struct FontFile: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var path: String
    var faces: [FontFace]
    var added = Date()
    /// OS/2 テーブルのベンダーID（MRSW＝モリサワ、FWKS＝フォントワークスなど）。無ければ空。古い版のライブラリでは nil
    var vendor: String?
    /// 商標の持ち主（name テーブルの商標・著作権の「trademark of …」から。ITC で始まる名前は ITC）。無ければ空、古い版のライブラリでは nil。
    /// ベンダーIDはファイルを作った会社なので、アドビが作ったモリサワ・Linotype の書体は ADBE になる。持ち主が分かればそちらを優先する
    var trademarkOwner: String?
    /// バリアブルフォント（fvar）・カラーフォント（COLR・sbix・CBDT・SVG）。古い版のライブラリでは nil
    var isVariable: Bool?
    var isColor: Bool?
    /// 収録文字数（cmap の文字の数）とグリフ数。かなフォントは、かなを持ち漢字をほとんど持たないもの。古い版のライブラリでは nil
    var characterCount: Int?
    var glyphCount: Int?
    /// head テーブルのフォントの版（fontRevision）。重複の優先の「バージョンが新しい」に使う。読めなければ 0、古い版のライブラリでは nil
    var fontRevision: Double?
    /// 中身の SHA-256（重複の優先の「中身が同じファイルは自動で決める」に使う）。決まらない重複の候補だけ裏で計る。読めなければ空、未計測は nil
    var contentHash: String?
    var isKana: Bool?
    /// 日本語をサポート：ひらがな・カタカナ（あ・ア）を持つ
    var supportsJapanese: Bool?
    /// アイコンフォント：欧文の拡張文字（ラテン文字拡張A）を持たず文字の半分以上が私用領域か、名前（Awesome・Icon など）（U+E000〜F8FF、第15・16面）か、フォントの分類が記号（Symbolic）
    var isIcon: Bool?
    /// 最後にアクティブにした・解除した日時（サイドバーの「最近アクティブ」「最近非アクティブ」）
    var activatedAt: Date?
    var deactivatedAt: Date?

    var url: URL { URL(fileURLWithPath: path) }
    var fileName: String { (path as NSString).lastPathComponent }
    /// ファミリー名は先頭の書体のもの（1ファイルに複数のファミリーが入ることはまれ）
    var family: String { faces.first?.family ?? fileName }
    var format: String {
        switch (path as NSString).pathExtension.lowercased() {
        case "otf": return "OpenType (CFF)"
        case "ttf": return "TrueType"
        case "ttc": return "TrueType Collection"
        case "otc": return "OpenType Collection"
        case "dfont": return "Datafork TrueType"
        case "woff", "woff2": return "WOFF"
        default: return (path as NSString).pathExtension.uppercased()
        }
    }
}

/// 名前を付けたフォントのまとまり。まとめてアクティブにできる
struct FontSet: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var files: [UUID] = []
}

/// プロジェクトの参照するファイル・フォルダー：制作ファイル（IDML・INDD・PDF・AI）、フォルダー（中の制作ファイルを全部。見張って自動で更新）、貼り付けたフォント名
struct ProjectSource: Codable, Identifiable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable { case file, folder, names }
    var id = UUID()
    var kind: Kind
    var path: String?
    var names: [String] = []
}

/// プロジェクトの候補：表記が少し異なってライブラリのファイルに当たったフォント名（承認するまで入れない）
struct ProjectCandidate: Codable, Hashable, Sendable {
    var name: String
    var file: UUID
}

/// 案件ごとのフォントのまとまり（セットとは別）。sources から集めたフォント名をライブラリと照合した結果を files・candidates・missing に持つ。
/// 候補は approved に入れたものだけ files に入る
struct FontProject: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var sources: [ProjectSource] = []
    var approved: Set<String> = []
    /// PostScript名が完全に一致したファイル。files はこれと承認した候補のファイル
    var matched: [UUID] = []
    var files: [UUID] = []
    var candidates: [ProjectCandidate] = []
    var missing: [String] = []
    var created = Date()
    /// 1.20 までの形（作ったときの制作ファイル1つ）。読み込んだら sources に移す
    var source: String?

    init(name: String) { self.name = name }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        sources = try container.decodeIfPresent([ProjectSource].self, forKey: .sources) ?? []
        approved = try container.decodeIfPresent(Set<String>.self, forKey: .approved) ?? []
        files = try container.decodeIfPresent([UUID].self, forKey: .files) ?? []
        matched = try container.decodeIfPresent([UUID].self, forKey: .matched) ?? files
        candidates = try container.decodeIfPresent([ProjectCandidate].self, forKey: .candidates) ?? []
        missing = try container.decodeIfPresent([String].self, forKey: .missing) ?? []
        created = try container.decodeIfPresent(Date.self, forKey: .created) ?? Date()
        source = try container.decodeIfPresent(String.self, forKey: .source)
    }

    var pendingCount: Int { candidates.filter { !approved.contains($0.name) }.count }

    mutating func refreshFiles() {
        var seen = Set<UUID>()
        files = (matched + candidates.filter { approved.contains($0.name) }.map(\.file)).filter { seen.insert($0).inserted }
    }
}

/// 保存する中身：ライブラリ・セット・プロジェクト・アクティブにしたファイル・お気に入りのファミリー
struct LibraryData: Codable, Sendable {
    var files: [FontFile] = []
    var sets: [FontSet] = []
    var projects: [FontProject] = []
    var smartSets: [SmartSet] = []
    var active: Set<UUID> = []
    /// フォントフォルダーから一時的に消えたファイルの場所と id（Creative Cloud で Adobe Fonts をオフにした、ファイルを入れ替えたなど）。
    /// 戻ってきたら同じ id で入れ直し、セット・プロジェクトに入ったままにする
    var departed: [String: UUID] = [:]
    /// ファミリー名。ファイルを入れ替えても残るよう、ファイルではなく名前で覚える
    var favorites: Set<String> = []
    /// 重複の優先の規則（「重複フォントを解決」で選んだもの）。ウォッチフォルダーの順位が同じときだけ使う
    var folderRules: [FolderRule] = []
    /// 同じフォルダーの中の重複など、規則にできない組でファイルごとに選んだ優先
    var preferredFiles: Set<UUID> = []

    init() {}

    // 古い版のファイル（favorites なし）も読めるよう、無い項目は空にする
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        files = try container.decodeIfPresent([FontFile].self, forKey: .files) ?? []
        sets = try container.decodeIfPresent([FontSet].self, forKey: .sets) ?? []
        projects = try container.decodeIfPresent([FontProject].self, forKey: .projects) ?? []
        departed = try container.decodeIfPresent([String: UUID].self, forKey: .departed) ?? [:]
        smartSets = try container.decodeIfPresent([SmartSet].self, forKey: .smartSets) ?? []
        active = try container.decodeIfPresent(Set<UUID>.self, forKey: .active) ?? []
        favorites = try container.decodeIfPresent(Set<String>.self, forKey: .favorites) ?? []
        folderRules = try container.decodeIfPresent([FolderRule].self, forKey: .folderRules) ?? []
        preferredFiles = try container.decodeIfPresent(Set<UUID>.self, forKey: .preferredFiles) ?? []
    }
}

/// 重複の優先の規則：preferred フォルダー（下の階層も）のファイルを、other フォルダーのファイルより優先する
struct FolderRule: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var preferred: String
    var other: String

    func prefers(_ winner: String, over loser: String) -> Bool {
        winner.hasPrefix(preferred + "/") && loser.hasPrefix(other + "/")
    }
}

/// ファミリー単位の表示。一覧の1行
struct FontFamily: Identifiable, Hashable, Sendable {
    var name: String
    var files: [FontFile]
    var id: String { name }
    var faceCount: Int { files.reduce(0) { $0 + $1.faces.count } }
    /// 日本語などの表示名（無ければ英語のファミリー名）
    var displayName: String { files.first?.faces.first?.displayFamily ?? name }
}

enum FontState: Hashable, Sendable {
    case active
    case inactive
    /// 同じPostScript名の別のファイルが使われている（システムやほかのアプリが入れたもの）
    case conflict(String)
    case missing
}

enum FontScanner {
    static let extensions: Set<String> = ["otf", "ttf", "ttc", "otc", "dfont", "woff", "woff2"]

    /// ファイルとフォルダーの中（下の階層も）からフォントファイルを拾う。隠しファイルとパッケージの中は見ない
    static func fontURLs(in urls: [URL], includeHidden: Bool = false) -> [URL] {
        var found: [URL] = []
        for url in urls {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { continue }
            if !isDirectory.boolValue {
                if extensions.contains(url.pathExtension.lowercased()) { found.append(url) }
                continue
            }
            let items = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey],
                                                       options: includeHidden ? [.skipsPackageDescendants] : [.skipsHiddenFiles, .skipsPackageDescendants])
            while let item = items?.nextObject() as? URL {
                if extensions.contains(item.pathExtension.lowercased()) { found.append(item) }
            }
        }
        return found
    }

    /// 書体を読み取る。フォントとして読めなければ nil
    static func read(_ url: URL) -> FontFile? {
        let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor] ?? []
        let faces = descriptors.compactMap { descriptor -> FontFace? in
            guard let name = CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String else { return nil }
            let family = CTFontDescriptorCopyAttribute(descriptor, kCTFontFamilyNameAttribute) as? String ?? name
            let style = CTFontDescriptorCopyAttribute(descriptor, kCTFontStyleNameAttribute) as? String ?? ""
            let full = CTFontDescriptorCopyAttribute(descriptor, kCTFontDisplayNameAttribute) as? String ?? name
            var face = FontFace(postScriptName: name, family: FontNaming.decodeEscaped(family), style: FontNaming.decodeEscaped(style),
                                fullName: FontNaming.decodeEscaped(full))
            (face.localizedFamily, face.localizedStyle) = localizedNames(descriptor)
            return face
        }
        guard !faces.isEmpty else { return nil }
        var file = FontFile(path: url.standardizedFileURL.path, faces: faces)
        file.vendor = vendorID(descriptors[0])
        file.trademarkOwner = trademarkOwner(descriptors[0], family: faces[0].family)
        let tables = tableTags(descriptors[0])
        file.isVariable = tables.contains("fvar")
        file.isColor = !tables.isDisjoint(with: ["COLR", "sbix", "CBDT", "SVG "])
        let characters = characterStats(descriptors[0])
        file.characterCount = characters.count
        file.glyphCount = characters.glyphs
        file.isKana = characters.kana
        file.supportsJapanese = characters.japanese
        file.isIcon = characters.icon || iconFamilyWords.contains { faces[0].family.contains($0) }
        file.fontRevision = fontRevision(descriptors[0])
        return file
    }

    /// ファイルの中身の SHA-256（16進）。読めなければ nil
    static func contentHash(_ url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try? handle.read(upToCount: 1 << 20), !chunk.isEmpty { hasher.update(data: chunk) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// head テーブルの fontRevision（16.16 の固定小数点）。読めなければ 0
    static func fontRevision(_ descriptor: CTFontDescriptor) -> Double {
        let font = CTFontCreateWithFontDescriptor(descriptor, 12, nil)
        guard let table = CTFontCopyTable(font, CTFontTableTag(kCTFontTableHead), []) as Data?, table.count >= 8 else { return 0 }
        let raw = table[table.startIndex + 4..<table.startIndex + 8].reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
        return Double(Int32(bitPattern: raw)) / 65536
    }

    /// アプリの表示言語（日本語環境なら日本語）のファミリー名・スタイル名。英語名と同じなら空
    static func localizedNames(_ descriptor: CTFontDescriptor) -> (String, String) {
        let family = CTFontDescriptorCopyLocalizedAttribute(descriptor, kCTFontFamilyNameAttribute, nil) as? String ?? ""
        let style = CTFontDescriptorCopyLocalizedAttribute(descriptor, kCTFontStyleNameAttribute, nil) as? String ?? ""
        let english = CTFontDescriptorCopyAttribute(descriptor, kCTFontFamilyNameAttribute) as? String ?? ""
        let englishStyle = CTFontDescriptorCopyAttribute(descriptor, kCTFontStyleNameAttribute) as? String ?? ""
        return (family == english ? "" : family, style == englishStyle ? "" : style)
    }

    /// OS/2 テーブルの achVendID（4文字）。前後の空白は落とす
    static func vendorID(_ descriptor: CTFontDescriptor) -> String {
        let font = CTFontCreateWithFontDescriptor(descriptor, 12, nil)
        guard let table = CTFontCopyTable(font, CTFontTableTag(kCTFontTableOS2), []) as Data?, table.count >= 62 else { return "" }
        return String(decoding: table[58..<62], as: UTF8.self).trimmingCharacters(in: .whitespaces.union(.controlCharacters))
    }

    /// 商標の持ち主。「X is a trademark of Morisawa and Company Limited.」「… trademarks of Adobe Systems Incorporated in the United States」
    /// のように書かれるので、「trademark(s) of」のあとを「.」「,」「;」「 in 」「 and/or」「 and may」の前まで取る
    static func trademarkOwner(_ descriptor: CTFontDescriptor, family: String) -> String {
        let font = CTFontCreateWithFontDescriptor(descriptor, 12, nil)
        let text = [kCTFontTrademarkNameKey, kCTFontCopyrightNameKey]
            .compactMap { CTFontCopyName(font, $0) as String? }.joined(separator: " ")
        if let range = text.range(of: #"trademarks? of "#, options: [.regularExpression, .caseInsensitive]) {
            var owner = String(text[range.upperBound...])
            for stop in [".", ",", ";", " in ", " and/or", " and may", "\n"] {
                if let end = owner.range(of: stop) { owner = String(owner[..<end.lowerBound]) }
            }
            owner = owner.trimmingCharacters(in: .whitespaces)
            if !owner.isEmpty { return owner }
        }
        return family.hasPrefix("ITC ") ? "ITC" : ""
    }

    /// 名前でアイコンフォントとみなす語。Font Awesome 6・7 は欧文の拡張文字も持ち、文字の構成では筆記体の書体と分けられない。
    /// 大文字・小文字を区別する（区別しないと「SemiCondensed」の icon、「Higemoji」の emoji に当たる）
    static let iconFamilyWords = ["Awesome", "Icon", "Dingbat", "Ornament", "Symbols", "Emoji", "Glyphicons", "Material Symbols"]

    /// 入っているテーブルの名前（4文字）。CTFontCopyAvailableTables の中身は CFNumber ではなくタグそのものなので、[Int] には読み替えられない
    static func tableTags(_ descriptor: CTFontDescriptor) -> Set<String> {
        let font = CTFontCreateWithFontDescriptor(descriptor, 12, nil)
        guard let array = CTFontCopyAvailableTables(font, []) else { return [] }
        var tags = Set<String>()
        for index in 0..<CFArrayGetCount(array) {
            let tag = UInt32(truncatingIfNeeded: UInt(bitPattern: CFArrayGetValueAtIndex(array, index)))
            tags.insert(String(decoding: [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: tag >> $0) }, as: UTF8.self))
        }
        return tags
    }

    /// 収録文字数・グリフ数・かなフォントかどうか。文字の数は CFCharacterSet のビットマップで数える
    /// （先頭の8,192バイトが基本面、そのあとは面ごとに面番号1バイト＋8,192バイト）
    static func characterStats(_ descriptor: CTFontDescriptor) -> (count: Int, glyphs: Int, kana: Bool, japanese: Bool, icon: Bool) {
        let font = CTFontCreateWithFontDescriptor(descriptor, 12, nil)
        let set = CTFontCopyCharacterSet(font)
        guard let bitmap = CFCharacterSetCreateBitmapRepresentation(nil, set) as Data? else { return (0, CTFontGetGlyphCount(font), false, false, false) }
        var count = 0
        var ideographs = 0
        var privateUse = 0
        var latinExtended = 0
        bitmap.withUnsafeBytes { bytes in
            for index in 0..<min(8192, bytes.count) {
                let bits = bytes[index].nonzeroBitCount
                count += bits
                // CJK統合漢字（U+4E00〜U+9FFF）
                if index >= 0x4E00 / 8 && index < 0xA000 / 8 { ideographs += bits }
                // 私用領域（U+E000〜U+F8FF）
                if index >= 0xE000 / 8 && index < 0xF900 / 8 { privateUse += bits }
                // ラテン文字拡張A（U+0100〜U+017F：Ā・Ł など）
                if index >= 0x100 / 8 && index < 0x180 / 8 { latinExtended += bits }
            }
            var offset = 8192
            while offset + 8193 <= bytes.count {
                let plane = bytes[offset]
                for index in (offset + 1)..<(offset + 8193) {
                    let bits = bytes[index].nonzeroBitCount
                    count += bits
                    if plane >= 15 { privateUse += bits }
                }
                offset += 8193
            }
        }
        let symbolic = (CTFontGetSymbolicTraits(font).rawValue & CTFontSymbolicTraits.traitClassMask.rawValue)
            == CTFontStylisticClass.classSymbolic.rawValue
        // SF Pro や筆記体の書体も私用領域に字形を多く持つので、欧文の拡張文字（ラテン文字拡張A）を持つものは外す。
        // Font Awesome は英字や記号（★ など）にもアイコンを割り当てるので、英字の有無やほかの文字の数では分けられない
        let icon = symbolic || (count > 0 && privateUse * 2 >= count && latinExtended < 20)
        // かな（あ・ア）を持ち、漢字が「々」などのわずかしか無い
        let japanese = CFCharacterSetIsLongCharacterMember(set, 0x3042) && CFCharacterSetIsLongCharacterMember(set, 0x30A2)
        return (count, CTFontGetGlyphCount(font), japanese && ideographs < 50, japanese, icon)
    }

    static func vendorID(of url: URL) -> String {
        guard let descriptor = (CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor])?.first else { return "" }
        return vendorID(descriptor)
    }
}

enum FontActivation {
    /// 先頭の書体のPostScript名で今使われるファイルを引き、このファイルかどうかで判定する。
    /// 登録済みの一覧を返す関数は macOS に無いので、ほかのアプリが入れたフォントも同じ方法で見分ける
    static func state(of file: FontFile) -> FontState {
        guard FileManager.default.fileExists(atPath: file.path) else { return .missing }
        guard let name = file.faces.first?.postScriptName else { return .inactive }
        let font = CTFontCreateWithName(name as CFString, 12, nil)
        guard CTFontCopyPostScriptName(font) as String == name else { return .inactive }
        guard let url = CTFontCopyAttribute(font, kCTFontURLAttribute) as? URL else { return .inactive }
        return samePath(url.path, file.path) ? .active : .conflict(url.path)
    }

    /// ライブラリのフォントはログイン中だけ有効（.session）。アプリを終了しても次にログアウトするまでほかのアプリで使える。
    /// フォントフォルダーに入っているフォントは .persistent（ファイルは動かさず、ユーザーの設定として残る）
    static func activate(_ file: FontFile, scope: CTFontManagerScope = .session) -> String? {
        var error: Unmanaged<CFError>?
        if CTFontManagerRegisterFontsForURL(file.url as CFURL, scope, &error) { return nil }
        let code = error.map { CFErrorGetCode($0.takeRetainedValue()) } ?? 0
        // 登録済みならそのままでよい
        if code == CTFontManagerError.alreadyRegistered.rawValue { return nil }
        return reason(code)
    }

    static func deactivate(_ file: FontFile, scope: CTFontManagerScope = .session) -> String? {
        var error: Unmanaged<CFError>?
        if CTFontManagerUnregisterFontsForURL(file.url as CFURL, scope, &error) { return nil }
        let code = error.map { CFErrorGetCode($0.takeRetainedValue()) } ?? 0
        if code == CTFontManagerError.notRegistered.rawValue { return nil }
        return reason(code)
    }

    /// 衝突しているほかのファイル（ライブラリの外の古い置き場所など）の登録を外す。
    /// どの範囲で登録されたか分からないので、ログイン中（.session）・ユーザー（.persistent）の順に試す。
    /// どちらでも外れなければ理由を返す（フォントフォルダーに置かれたファイルは、ファイルを動かさないと外れない）
    static func unregister(path: String) -> String? {
        let url = URL(fileURLWithPath: path) as CFURL
        var lastCode: CFIndex = 0
        for scope in [CTFontManagerScope.session, .persistent] {
            var error: Unmanaged<CFError>?
            if CTFontManagerUnregisterFontsForURL(url, scope, &error) { return nil }
            lastCode = error.map { CFErrorGetCode($0.takeRetainedValue()) } ?? 0
        }
        if lastCode == CTFontManagerError.notRegistered.rawValue {
            return L("このアプリからは外せない登録です（フォントフォルダーに置かれているか、ほかのアプリが管理しています）")
        }
        return reason(lastCode)
    }

    private static func reason(_ code: CFIndex) -> String {
        switch code {
        case CTFontManagerError.fileNotFound.rawValue: return L("ファイルが見つかりません")
        case CTFontManagerError.insufficientPermissions.rawValue: return L("ファイルを読む権限がありません")
        case CTFontManagerError.invalidFontData.rawValue, CTFontManagerError.unrecognizedFormat.rawValue: return L("フォントとして読めません")
        case CTFontManagerError.duplicatedName.rawValue: return L("同じ名前のフォントがすでに使われています")
        case CTFontManagerError.systemRequired.rawValue: return L("システムに必要なフォントです")
        case CTFontManagerError.inUse.rawValue: return L("使用中のため解除できません")
        default: return L("エラー %d", Int(code))
        }
    }

    static func samePath(_ a: String, _ b: String) -> Bool {
        URL(fileURLWithPath: a).resolvingSymlinksInPath().path == URL(fileURLWithPath: b).resolvingSymlinksInPath().path
    }
}

extension LibraryData {
    /// ファミリーごとにまとめ、名前順に並べる
    func families(of files: [FontFile]) -> [FontFamily] {
        Dictionary(grouping: files, by: \.family)
            .map { FontFamily(name: $0.key, files: $0.value.sorted { $0.fileName.localizedStandardCompare($1.fileName) == .orderedAscending }) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// 同じPostScript名を持つファイルが2つ以上あるもの
    var duplicateFileIDs: Set<UUID> {
        var owners: [String: [UUID]] = [:]
        for file in files {
            for face in file.faces { owners[face.postScriptName, default: []].append(file.id) }
        }
        return Set(owners.values.filter { Set($0).count > 1 }.flatMap { $0 })
    }

    /// 新しいファイルだけを足す（同じパスは足さない）。足した数を返す
    mutating func add(_ newFiles: [FontFile]) -> Int {
        var known = Set(files.map(\.path))
        var added = 0
        for var file in newFiles where !known.contains(file.path) {
            if let id = departed.removeValue(forKey: file.path) { file.id = id }
            files.append(file)
            known.insert(file.path)
            added += 1
        }
        return added
    }

    mutating func remove(_ ids: Set<UUID>) {
        files.removeAll { ids.contains($0.id) }
        active.subtract(ids)
        for index in sets.indices { sets[index].files.removeAll { ids.contains($0) } }
        for index in projects.indices {
            projects[index].files.removeAll { ids.contains($0) }
            projects[index].matched.removeAll { ids.contains($0) }
            projects[index].candidates.removeAll { ids.contains($0.file) }
        }
    }
}

/// 一覧の1行：ファミリーか、その中の書体（ファイル）。ファイルが2つ以上のファミリーだけ開ける
struct FamilyNode: Identifiable, Hashable, Sendable {
    let id: String
    let family: FontFamily
    var file: FontFile?
    var children: [FamilyNode]?

    /// 書体の行の id。ファミリーの行（ファミリー名）と重ならないよう接頭辞を付ける
    static func fileID(_ file: FontFile) -> String { "file:" + file.id.uuidString }

    static func nodes(_ families: [FontFamily]) -> [FamilyNode] {
        families.map { family in
            FamilyNode(id: family.id, family: family, file: nil,
                       children: family.files.count > 1
                           ? family.files.map { FamilyNode(id: fileID($0), family: family, file: $0, children: nil) }
                           : nil)
        }
    }
}

/// Macごとに異なる場所を、共有ライブラリでは目印に置き換える。
/// Dropbox の中は「$DROPBOX-<アカウント>/…」、ホームの中は「~/…」
enum PortablePath {
    static let home = NSHomeDirectory()
    /// ~/.dropbox/info.json の personal・business それぞれの場所
    static let dropboxRoots: [String: String] = {
        let url = URL(fileURLWithPath: home).appendingPathComponent(".dropbox/info.json")
        guard let bytes = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any] else { return [:] }
        var roots: [String: String] = [:]
        for (account, value) in json {
            if let path = (value as? [String: Any])?["path"] as? String { roots[account] = path }
        }
        return roots
    }()

    static func encode(_ path: String, roots: [String: String] = dropboxRoots, home: String = home) -> String {
        // 長い場所から当てる（Dropbox はホームの中にあるため）
        for (account, root) in roots.sorted(by: { $0.value.count > $1.value.count })
        where path.hasPrefix(root + "/") {
            return "$DROPBOX-\(account)" + path.dropFirst(root.count)
        }
        if path.hasPrefix(home + "/") { return "~" + path.dropFirst(home.count) }
        return path
    }

    static func decode(_ path: String, roots: [String: String] = dropboxRoots, home: String = home) -> String {
        if path.hasPrefix("$DROPBOX-"), let slash = path.firstIndex(of: "/") {
            let account = String(path[path.index(path.startIndex, offsetBy: 9)..<slash])
            if let root = roots[account] { return root + path[slash...] }
        }
        if path.hasPrefix("~/") { return home + path.dropFirst(1) }
        return path
    }
}

extension LibraryData {
    func mapPaths(_ transform: (String) -> String) -> LibraryData {
        var copy = self
        for index in copy.files.indices { copy.files[index].path = transform(copy.files[index].path) }
        for index in copy.projects.indices {
            copy.projects[index].source = copy.projects[index].source.map(transform)
            for source in copy.projects[index].sources.indices {
                copy.projects[index].sources[source].path = copy.projects[index].sources[source].path.map(transform)
            }
        }
        for index in copy.folderRules.indices {
            copy.folderRules[index].preferred = transform(copy.folderRules[index].preferred)
            copy.folderRules[index].other = transform(copy.folderRules[index].other)
        }
        return copy
    }

    /// ほかのライブラリを合わせる。同じ場所のファイルは1つにまとめ、セットは名前で合わせ、アクティブは両方を残す。
    /// 足したファイルの数を返す
    /// 1.20 までのプロジェクト（参照するファイル・フォルダーが無い）を移す。作ったときの制作ファイルがあればそれを、
    /// 貼り付けで作ったものは入っているフォントの PostScript名と見つからなかった名前を「フォント名」として元にする
    /// 1.28 までに読んだ、制作ツールの書式がそのまま入った名前を文字に戻す（FontNaming.decodeEscaped）
    mutating func decodeEscapedNames() {
        for index in files.indices {
            for face in files[index].faces.indices {
                let current = files[index].faces[face]
                files[index].faces[face].family = FontNaming.decodeEscaped(current.family)
                files[index].faces[face].style = FontNaming.decodeEscaped(current.style)
                files[index].faces[face].fullName = FontNaming.decodeEscaped(current.fullName)
            }
        }
    }

    mutating func migrateProjects() {
        for index in projects.indices where projects[index].sources.isEmpty {
            if let source = projects[index].source {
                projects[index].sources = [ProjectSource(kind: .file, path: source)]
            } else {
                let ids = Set(projects[index].files)
                let names = files.filter { ids.contains($0.id) }.compactMap { $0.faces.first?.postScriptName } + projects[index].missing
                if !names.isEmpty { projects[index].sources = [ProjectSource(kind: .names, names: names)] }
            }
            projects[index].source = nil
        }
    }

    mutating func merge(_ other: LibraryData) -> Int {
        var idMap: [UUID: UUID] = [:]
        var byPath: [String: UUID] = [:]
        for file in files where byPath[file.path] == nil { byPath[file.path] = file.id }
        var added = 0
        for file in other.files {
            if let id = byPath[file.path] {
                idMap[file.id] = id
            } else {
                files.append(file)
                byPath[file.path] = file.id
                idMap[file.id] = file.id
                added += 1
            }
        }
        for set in other.sets {
            let members = set.files.compactMap { idMap[$0] }
            if let index = sets.firstIndex(where: { $0.name == set.name }) {
                let known = Set(sets[index].files)
                sets[index].files += members.filter { !known.contains($0) }
            } else {
                // ほかのMacで名前を変えたセットは、同じ id のまま別の名前で届く。id がぶつからないよう新しくする
                let id = sets.contains(where: { $0.id == set.id }) ? UUID() : set.id
                sets.append(FontSet(id: id, name: set.name, files: members))
            }
        }
        for project in other.projects {
            if let index = projects.firstIndex(where: { $0.id == project.id }) {
                let known = Set(projects[index].files)
                projects[index].files += project.files.compactMap { idMap[$0] }.filter { !known.contains($0) }
                projects[index].approved.formUnion(project.approved)
            } else {
                // 一致・候補のファイルも、合わせた後の id に読み替える（読み替えないと編集の画面で空になり、承認で消える）
                var copy = project
                copy.files = project.files.compactMap { idMap[$0] }
                copy.matched = project.matched.compactMap { idMap[$0] }
                copy.candidates = project.candidates.compactMap { candidate in
                    idMap[candidate.file].map { ProjectCandidate(name: candidate.name, file: $0) }
                }
                projects.append(copy)
            }
        }
        // スマートセットは条件だけなので id で合わせる（ファイルの id は持たない）
        for smartSet in other.smartSets where !smartSets.contains(where: { $0.id == smartSet.id }) { smartSets.append(smartSet) }
        active.formUnion(other.active.compactMap { idMap[$0] })
        favorites.formUnion(other.favorites)
        // 規則は場所の組で合わせる。こちらに逆向きの規則があれば、こちらを残す
        for rule in other.folderRules where !folderRules.contains(where: {
            ($0.preferred == rule.preferred && $0.other == rule.other) || ($0.preferred == rule.other && $0.other == rule.preferred)
        }) { folderRules.append(rule) }
        preferredFiles.formUnion(other.preferredFiles.compactMap { idMap[$0] })
        return added
    }
}

/// macOS のフォントフォルダー。ライブラリとは別に、起動時とフォントの変更時に読み込む
enum SystemFolder: String, CaseIterable, Hashable, Sendable {
    /// ~/Library/Fonts（このユーザーだけ）
    case user
    /// /Library/Fonts（このMacのすべてのユーザー）
    case allUsers
    /// /System/Library/Fonts（macOS のフォント。切り替えない）
    case system
    /// Adobe Fonts（Creative Cloud が入れたフォント。隠しフォルダーに「.12345.otf」の名前で置かれる。切り替えは Creative Cloud で）
    case adobeFonts

    var path: String {
        switch self {
        case .user: return NSHomeDirectory() + "/Library/Fonts"
        case .allUsers: return "/Library/Fonts"
        case .system: return "/System/Library/Fonts"
        case .adobeFonts: return NSHomeDirectory() + "/Library/Application Support/Adobe/CoreSync/plugins/livetype/.r"
        }
    }

    /// サイドバーの名前。Font Book と同じく、ユーザーはユーザー名で出す
    var title: String {
        switch self {
        case .user: return NSUserName()
        case .allUsers: return "All Users"
        case .system: return "System"
        case .adobeFonts: return "Adobe Fonts"
        }
    }

    /// username・All Users は .persistent の登録・解除で切り替える（ファイルは動かさない）。
    /// System は macOS、Adobe Fonts は Creative Cloud が管理するので切り替えない
    var isEditable: Bool { self == .user || self == .allUsers }

    /// 隠しファイルも読むフォルダー（Adobe Fonts のファイル名は . で始まる）
    var includesHiddenFiles: Bool { self == .adobeFonts }

    static func of(_ path: String) -> SystemFolder? {
        prefixes.first { path.hasPrefix($0.prefix) }?.folder
    }
    /// 各フォルダーの「パス/」。ホームフォルダーを毎回引くと数万件の判定で重いので、1回だけ作る
    private static let prefixes = allCases.map { (folder: $0, prefix: $0.path + "/") }
}

/// 一覧のフォント名の出し方
enum NameDisplay: String, CaseIterable, Sendable {
    /// 日本語名（ローカライズ名。無ければ英語名）
    case localized
    /// PostScript名（ファミリーの行は英語のファミリー名）
    case postScript
    /// 日本語名と PostScript名
    case both

    static let key = "nameDisplay"
    static var current: NameDisplay {
        UserDefaults.standard.string(forKey: key).flatMap(NameDisplay.init(rawValue:)) ?? .localized
    }
}

/// ファミリー名から読む分類（絞り込み用）
enum FontNaming {
    /// フォント制作ツールの書式がそのまま名前に入っているもの（「3,1,0x411,\\304B\\3089\\304B\\305C」＝からかぜ）を文字に戻す。
    /// 「プラットフォーム,エンコーディング,言語,」の前置きを外し、「\\XXXX」（16進4桁）を文字にする。当てはまらなければそのまま
    nonisolated static func decodeEscaped(_ name: String) -> String {
        guard name.range(of: #"\d+,\d+,0x[0-9A-Fa-f]+,"#, options: .regularExpression) != nil else { return name }
        var text = name.replacingOccurrences(of: #"\d+,\d+,0x[0-9A-Fa-f]+,"#, with: "", options: .regularExpression)
        while let range = text.range(of: #"\\[0-9A-Fa-f]{4}"#, options: .regularExpression) {
            let hex = text[range].dropFirst()
            guard let value = UInt32(hex, radix: 16), let scalar = Unicode.Scalar(value) else { break }
            text.replaceSubrange(range, with: String(Character(scalar)))
        }
        return text
    }

    /// Adobe-Japan1 の文字セットの名前（Std・Pro・Pr6N など）。ファミリー名の単語として入っているものだけ
    static let charsets = ["Std", "StdN", "Pro", "ProN", "Pr5", "Pr5N", "Pr6", "Pr6N", "Plus", "PlusN"]

    static func charset(_ family: String) -> String? {
        let words = family.split(whereSeparator: { $0 == " " || $0 == "-" }).map(String.init)
        return words.last { charsets.contains($0) }
    }
}
