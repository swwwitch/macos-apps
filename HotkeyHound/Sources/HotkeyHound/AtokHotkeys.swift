import Foundation

/// ATOK のキーカスタマイズ（使用中のスタイルの「キー」）。
/// 使用中のスタイルは ~/Library/Preferences/ATOK<版>/ATOK<版>Customizer.plist の「スタイル名」。
/// ユーザーのスタイルは同じフォルダの Styles、既定のスタイルは /Library/Application Support/JustSystems/ATOK<版>/Data/Styles にある
enum AtokHotkeys {
    static func scan() -> [HotkeyEntry] {
        guard let (version, folder) = latestFolder(),
              let customizer = plist(folder.appendingPathComponent("ATOK\(version)Customizer.plist")) else { return [] }
        let styleFile = customizer["スタイル名"] as? String ?? "atok_style.plist"
        let candidates = [folder.appendingPathComponent("Styles/\(styleFile)"),
                          URL(fileURLWithPath: "/Library/Application Support/JustSystems/ATOK\(version)/Data/Styles/\(styleFile)")]
        guard let style = candidates.lazy.compactMap(plist).first, let data = style["キー"] as? Data else { return [] }
        let styleName = userStyleName(styleFile, customizer) ?? builtInNames[styleFile] ?? (styleFile as NSString).deletingPathExtension
        let owner = "com.justsystems.inputmethod.atok\(version)"
        return parse(data).map { item in
            var entry = HotkeyEntry(source: .atok, combo: item.combo, title: item.title, group: L("スタイル「%@」", styleName),
                                    scope: L("ATOKがオンで%@のとき", item.states.map { L($0) }.joined(separator: "・")))
            entry.ownerBundleID = owner
            return entry
        }
    }

    /// ~/Library/Preferences/ATOK<版> のうち、いちばん新しい版
    private static func latestFolder() -> (Int, URL)? {
        let preferences = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Preferences")
        let names = (try? FileManager.default.contentsOfDirectory(atPath: preferences.path)) ?? []
        let versions = names.compactMap { name -> Int? in name.hasPrefix("ATOK") ? Int(name.dropFirst(4)) : nil }
        guard let version = versions.max() else { return nil }
        return (version, preferences.appendingPathComponent("ATOK\(version)"))
    }

    private static func plist(_ url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
    }

    /// 「スタイル一覧」は [{ファイル名: 表示名}] の配列
    private static func userStyleName(_ file: String, _ customizer: [String: Any]) -> String? {
        for item in customizer["スタイル一覧"] as? [[String: String]] ?? [] {
            if let name = item[file] { return name }
        }
        return nil
    }

    private static let builtInNames = ["atok_style.plist": "ATOK", "kotoeri_style.plist": "macOS標準風スタイル",
                                       "ms-ime_style.plist": "MS-IME", "egbridge_style.plist": "egbridge", "mac-vje-delta_style.plist": "Mac-VJE-Delta"]

    // MARK: 「キー」の形式（実測。ATOK Customizer の「キー設定のテキストファイル出力」と突き合わせた）
    // 先頭 72 バイトは状態ごとの [開始, 終了) のレコード番号（UInt16 ビッグエンディアン）。
    // 0〜11 語目が 文字未入力・入力中・変換中・次候補表示中・全候補表示中・文節区切り直し中、28〜29 語目が 半角入力。
    // レコードは 64 バイト目から 10 バイトずつで、キー 4 つ（未設定は 0xFFFF）＋機能番号。
    // キーは上位バイトが 0x01 特殊キー・0x04 shift・0x10 control・0x20 option、下位バイトが文字（control 付きは制御文字）か特殊キーの番号

    struct Item { let combo: KeyCombo; let title: String; var states: [String] }

    static let states = ["文字未入力", "入力中", "変換中", "次候補表示中", "全候補表示中", "文節区切り直し中", "半角入力"]

    static func parse(_ data: Data) -> [Item] {
        let bytes = [UInt8](data)
        func word(_ offset: Int) -> Int? {
            guard offset + 1 < bytes.count else { return nil }
            return Int(bytes[offset]) << 8 | Int(bytes[offset + 1])
        }
        let ranges = [0, 2, 4, 6, 8, 10, 28].map { (word($0 * 2) ?? 0, word($0 * 2 + 2) ?? 0) }
        var items: [Item] = []
        var index: [String: Int] = [:]
        for (state, range) in zip(states, ranges) where range.0 != 0xFFFF && range.0 < range.1 {
            for record in range.0..<range.1 {
                let base = 64 + record * 10
                guard let function = word(base + 8), let title = functionNames[function] else { continue }
                for slot in 0..<4 {
                    guard let key = word(base + slot * 2), key != 0xFFFF, let combo = combo(key) else { continue }
                    // 同じ機能・同じキーは状態をまとめて 1 件に
                    let id = "\(function):\(combo.keyCode):\(combo.modifiers.rawValue)"
                    if let existing = index[id] {
                        if !items[existing].states.contains(state) { items[existing].states.append(state) }
                    } else {
                        index[id] = items.count
                        items.append(Item(combo: combo, title: title, states: [state]))
                    }
                }
            }
        }
        return items
    }

    static func combo(_ key: Int) -> KeyCombo? {
        let flags = key >> 8, code = key & 0xFF
        var modifiers: KeyModifiers = []
        if flags & 0x04 != 0 { modifiers.insert(.shift) }
        if flags & 0x10 != 0 { modifiers.insert(.control) }
        if flags & 0x20 != 0 { modifiers.insert(.option) }
        if flags & 0x01 != 0 || code == 0x20 {
            guard let keyCode = specialKeys[code] else { return nil }
            return KeyCombo(keyCode: keyCode, modifiers: modifiers)
        }
        // control 付きの英字は制御文字（0x01〜0x1A）で入っている
        let scalar = flags & 0x10 != 0 && code < 0x20 ? code + 0x60 : code
        guard let character = Unicode.Scalar(scalar),
              let found = KeyNames.keyCode(forCharacter: String(Character(character)).lowercased(), caseImpliesShift: false) else { return nil }
        if found.shift { modifiers.insert(.shift) }
        return KeyCombo(keyCode: found.keyCode, modifiers: modifiers)
    }

    /// 特殊キーの番号 → 仮想キーコード
    static let specialKeys: [Int: Int] = [
        0x08: 51, 0x09: 48, 0x0D: 36, 0x1B: 53, 0x20: 49,
        0x21: 122, 0x22: 120, 0x23: 99, 0x24: 118, 0x25: 96, 0x26: 97, 0x27: 98, 0x28: 100, 0x29: 101, 0x2A: 109, 0x2B: 103, 0x2C: 111,
        0x47: 71, 0x50: 104, 0x52: 102, 0x61: 121, 0x62: 116, 0x64: 117,
        0x65: 126, 0x66: 123, 0x67: 124, 0x68: 125, 0x69: 115, 0x6A: 119, 0x6F: 76
    ]

    /// 機能番号 → 機能名（ATOK Customizer の機能表から取り出したもの）
    static let functionNames: [Int: String] = [
        0: "前文字削除", 1: "1文字削除", 2: "挿入ポイント後移動", 3: "挿入ポイント前移動", 4: "挿入ポイント末尾移動", 5: "挿入ポイント先頭移動", 7: "継続変換(自動変換時)", 8: "変換/次候補",
        9: "変換/前候補", 10: "1音確定", 11: "半角英字(後)変換", 12: "ひらがな(後)変換", 13: "カタカナ(後)変換", 14: "半角(後)変換", 15: "全角英字(後)変換", 17: "辞書セット1変換",
        18: "辞書セット2変換", 19: "辞書セット3変換", 20: "辞書セット4変換", 21: "辞書セット5変換", 22: "辞書セット6変換", 23: "辞書セット7変換", 24: "辞書セット8変換", 25: "辞書セット9変換",
        26: "辞書セット0変換", 27: "部分確定", 28: "全候補表示", 29: "全文確定", 30: "全文字削除", 31: "確定リピート", 32: "確定アンドゥ", 37: "固定入力順次切替", 38: "固定入力英字順次切替",
        39: "固定入力カナ順次切替", 41: "ひらがな固定入力(あ)ON/OFF", 42: "カタカナ固定入力(ア)ON/OFF", 43: "半角カタカナ固定入力(ｱ)ON/OFF", 44: "全角英数固定入力(Ａ)ON/OFF",
        45: "英字入力(A)ON/OFF", 46: "英語入力ON/OFF", 47: "読みの入力誤り位置へジャンプ", 48: "先頭1文字確定", 49: "末尾1文字確定", 50: "変換取消", 51: "全変換取消",
        52: "文節区切り伸張", 53: "文節区切り収縮", 54: "文節後移動", 55: "文節前移動", 56: "文節最終移動", 57: "文節先頭移動", 58: "単語削除", 59: "注目文節削除", 60: "自動表示候補確定",
        62: "次候補群表示", 63: "前候補群表示", 64: "全角/半角文字切替", 65: "単語登録", 67: "送り仮名モード順次切替", 68: "漢字入力モード切替", 69: "漢字変換モード順次切替", 70: "入力文字種順次切替",
        71: "入力文字種(Ａ/A)順次切替", 72: "入力文字種(あ/ア/ｱ)順次切替", 73: "ひらがな入力文字種(あ)", 74: "カタカナ入力文字種(ア)", 75: "半角カタカナ入力文字種(ｱ)", 76: "全角英数入力文字種(Ａ)",
        77: "半角英数入力文字種(A)", 78: "辞書･学習設定", 79: "話し言葉優先モード順次切替", 87: "漢字/半角モード切替", 91: "表現モード順次切替", 94: "情報ウインドウオープン/表示切替",
        95: "情報ウインドウクローズ", 107: "連想変換", 118: "次グループ移動", 119: "前グループ移動", 120: "順次後変換", 121: "順次無変換後変換", 122: "順次カタカナ後変換",
        123: "ローマ字単位区切り伸張", 124: "ローマ字単位区切り収縮", 125: "全角英字入力(Ａ)", 126: "半角英字入力(A)", 127: "読みの英字/カナ置換", 128: "読みの英字置換", 129: "読みのカナ置換",
        130: "入力文字種(あ/ア)順次切替", 131: "入力文字種(あ/ア/Ａ)順次切替", 132: "入力文字種(あ,ア/Ａ)順次切替", 133: "入力文字種(あ/Ａ)順次切替", 134: "入力文字種(ア/Ａ)順次切替",
        135: "固定入力ON/OFF", 136: "ひらがな固定入力(あ)", 137: "カタカナ固定入力(ア)", 138: "半角カタカナ固定入力(ｱ)", 139: "全角英数固定入力(Ａ)", 140: "英字入力(A)",
        141: "コード順並べ替え", 142: "先頭文字並べ替え", 143: "末尾文字並べ替え", 144: "学習機能の抑制", 145: "学習情報クリア", 148: "ATOKダイレクト プラグイン1で検索", 149: "ATOKダイレクト プラグイン2で検索",
        150: "ATOKダイレクト プラグイン3で検索", 151: "ATOKダイレクト プラグイン4で検索", 152: "ATOKダイレクト プラグイン5で検索", 156: "推測候補の自動表示(強)ON/OFF", 158: "推測変換",
        159: "再変換", 160: "漢字モード", 161: "半角モード", 168: "全候補次移動", 169: "先頭候補へ移動", 170: "全候補前移動", 171: "全候補次行移動", 172: "全候補前行移動",
        173: "全候補選択確定", 174: "全候補選択取消", 175: "最終候補へ移動", 176: "ヘルプ", 177: "ATOKアトカラ", 178: "キー・ローマ字カスタマイザ", 179: "辞書ユーティリティ",
        180: "文字パレット", 182: "顔文字パレット", 186: "ATOK MiRA", 190: "お気に入り文書メニュー", 192: "ATOKパレット表示", 193: "環境設定", 194: "ATOK Sync",
        195: "お気に入り文書リピート", 196: "お気に入り文書編集ツール", 198: "自動表示候補前移動", 199: "自動表示候補次移動", 206: "環境設定関連付けツール", 207: "電子辞典で検索",
        208: "スピーチで英文読み上げ", 213: "Spotlightで検索", 216: "無学習全文確定", 217: "自動表示候補クローズ", 218: "キーワードExpress", 220: "自動修復取消", 221: "校正支援 見逃し指摘ビューア",
        229: "日付入力パレット", 231: "情報ウインドウ 前ページ移動", 232: "情報ウインドウ 次ページ移動", 234: "電子辞典 部分一致検索", 237: "ATOKダイレクト すべてのプラグインで検索",
        238: "ATOKダイレクト プラグインを指定して検索"
    ]
}
