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

/// ライブラリに登録したフォントファイル。ファイルは動かさず、場所だけを覚える
struct FontFile: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var path: String
    var faces: [FontFace]
    var added = Date()
    /// OS/2 テーブルのベンダーID（MRSW＝モリサワ、FWKS＝フォントワークスなど）。無ければ空。古い版のライブラリでは nil
    var vendor: String?

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

/// 保存する中身：ライブラリ・セット・アクティブにしたファイル・お気に入りのファミリー
struct LibraryData: Codable, Sendable {
    var files: [FontFile] = []
    var sets: [FontSet] = []
    var active: Set<UUID> = []
    /// ファミリー名。ファイルを入れ替えても残るよう、ファイルではなく名前で覚える
    var favorites: Set<String> = []

    init() {}

    // 古い版のファイル（favorites なし）も読めるよう、無い項目は空にする
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        files = try container.decodeIfPresent([FontFile].self, forKey: .files) ?? []
        sets = try container.decodeIfPresent([FontSet].self, forKey: .sets) ?? []
        active = try container.decodeIfPresent(Set<UUID>.self, forKey: .active) ?? []
        favorites = try container.decodeIfPresent(Set<String>.self, forKey: .favorites) ?? []
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
    static func fontURLs(in urls: [URL]) -> [URL] {
        var found: [URL] = []
        for url in urls {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { continue }
            if !isDirectory.boolValue {
                if extensions.contains(url.pathExtension.lowercased()) { found.append(url) }
                continue
            }
            let items = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey],
                                                       options: [.skipsHiddenFiles, .skipsPackageDescendants])
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
            var face = FontFace(postScriptName: name, family: family, style: style, fullName: full)
            (face.localizedFamily, face.localizedStyle) = localizedNames(descriptor)
            return face
        }
        guard !faces.isEmpty else { return nil }
        var file = FontFile(path: url.standardizedFileURL.path, faces: faces)
        file.vendor = vendorID(descriptors[0])
        return file
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
        for file in newFiles where !known.contains(file.path) {
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
        return copy
    }

    /// ほかのライブラリを合わせる。同じ場所のファイルは1つにまとめ、セットは名前で合わせ、アクティブは両方を残す。
    /// 足したファイルの数を返す
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
                sets.append(FontSet(id: set.id, name: set.name, files: members))
            }
        }
        active.formUnion(other.active.compactMap { idMap[$0] })
        favorites.formUnion(other.favorites)
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

    var path: String {
        switch self {
        case .user: return NSHomeDirectory() + "/Library/Fonts"
        case .allUsers: return "/Library/Fonts"
        case .system: return "/System/Library/Fonts"
        }
    }

    /// サイドバーの名前。Font Book と同じく、ユーザーはユーザー名で出す
    var title: String {
        switch self {
        case .user: return NSUserName()
        case .allUsers: return "All Users"
        case .system: return "System"
        }
    }

    /// System 以外は .persistent の登録・解除で切り替える（ファイルは動かさない）
    var isEditable: Bool { self != .system }

    static func of(_ path: String) -> SystemFolder? {
        allCases.first { path.hasPrefix($0.path + "/") }
    }
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
    /// Adobe-Japan1 の文字セットの名前（Std・Pro・Pr6N など）。ファミリー名の単語として入っているものだけ
    static let charsets = ["Std", "StdN", "Pro", "ProN", "Pr5", "Pr5N", "Pr6", "Pr6N", "Plus", "PlusN"]

    static func charset(_ family: String) -> String? {
        let words = family.split(whereSeparator: { $0 == " " || $0 == "-" }).map(String.init)
        return words.last { charsets.contains($0) }
    }

    /// 名前の先頭：「A P-OTF」「M PLUS」のように1文字の語で始まるものは2語、「FOT-Rodin」のような接頭辞は「FOT-」、
    /// 「A-OTF」のように後ろが大文字だけのものは語のまま、それ以外は最初の語
    static func prefix(_ family: String) -> String {
        let words = family.split(separator: " ").map(String.init)
        guard let first = words.first else { return family }
        if first.count == 1, words.count > 1 { return first + " " + words[1] }
        if let hyphen = first.firstIndex(of: "-") {
            let rest = first[first.index(after: hyphen)...]
            if !rest.isEmpty, rest.allSatisfy({ $0.isUppercase || $0.isNumber }) { return first }
            return String(first[...hyphen])
        }
        return first
    }
}
