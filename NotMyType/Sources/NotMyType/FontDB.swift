import Foundation
import SQLite3

/// FontDB（~/Git/macos-apps/FontDB/data/fonts.sqlite、モリサワ・フォントワークス・アドビ・フロップデザイン・Google Fonts の公式情報）で補うメタデータ。
/// build.sh がアプリの Resources に FontDB.sqlite として写し、起動時に読み取りだけで全件を読む（約12,000件、PostScript名で引く）。
/// 2026-10-24 の調べで、ライブラリ36,701件のうち12,221件が PostScript名で対応した
struct FontDBRecord: Sendable {
    var name: String
    var reading: String
    var maker: String
    var series: String
    var classification: String
    var languages: [String]
    var plans: [String]
    var releaseDate: String
    var originalRelease: String
    var designer: String
    var description: String
    var url: String
    /// files の値（公式のファイル名・メニュー名・バージョン）
    var fileName: String
    var menuName: String
    var version: String

    /// リリース年（発売日の先頭4桁。初出があればそちらを優先）
    var releaseYear: Int? {
        for text in [originalRelease, releaseDate] where text.count >= 4 {
            if let year = Int(text.prefix(4)) { return year }
        }
        return nil
    }

    /// 検索で引く文字（よみ・メーカー・デザイナー・分類・シリーズ・説明・公式の名前）
    /// 検索に使う文字。説明文はフォントベンダーの著作物なので使わない（表示もしない、ユーザー指定）
    var searchText: String { [name, reading, maker, designer, classification, series, menuName].joined(separator: " ") }
}

enum FontDB {
    /// PostScript名 → 公式の情報
    nonisolated(unsafe) private static var records: [String: FontDBRecord] = [:]
    nonisolated(unsafe) private static var loaded = false
    private static let lock = NSLock()

    static func record(_ postScriptName: String) -> FontDBRecord? {
        lock.withLock {
            if !loaded { load(); loaded = true }
            return records[postScriptName]
        }
    }

    /// ファイルの書体のうち、最初に見つかったものの情報
    static func record(for file: FontFile) -> FontDBRecord? {
        for face in file.faces { if let found = record(face.postScriptName) { return found } }
        return nil
    }

    /// 分類の一覧（検索オプション用）
    static var classifications: [String] {
        lock.withLock {
            if !loaded { load(); loaded = true }
            return Array(Set(records.values.map(\.classification).filter { !$0.isEmpty })).sorted()
        }
    }

    private static func load() {
        guard let url = Bundle.main.url(forResource: "FontDB", withExtension: "sqlite") else { return }
        var database: OpaquePointer?
        guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let database else {
            sqlite3_close(database)
            return
        }
        defer { sqlite3_close(database) }
        let sql = """
            SELECT fi.postscript_name, f.name, f.reading, f.maker, f.series, f.classification, f.languages, f.plans,
                   f.release_date, f.original_release, f.designer, f.description, f.url,
                   fi.file_name, fi.menu_name_ja, fi.version, fi.plans
            FROM files fi JOIN fonts f ON f.uid = fi.font_uid
            """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else { return }
        defer { sqlite3_finalize(statement) }
        func text(_ column: Int32) -> String { sqlite3_column_text(statement, column).map { String(cString: $0) } ?? "" }
        func list(_ column: Int32) -> [String] {
            guard let data = text(column).data(using: .utf8), let array = try? JSONSerialization.jsonObject(with: data) as? [String] else { return [] }
            return array
        }
        while sqlite3_step(statement) == SQLITE_ROW {
            let postScriptName = text(0)
            guard !postScriptName.isEmpty, records[postScriptName] == nil else { continue }
            // プランはファイルの方が細かいので、あればそちらを使う
            let filePlans = list(16)
            records[postScriptName] = FontDBRecord(
                name: text(1), reading: text(2), maker: text(3), series: text(4), classification: text(5),
                languages: list(6), plans: filePlans.isEmpty ? list(7) : filePlans,
                releaseDate: text(8), originalRelease: text(9), designer: text(10), description: text(11), url: text(12),
                fileName: text(13), menuName: text(14), version: text(15))
        }
    }
}

/// 検索オプションの「リリース年」（年代ごと）
enum ReleaseDecade: Int, CaseIterable, Hashable, Sendable {
    case before1990 = 0, nineties = 1990, twoThousands = 2000, twentyTens = 2010, twentyTwenties = 2020

    init(year: Int) {
        switch year {
        case ..<1990: self = .before1990
        case 1990..<2000: self = .nineties
        case 2000..<2010: self = .twoThousands
        case 2010..<2020: self = .twentyTens
        default: self = .twentyTwenties
        }
    }

    var title: String { self == .before1990 ? L("1989年以前") : L("%@年代", String(rawValue)) }
}
