import AppKit
import SQLite3

/// 設定ファイル・システムの設定からホットキーを集める（メインスレッド以外で呼ぶ）
enum HotkeyScanners {
    static func scan(_ source: HotkeySource) -> [HotkeyEntry] {
        switch source {
        case .system: SystemHotkeys.scan()
        case .services: ServicesHotkeys.scan()
        case .userKeyEquivalents: UserKeyEquivalents.scan()
        case .menus: []
        case .keyboardMaestro: KeyboardMaestroHotkeys.scan()
        case .betterTouchTool: BetterTouchToolHotkeys.scan()
        case .karabiner: KarabinerHotkeys.scan()
        case .alfred: AlfredHotkeys.scan()
        case .keystrokePro: KeystrokeProHotkeys.scan()
        case .swApps: SwAppHotkeys.scan()
        case .keyboardShortcuts: KeyboardShortcutsHotkeys.scan()
        case .defaultFolderX: DefaultFolderXHotkeys.scan()
        case .atok: AtokHotkeys.scan()
        case .illustrator: IllustratorHotkeys.scan()
        default: CustomSources.scan(source)
        }
    }

    static func preference(_ key: String, _ domain: String) -> Any? {
        CFPreferencesCopyAppValue(key as CFString, domain as CFString)
    }

    static func appName(bundleID: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        }
        return bundleID
    }

    static var allApps: String { L("すべてのアプリ") }
}

// MARK: - macOS

/// システム設定＞キーボード＞キーボードショートカット（com.apple.symbolichotkeys）
enum SystemHotkeys {
    static func scan() -> [HotkeyEntry] {
        guard let table = HotkeyScanners.preference("AppleSymbolicHotKeys", "com.apple.symbolichotkeys") as? [String: Any] else { return [] }
        var entries: [HotkeyEntry] = []
        for (key, raw) in table {
            guard let item = raw as? [String: Any], let value = item["value"] as? [String: Any],
                  (value["type"] as? String ?? "standard") == "standard",
                  let parameters = value["parameters"] as? [Int], parameters.count >= 3,
                  parameters[1] != 65535 else { continue }
            let id = Int(key) ?? -1
            let title = names[id].map { L($0) } ?? L("システムのホットキー（ID %@）", key)
            entries.append(HotkeyEntry(source: .system,
                                       combo: KeyCombo(keyCode: parameters[1], modifiers: KeyModifiers(cocoaFlags: parameters[2])),
                                       title: title, scope: L("システム全体"),
                                       isEnabled: (item["enabled"] as? Bool) ?? ((item["enabled"] as? Int) == 1)))
        }
        return entries
    }

    /// AppleSymbolicHotKeys の番号と項目名
    static let names: [Int: String] = [
        7: "メニューバーを操作対象にする", 8: "Dockを操作対象にする", 9: "アクティブなウインドウまたは次のウインドウを操作対象にする",
        10: "ウインドウのツールバーを操作対象にする", 11: "フローティングウインドウを操作対象にする", 12: "キーボード操作の対象を切り替える",
        13: "ウインドウ内の操作対象を変更する", 15: "ズーム機能のオン／オフ", 17: "ズームイン", 19: "ズームアウト",
        21: "カラーを反転", 23: "イメージをスムージング", 25: "コントラストを上げる", 26: "コントラストを下げる",
        27: "次のウインドウを操作対象にする", 28: "画面のピクチャをファイルとして保存", 29: "画面のピクチャをクリップボードにコピー",
        30: "選択部分のピクチャをファイルとして保存", 31: "選択部分のピクチャをクリップボードにコピー",
        32: "Mission Control", 33: "アプリケーションウインドウ", 34: "Mission Control", 35: "アプリケーションウインドウ",
        36: "デスクトップを表示", 37: "デスクトップを表示", 51: "ウインドウの引き出しを操作対象にする",
        52: "Dockを自動的に表示／非表示", 57: "ステータスメニューを操作対象にする", 59: "VoiceOverのオン／オフ",
        60: "前の入力ソースを選択", 61: "入力メニューの次のソースを選択", 64: "Spotlight検索を表示",
        65: "Finderの検索ウインドウを表示", 70: "辞書で調べる", 79: "左の操作スペースに移動", 80: "左の操作スペースに移動",
        81: "右の操作スペースに移動", 82: "右の操作スペースに移動", 98: "ヘルプメニューを表示",
        118: "デスクトップ1へ切り替える", 119: "デスクトップ2へ切り替える", 120: "デスクトップ3へ切り替える",
        121: "デスクトップ4へ切り替える", 122: "デスクトップ5へ切り替える", 123: "デスクトップ6へ切り替える",
        124: "デスクトップ7へ切り替える", 125: "デスクトップ8へ切り替える", 126: "デスクトップ9へ切り替える",
        160: "Launchpadを表示", 162: "アクセシビリティコントロールを表示", 163: "通知センターを表示",
        175: "おやすみモードのオン／オフ", 184: "スクリーンショットと収録のオプション", 190: "クイックメモ"
    ]
}

/// システム設定のサービスに付けたホットキー（pbs）
enum ServicesHotkeys {
    static func scan() -> [HotkeyEntry] {
        guard let status = HotkeyScanners.preference("NSServicesStatus", "pbs") as? [String: Any] else { return [] }
        var entries: [HotkeyEntry] = []
        for (key, raw) in status {
            guard let item = raw as? [String: Any], let equivalent = item["key_equivalent"] as? String, !equivalent.isEmpty,
                  let combo = KeyNames.comboFromKeyEquivalent(equivalent) else { continue }
            // "バンドルID - サービス名 - メッセージ"
            let parts = key.components(separatedBy: " - ")
            let title = parts.count >= 2 ? parts[1] : key
            var entry = HotkeyEntry(source: .services, combo: combo, title: title, scope: HotkeyScanners.allApps,
                                    isEnabled: item["enabled_services_menu"] as? Bool ?? true)
            if let owner = parts.first, owner != "(null)" { entry.ownerBundleID = owner; entry.group = HotkeyScanners.appName(bundleID: owner) }
            entries.append(entry)
        }
        return entries
    }
}

/// システム設定＞キーボード＞キーボードショートカット＞アプリのショートカット（NSUserKeyEquivalents）
enum UserKeyEquivalents {
    static func scan() -> [HotkeyEntry] {
        var domains = ["NSGlobalDomain"]
        if let apps = HotkeyScanners.preference("com.apple.custommenu.apps", "com.apple.universalaccess") as? [String] {
            domains += apps.filter { $0 != "NSGlobalDomain" }
        }
        var entries: [HotkeyEntry] = []
        for domain in domains {
            let value = domain == "NSGlobalDomain"
                ? CFPreferencesCopyValue("NSUserKeyEquivalents" as CFString, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
                : HotkeyScanners.preference("NSUserKeyEquivalents", domain)
            guard let table = value as? [String: String] else { continue }
            let scope = domain == "NSGlobalDomain" ? HotkeyScanners.allApps : HotkeyScanners.appName(bundleID: domain)
            for (path, equivalent) in table {
                guard let combo = KeyNames.comboFromKeyEquivalent(equivalent) else { continue }
                // "\u{1B}メニュー\u{1B}項目" はメニューの階層指定
                let parts = path.split(separator: "\u{1B}").map(String.init)
                var entry = HotkeyEntry(source: .userKeyEquivalents, combo: combo, title: parts.last ?? path, scope: scope)
                if parts.count > 1 { entry.group = parts.dropLast().joined(separator: " › ") }
                if domain != "NSGlobalDomain" { entry.ownerBundleID = domain; entry.apps = .only([domain]) }
                entries.append(entry)
            }
        }
        return entries
    }
}

// MARK: - Keyboard Maestro

enum KeyboardMaestroHotkeys {
    static let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Keyboard Maestro/Keyboard Maestro Macros.plist")

    static func scan() -> [HotkeyEntry] {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe),
              let root = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let groups = root["MacroGroups"] as? [[String: Any]] else { return [] }
        var entries: [HotkeyEntry] = []
        for group in groups {
            let groupName = group["Name"] as? String ?? ""
            let groupActive = group["IsActive"] as? Bool ?? true
            let scope = targeting(group["Targeting"] as? [String: Any])
            let apps = targetApps(group["Targeting"] as? [String: Any])
            let activation = group["Activate"] as? String ?? "Normal"
            // グループを有効にする・パレットを出すホットキー
            if let code = group["KeyCode"] as? Int, code >= 0, code != 32767 {
                var entry = HotkeyEntry(source: .keyboardMaestro,
                                        combo: KeyCombo(keyCode: code, modifiers: KeyModifiers(carbonFlags: group["Modifiers"] as? Int ?? 0)),
                                        title: L("グループ「%@」の有効化・パレット", groupName), group: groupName, scope: scope,
                                        isEnabled: groupActive)
                entry.ownerBundleID = "com.stairways.keyboardmaestro.editor"
                entry.apps = apps
                entries.append(entry)
            }
            for macro in group["Macros"] as? [[String: Any]] ?? [] {
                let macroActive = macro["IsActive"] as? Bool ?? true
                for trigger in macro["Triggers"] as? [[String: Any]] ?? [] {
                    guard trigger["MacroTriggerType"] as? String == "HotKey",
                          let code = trigger["KeyCode"] as? Int, code >= 0, code != 32767 else { continue }
                    var entry = HotkeyEntry(source: .keyboardMaestro,
                                            combo: KeyCombo(keyCode: code, modifiers: KeyModifiers(carbonFlags: trigger["Modifiers"] as? Int ?? 0)),
                                            title: macro["Name"] as? String ?? L("（名前なし）"), group: groupName, scope: scope,
                                            isEnabled: groupActive && macroActive)
                    entry.ownerBundleID = "com.stairways.keyboardmaestro.editor"
                    entry.apps = apps
                    if activation != "Normal" { entry.note = L("グループを有効にしたとき・パレット表示中だけ") }
                    entries.append(entry)
                }
            }
        }
        return entries
    }

    static func targeting(_ value: [String: Any]?) -> String {
        guard let value, let mode = value["Targeting"] as? String, mode != "All" else { return HotkeyScanners.allApps }
        var names: [String] = []
        for name in (value["TargetingApps"] as? [[String: Any]] ?? []).compactMap({ $0["Name"] as? String }) where !names.contains(name) {
            names.append(name)
        }
        let list = names.joined(separator: "、")
        return mode == "Excluded" ? L("%@以外", list) : L("%@のみ", list)
    }

    static func targetApps(_ value: [String: Any]?) -> AppScope {
        guard let value, let mode = value["Targeting"] as? String, mode != "All" else { return .all }
        let ids = (value["TargetingApps"] as? [[String: Any]] ?? []).compactMap { $0["BundleIdentifier"] as? String }
        return mode == "Excluded" ? .except(ids) : .only(ids)
    }
}

// MARK: - BetterTouchTool

enum BetterTouchToolHotkeys {
    static let folder = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/BetterTouchTool")

    /// 最新ビルドのデータストア（btt_data_store.version_<版>_build_<日付>）
    static var databaseURL: URL? {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        let stores = names.filter { $0.hasPrefix("btt_data_store.version_") && !$0.contains("-") && !$0.contains("_tmp_") }
        let latest = stores.max { build($0) < build($1) }
        return latest.map { folder.appendingPathComponent($0) }
    }
    private static func build(_ name: String) -> Int {
        Int(name.components(separatedBy: "_build_").last ?? "") ?? 0
    }

    static func scan() -> [HotkeyEntry] {
        guard let url = databaseURL else { return [] }
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { sqlite3_close(db); return [] }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 2000)
        // ZGESTURETYPE 0 がキーボードのホットキー、630 がフォルダ。アプリへの割り当ては自身か親フォルダにある
        let sql = """
        SELECT g.ZKEYCODE, g.ZMODIFIERKEYS, g.ZISENABLED, g.ZNOTES, g.ZSHORTCUT, g.ZACTION,
               p.ZNOTES, IFNULL(p.ZISENABLED, 1), IFNULL(pr.ZACTIVATED, 1), pr.ZNAME3,
               (SELECT a.ZBUNDLEIDENTIFIER FROM ZBTTBASEENTITY a JOIN Z_2APPS_GESTURES j ON j.Z_2GESTURES = a.Z_PK
                 WHERE j.Z_9APPS_GESTURES = g.Z_PK OR j.Z_9APPS_GESTURES = g.ZPARENT LIMIT 1),
               (SELECT a.ZNAME FROM ZBTTBASEENTITY a JOIN Z_2APPS_GESTURES j ON j.Z_2GESTURES = a.Z_PK
                 WHERE j.Z_9APPS_GESTURES = g.Z_PK OR j.Z_9APPS_GESTURES = g.ZPARENT LIMIT 1)
        FROM ZBTTBASEENTITY g
        LEFT JOIN ZBTTBASEENTITY p ON p.Z_PK = g.ZPARENT
        LEFT JOIN ZBTTBASEENTITY pr ON pr.Z_PK = g.ZBELONGSTOPRESET2
        WHERE g.Z_ENT = (SELECT Z_ENT FROM Z_PRIMARYKEY WHERE Z_NAME = 'Gesture')
          AND g.ZGESTURETYPE = 0 AND g.ZKEYCODE >= 0
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(statement) }
        func text(_ index: Int32) -> String? {
            guard let pointer = sqlite3_column_text(statement, index) else { return nil }
            let value = String(cString: pointer)
            return value.isEmpty ? nil : value
        }
        var entries: [HotkeyEntry] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let keyCode = Int(sqlite3_column_int64(statement, 0))
            let modifiers = KeyModifiers(cocoaFlags: Int(sqlite3_column_int64(statement, 1)))
            let enabled = sqlite3_column_int(statement, 2) == 1 && sqlite3_column_int(statement, 7) == 1
                && sqlite3_column_int(statement, 8) != 0
            let action = Int(sqlite3_column_int64(statement, 5))
            let sent = text(4).flatMap(sentShortcut)
            let title = text(3) ?? sent.map { L("キー送信 %@", $0) } ?? (action >= 0 ? L("アクション #%@", String(action)) : L("（メモなし）"))
            let bundle = text(10)
            var scope = HotkeyScanners.allApps
            if let bundle, !bundle.hasPrefix("BT.") { scope = L("%@のみ", text(11) ?? HotkeyScanners.appName(bundleID: bundle)) }
            var entry = HotkeyEntry(source: .betterTouchTool, combo: KeyCombo(keyCode: keyCode, modifiers: modifiers),
                                    title: title, group: [text(9), text(6)].compactMap { $0 }.joined(separator: " › "),
                                    scope: scope, isEnabled: enabled)
            if entry.group?.isEmpty == true { entry.group = nil }
            if let bundle, !bundle.hasPrefix("BT.") { entry.apps = .only([bundle]) }
            if let sent, text(3) != nil { entry.note = L("キー送信 %@", sent) }
            entries.append(entry)
        }
        return entries
    }

    /// ZSHORTCUT の "59,58,124"（修飾キーのキーコードの後に本体のキー）を表記にする
    static func sentShortcut(_ value: String) -> String? {
        let codes = value.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        guard let key = codes.last, key >= 0 else { return nil }
        var modifiers: KeyModifiers = []
        for code in codes.dropLast() {
            switch code {
            case 59, 62: modifiers.insert(.control)
            case 58, 61: modifiers.insert(.option)
            case 56, 60: modifiers.insert(.shift)
            case 55, 54: modifiers.insert(.command)
            case 63: modifiers.insert(.function)
            default: break
            }
        }
        return KeyCombo(keyCode: key, modifiers: modifiers).display
    }
}

// MARK: - Karabiner-Elements

enum KarabinerHotkeys {
    static let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/karabiner/karabiner.json")

    static func scan() -> [HotkeyEntry] {
        guard let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profiles = root["profiles"] as? [[String: Any]],
              let profile = profiles.first(where: { $0["selected"] as? Bool == true }) ?? profiles.first else { return [] }
        let profileName = profile["name"] as? String
        var entries: [HotkeyEntry] = []
        let rules = (profile["complex_modifications"] as? [String: Any])?["rules"] as? [[String: Any]] ?? []
        for rule in rules {
            let description = rule["description"] as? String ?? L("（説明なし）")
            let ruleEnabled = rule["enabled"] as? Bool ?? true
            for manipulator in rule["manipulators"] as? [[String: Any]] ?? [] {
                guard let from = manipulator["from"] as? [String: Any], let name = from["key_code"] as? String,
                      let code = keyCodes[name] else { continue }
                let fromModifiers = from["modifiers"] as? [String: Any]
                let optional = fromModifiers?["optional"] as? [String] ?? []
                var entry = HotkeyEntry(source: .karabiner,
                                        combo: KeyCombo(keyCode: code, modifiers: modifiers(fromModifiers?["mandatory"] as? [String] ?? [])),
                                        title: description, group: profileName,
                                        scope: conditions(manipulator["conditions"] as? [[String: Any]]),
                                        isEnabled: ruleEnabled)
                entry.apps = conditionApps(manipulator["conditions"] as? [[String: Any]])
                entry.allowsExtraModifiers = optional.contains("any")
                entry.note = destination(manipulator)
                entries.append(entry)
            }
        }
        // 単純な置き換え（プロファイル全体と機器ごと）
        var simple = profile["simple_modifications"] as? [[String: Any]] ?? []
        for device in profile["devices"] as? [[String: Any]] ?? [] {
            simple += device["simple_modifications"] as? [[String: Any]] ?? []
        }
        for item in simple {
            guard let from = (item["from"] as? [String: Any])?["key_code"] as? String, let code = keyCodes[from] else { continue }
            var entry = HotkeyEntry(source: .karabiner, combo: KeyCombo(keyCode: code, modifiers: []),
                                    title: L("キーの置き換え（Simple Modifications）"), group: profileName, scope: HotkeyScanners.allApps)
            entry.allowsExtraModifiers = true
            if let to = (item["to"] as? [[String: Any]])?.first { entry.note = "→ " + describe(to) }
            entries.append(entry)
        }
        return entries
    }

    static func modifiers(_ names: [String]) -> KeyModifiers {
        var value: KeyModifiers = []
        for name in names {
            if name.hasSuffix("command") { value.insert(.command) }
            if name.hasSuffix("option") { value.insert(.option) }
            if name.hasSuffix("control") { value.insert(.control) }
            if name.hasSuffix("shift") { value.insert(.shift) }
            if name == "fn" { value.insert(.function) }
        }
        return value
    }

    static func conditions(_ list: [[String: Any]]?) -> String {
        guard let list, !list.isEmpty else { return HotkeyScanners.allApps }
        var parts: [String] = []
        for condition in list {
            let type = condition["type"] as? String ?? ""
            let ids = (condition["bundle_identifiers"] as? [String] ?? []).map(readableBundlePattern).joined(separator: "、")
            switch type {
            case "frontmost_application_if": parts.append(L("%@のみ", ids))
            case "frontmost_application_unless": parts.append(L("%@以外", ids))
            default: parts.append(L("条件付き（%@）", type))
            }
        }
        return parts.joined(separator: "・")
    }

    /// frontmost_application_if / unless だけを判定に使う（ほかの条件は効く可能性ありとして扱う）
    static func conditionApps(_ list: [[String: Any]]?) -> AppScope {
        var scope = AppScope.all
        scope.usesPatterns = true
        for condition in list ?? [] {
            let ids = condition["bundle_identifiers"] as? [String] ?? []
            switch condition["type"] as? String {
            case "frontmost_application_if": scope.only = (scope.only ?? []) + ids
            case "frontmost_application_unless": scope.except += ids
            default: break
            }
        }
        return scope
    }

    /// "^com\\.adobe\\.illustrator$" → "com.adobe.illustrator"
    static func readableBundlePattern(_ pattern: String) -> String {
        pattern.replacingOccurrences(of: "\\.", with: ".").trimmingCharacters(in: CharacterSet(charactersIn: "^$"))
    }

    static func destination(_ manipulator: [String: Any]) -> String? {
        for key in ["to", "to_if_alone", "to_if_held_down"] {
            if let first = (manipulator[key] as? [[String: Any]])?.first { return "→ " + describe(first) }
        }
        return nil
    }

    static func describe(_ event: [String: Any]) -> String {
        if let name = event["key_code"] as? String {
            let mods = modifiers(event["modifiers"] as? [String] ?? [])
            if let code = keyCodes[name] { return KeyCombo(keyCode: code, modifiers: mods).display }
            return mods.symbols + name
        }
        if let command = event["shell_command"] as? String { return "shell: " + String(command.prefix(40)) }
        return event.keys.sorted().joined(separator: ", ")
    }

    /// Karabiner のキー名 → macOS の仮想キーコード
    static let keyCodes: [String: Int] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "non_us_backslash": 10,
        "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21,
        "6": 22, "5": 23, "equal_sign": 24, "9": 25, "7": 26, "hyphen": 27, "8": 28, "0": 29,
        "close_bracket": 30, "o": 31, "u": 32, "open_bracket": 33, "i": 34, "p": 35, "return_or_enter": 36,
        "l": 37, "j": 38, "quote": 39, "k": 40, "semicolon": 41, "backslash": 42, "comma": 43, "slash": 44,
        "n": 45, "m": 46, "period": 47, "tab": 48, "spacebar": 49, "grave_accent_and_tilde": 50,
        "delete_or_backspace": 51, "escape": 53, "right_command": 54, "left_command": 55, "left_shift": 56,
        "caps_lock": 57, "left_option": 58, "left_control": 59, "right_shift": 60, "right_option": 61,
        "right_control": 62, "fn": 63, "f17": 64, "keypad_period": 65, "keypad_asterisk": 67, "keypad_plus": 69,
        "keypad_num_lock": 71, "keypad_slash": 75, "keypad_enter": 76, "keypad_hyphen": 78, "f18": 79, "f19": 80,
        "keypad_equal_sign": 81, "keypad_0": 82, "keypad_1": 83, "keypad_2": 84, "keypad_3": 85, "keypad_4": 86,
        "keypad_5": 87, "keypad_6": 88, "keypad_7": 89, "f20": 90, "keypad_8": 91, "keypad_9": 92,
        "international3": 93, "international1": 94, "keypad_comma": 95, "f5": 96, "f6": 97, "f7": 98, "f3": 99,
        "f8": 100, "f9": 101, "japanese_eisuu": 102, "lang2": 102, "f11": 103, "japanese_kana": 104, "lang1": 104,
        "f13": 105, "f16": 106, "f14": 107, "f10": 109, "f12": 111, "f15": 113, "help": 114, "home": 115,
        "page_up": 116, "delete_forward": 117, "f4": 118, "end": 119, "f2": 120, "page_down": 121, "f1": 122,
        "left_arrow": 123, "right_arrow": 124, "down_arrow": 125, "up_arrow": 126
    ]
}

// MARK: - Alfred

enum AlfredHotkeys {
    static let support = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Alfred")

    /// 同期フォルダを使っていれば prefs.json の current、ローカル設定のフォルダ名は localhash
    static var locations: (preferences: URL, local: URL?) {
        let fallback = support.appendingPathComponent("Alfred.alfredpreferences")
        guard let data = try? Data(contentsOf: support.appendingPathComponent("prefs.json")),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return (fallback, nil) }
        let preferences = (json["current"] as? String).map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) } ?? fallback
        let local = (json["localhash"] as? String).map { preferences.appendingPathComponent("preferences/local/\($0)") }
        return (preferences, local)
    }

    static func plist(_ url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
    }

    /// 未設定は key -1、または修飾なしで表記も空
    static func combo(key: Any?, mod: Any?, string: Any?) -> KeyCombo? {
        guard let code = key as? Int, code >= 0 else { return nil }
        let flags = mod as? Int ?? 0
        if flags <= 0 && (string as? String ?? "").isEmpty { return nil }
        return KeyCombo(keyCode: code, modifiers: KeyModifiers(cocoaFlags: max(flags, 0)))
    }

    static func scan() -> [HotkeyEntry] {
        let (root, local) = locations
        let owner = HotkeySource.alfred.bundleIDs[0]
        var entries: [HotkeyEntry] = []
        func add(_ combo: KeyCombo?, _ title: String, group: String? = nil, scope: String = HotkeyScanners.allApps, apps: AppScope = .all,
                 enabled: Bool = true, note: String? = nil) {
            guard let combo else { return }
            var entry = HotkeyEntry(source: .alfred, combo: combo, title: title, group: group, scope: scope, isEnabled: enabled)
            entry.ownerBundleID = owner
            entry.apps = apps
            entry.note = note
            entries.append(entry)
        }
        // Alfred を呼び出すホットキー（Mac ごとの設定）
        if let local, let hotkey = plist(local.appendingPathComponent("hotkey/prefs.plist"))?["default"] as? [String: Any] {
            add(combo(key: hotkey["key"], mod: hotkey["mod"], string: hotkey["string"]), L("Alfredを表示"))
        }
        // 機能ごとのホットキー
        let features: [(path: String, key: String, title: String)] = [
            ("clipboard", "hotkey", "クリップボード履歴を表示"),
            ("snippets", "hotkey", "スニペットを表示"),
            ("itunes", "hotkey", "ミニプレーヤーを表示"),
            ("filesearch/navigation", "previousPathHotkey", "前のパスへ戻る"),
            ("filesearch/actions", "finderSelectionHotkey", "Finderの選択項目のアクション")
        ]
        for feature in features {
            guard let hotkey = plist(root.appendingPathComponent("preferences/features/\(feature.path)/prefs.plist"))?[feature.key] as? [String: Any] else { continue }
            var enabled = true
            if feature.path == "clipboard", let local {
                enabled = plist(local.appendingPathComponent("features/clipboard/prefs.plist"))?["enabled"] as? Bool ?? false
            }
            add(combo(key: hotkey["key"], mod: hotkey["mod"], string: hotkey["string"]), L(feature.title), group: L("機能"), enabled: enabled)
        }
        // ワークフローのホットキー
        let folder = root.appendingPathComponent("workflows")
        for name in (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [] {
            guard let info = plist(folder.appendingPathComponent(name).appendingPathComponent("info.plist")) else { continue }
            let workflow = info["name"] as? String ?? name
            let workflowEnabled = !(info["disabled"] as? Bool ?? false)
            let notes = info["uidata"] as? [String: [String: Any]] ?? [:]
            for object in info["objects"] as? [[String: Any]] ?? [] where object["type"] as? String == "alfred.workflow.trigger.hotkey" {
                let config = object["config"] as? [String: Any] ?? [:]
                // メモは作者の定型文のこともあるので名前にせず、1 行目を補足に出す
                let note = (object["uid"] as? String).flatMap { notes[$0]?["note"] as? String }?
                    .components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespaces)
                    .prefix(60)
                var scope = HotkeyScanners.allApps
                var appScope = AppScope.all
                let related = config["relatedApps"] as? [String] ?? []
                let apps = related.map(HotkeyScanners.appName).joined(separator: "、")
                if !apps.isEmpty {
                    switch config["relatedAppsMode"] as? Int ?? 0 {
                    case 1: scope = L("%@のみ", apps); appScope = .only(related)
                    case 2: scope = L("%@以外", apps); appScope = .except(related)
                    default: break
                    }
                }
                add(combo(key: config["hotkey"], mod: config["hotmod"], string: config["hotstring"]),
                    workflow, group: L("ワークフロー"), scope: scope, apps: appScope,
                    enabled: workflowEnabled && !(object["disabled"] as? Bool ?? false),
                    note: note.flatMap { $0.isEmpty ? nil : String($0) })
            }
        }
        return entries
    }
}

// MARK: - Default Folder X

enum DefaultFolderXHotkeys {
    static func scan() -> [HotkeyEntry] {
        // Setapp 版と単体版で設定のドメインが異なる。動いている方、無ければ設定のある方
        let domains = HotkeySource.defaultFolderX.bundleIDs
        let running = NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)
        let ordered = domains.filter { running.contains($0) } + domains.filter { !running.contains($0) }
        guard let domain = ordered.first(where: { HotkeyScanners.preference("keyBindings", $0) != nil }),
              let bindings = HotkeyScanners.preference("keyBindings", domain) as? [[String: Any]] else { return [] }
        let inDialogs = HotkeyScanners.preference("hotkeysInFileDialogs", domain) as? Bool ?? true
        let inFinder = HotkeyScanners.preference("hotkeysInFinder", domain) as? Bool ?? true
        var group: String?
        var entries: [HotkeyEntry] = []
        for binding in bindings {
            let name = binding["name"] as? String ?? ""
            if binding["action"] as? String == "groupName:" { group = name; continue }
            guard let key = binding["key"] as? [String: Any], let code = key["keyCode"] as? Int else { continue }
            let context = binding["context"] as? Int ?? 0
            let scope: String
            var enabled = true
            var apps = AppScope.all
            switch context {
            case 1: scope = L("ファイルダイアログ"); enabled = inDialogs
            case 2: scope = "Finder"; enabled = inFinder; apps = .only(["com.apple.finder"])
            case 4: scope = HotkeyScanners.allApps
            case 16: scope = L("クイックサーチのウインドウ")
            default: scope = L("その他（%@）", String(context))
            }
            var entry = HotkeyEntry(source: .defaultFolderX,
                                    combo: KeyCombo(keyCode: code, modifiers: KeyModifiers(cocoaFlags: key["modifierFlags"] as? Int ?? 0)),
                                    title: name, group: group, scope: scope, isEnabled: enabled)
            entry.apps = apps
            entry.ownerBundleID = domain
            entries.append(entry)
        }
        return entries
    }
}

// MARK: - Keystroke Pro

/// サンドボックスのアプリ。コンテナの設定は cfprefsd 経由（ドメインにファイルのパスを渡す）で読む
enum KeystrokeProHotkeys {
    static let domain = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Containers/de.ixeau.KeystrokePro2/Data/Library/Preferences/de.ixeau.KeystrokePro2").path

    static func scan() -> [HotkeyEntry] {
        guard let character = HotkeyScanners.preference("hotKeyCharacter", domain) as? String, !character.isEmpty,
              let key = KeyNames.keyCode(forCharacter: character, caseImpliesShift: false) else { return [] }
        var modifiers: KeyModifiers = key.shift ? .shift : []
        for (name, flag) in [("Command", KeyModifiers.command), ("Control", .control), ("Option", .option), ("Shift", .shift)]
        where HotkeyScanners.preference("hotKeyModifier" + name, domain) as? Bool == true {
            modifiers.insert(flag)
        }
        var entry = HotkeyEntry(source: .keystrokePro, combo: KeyCombo(keyCode: key.keyCode, modifiers: modifiers),
                                title: L("キー表示のオン／オフ"), scope: HotkeyScanners.allApps)
        entry.ownerBundleID = HotkeySource.keystrokePro.bundleIDs[0]
        return [entry]
    }
}

// MARK: - 自作アプリ（swwwitch）

/// 各アプリが Shared/HotkeyManifest で書き出した JSON（~/Library/Application Support/swwwitch/Hotkeys/<Bundle ID>.json）
enum SwAppHotkeys {
    static let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/swwwitch/Hotkeys")

    private struct Item: Decodable {
        var id: String
        var title: String
        var keyCode: Int
        var modifiers: Int
        var enabled: Bool?
        var scope: String?
        var apps: [String]?
        var note: String?
    }
    private struct Document: Decodable {
        var app: String
        var bundleID: String
        var hotkeys: [Item]
    }

    static func scan() -> [HotkeyEntry] {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        var entries: [HotkeyEntry] = []
        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file), let document = try? JSONDecoder().decode(Document.self, from: data) else { continue }
            // アプリを削除した後に残ったファイルは読まない
            guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: document.bundleID) != nil else { continue }
            let appName = HotkeyScanners.appName(bundleID: document.bundleID)
            for item in document.hotkeys where item.keyCode >= 0 {
                // 入っていないアプリ（Path Finder の通常版と Setapp 版の片方など）は除き、同じ名前は一度だけ
                var names: [String] = []
                for id in item.apps ?? [] where NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) != nil {
                    let name = HotkeyScanners.appName(bundleID: id)
                    if !names.contains(name) { names.append(name) }
                }
                let apps = names.joined(separator: "、")
                let scope: String
                var appScope = AppScope.all
                switch item.scope ?? "all" {
                case "only" where !apps.isEmpty: scope = L("%@のみ", apps); appScope = .only(item.apps ?? [])
                case "except" where !apps.isEmpty: scope = L("%@以外", apps); appScope = .except(item.apps ?? [])
                case "custom": scope = item.note ?? L("条件付き")
                default: scope = HotkeyScanners.allApps
                }
                var entry = HotkeyEntry(source: .swApps, combo: KeyCombo(keyCode: item.keyCode, modifiers: KeyModifiers(carbonFlags: item.modifiers)),
                                        title: item.title, group: appName.isEmpty ? document.app : appName, scope: scope,
                                        isEnabled: item.enabled ?? true)
                entry.ownerBundleID = document.bundleID
                entry.apps = appScope
                if item.scope != "custom" { entry.note = item.note }
                entries.append(entry)
            }
        }
        return entries
    }
}

// MARK: - KeyboardShortcuts 形式

/// sindresorhus/KeyboardShortcuts を使うアプリ。設定に "KeyboardShortcuts_<名前>" = {"carbonKeyCode":…,"carbonModifiers":…} の JSON 文字列で入る
enum KeyboardShortcutsHotkeys {
    static let prefix = "KeyboardShortcuts_"

    /// 設定ファイルのあるドメイン：通常のアプリと、サンドボックスのアプリのコンテナ（コンテナはパスをドメインにして cfprefsd 経由で読む）
    static var domains: [(domain: String, bundleID: String)] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let manager = FileManager.default
        var list: [(String, String)] = []
        let preferences = home.appendingPathComponent("Library/Preferences")
        for name in (try? manager.contentsOfDirectory(atPath: preferences.path)) ?? [] where name.hasSuffix(".plist") && !name.hasPrefix("com.apple.") {
            let id = String(name.dropLast(6))
            list.append((id, id))
        }
        let containers = home.appendingPathComponent("Library/Containers")
        for id in (try? manager.contentsOfDirectory(atPath: containers.path)) ?? [] where !id.hasPrefix("com.apple.") {
            let path = containers.appendingPathComponent(id).appendingPathComponent("Data/Library/Preferences/\(id)").path
            if manager.fileExists(atPath: path + ".plist") { list.append((path, id)) }
        }
        return list
    }

    static func scan() -> [HotkeyEntry] {
        var entries: [HotkeyEntry] = []
        var seen: Set<String> = []
        for (domain, bundleID) in domains {
            guard let keys = CFPreferencesCopyKeyList(domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [String] else { continue }
            let names = keys.filter { $0.hasPrefix(prefix) }
            guard !names.isEmpty, NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil,
                  seen.insert(bundleID).inserted else { continue }
            let appName = HotkeyScanners.appName(bundleID: bundleID)
            for name in names.sorted() {
                guard let text = HotkeyScanners.preference(name, domain) as? String, let data = text.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let code = json["carbonKeyCode"] as? Int, code >= 0 else { continue }
                var entry = HotkeyEntry(source: .keyboardShortcuts,
                                        combo: KeyCombo(keyCode: code, modifiers: KeyModifiers(carbonFlags: json["carbonModifiers"] as? Int ?? 0)),
                                        title: String(name.dropFirst(prefix.count)), group: appName, scope: HotkeyScanners.allApps)
                entry.ownerBundleID = bundleID
                entries.append(entry)
            }
        }
        return entries
    }
}
