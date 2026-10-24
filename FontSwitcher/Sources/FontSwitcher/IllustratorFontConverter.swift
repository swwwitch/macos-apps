import AppKit
import SwiftUI

/// 起動中の Illustrator に JSX を送って結果を受け取る。osascript の do javascript で送り、
/// JSX は1行目に「OK」か「ERR」、2行目から結果を返す
enum IllustratorBridge {
    static let bundleID = "com.adobe.illustrator"

    enum Failure: Error {
        case notRunning
        /// JSX が返した理由（noDocument・noSelection・noTarget）
        case refused(String)
        case script(String)
    }

    static var isRunning: Bool { !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty }

    static func run(_ jsx: String) async throws -> [String] {
        guard isRunning else { throw Failure.notRunning }
        let output = try await Task.detached(priority: .userInitiated) { () throws -> String in
            let file = FileManager.default.temporaryDirectory.appendingPathComponent("FontSwitcher-\(UUID().uuidString).jsx")
            try jsx.write(to: file, atomically: true, encoding: .utf8)
            defer { try? FileManager.default.removeItem(at: file) }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            // 大きなドキュメントでは数分かかるので、Apple イベントの待ち時間（既定2分）を延ばす
            process.arguments = ["-e", "on run argv", "-e", "with timeout of 3600 seconds",
                                 "-e", "tell application id \"\(bundleID)\" to do javascript (POSIX file (item 1 of argv) as alias)",
                                 "-e", "end timeout", "-e", "end run", file.path]
            let out = Pipe(), err = Pipe()
            process.standardOutput = out
            process.standardError = err
            try process.run()
            let data = out.fileHandleForReading.readDataToEndOfFile()
            let errorData = err.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                throw Failure.script(String(decoding: errorData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
            }
            return String(decoding: data, as: UTF8.self)
        }.value
        // osascript は改行を「\r」で返すことがあるので、どちらでも分ける
        let lines = output.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: CharacterSet(charactersIn: "\r\n"))
        guard let head = lines.first else { throw Failure.script("") }
        if head == "ERR" { throw Failure.refused(lines.dropFirst().first ?? "") }
        guard head == "OK" else { throw Failure.script(lines.joined(separator: "\n")) }
        return Array(lines.dropFirst()).filter { !$0.isEmpty }
    }

    /// JS の値に書き換える（文字列の配列・オブジェクト）。JSON は ES3 の式としてそのまま読める
    static func literal(_ value: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed]) else { return "null" }
        return String(decoding: data, as: UTF8.self)
    }
}

/// Illustrator の中の操作（AiFontConverter.jsx の対象の集め方・ロック・非表示・適用をそのまま写したもの）
enum IllustratorFontScripts {
    private static func options(_ settings: ConverterSettings) -> String {
        IllustratorBridge.literal([
            "target": settings.target.rawValue, "locked": settings.includeLocked,
            "hidden": settings.includeHidden, "styles": settings.appliesToStyles,
        ] as [String: Any])
    }

    /// 対象のテキストで使われているフォントの PostScript 名
    static func scan(_ settings: ConverterSettings) -> String {
        prelude(settings) + """
            var frames = collectTargetFrames();
            if (frames === null) return "ERR\\nnoSelection";
            if (frames.length === 0 && !OPT.styles) return "ERR\\nnoTarget";
            var seen = {}, names = [];
            function note(name) { if (name && !seen["_" + name]) { seen["_" + name] = true; names.push(name); } }
            for (var i = 0; i < frames.length; i++) {
                var runs = collectFontRuns(frames[i]);
                for (var r = 0; r < runs.length; r++) note(runs[r].fontName);
            }
            if (OPT.styles) {
                var collections = [doc.paragraphStyles, doc.characterStyles];
                for (var c = 0; c < collections.length; c++) {
                    for (var k = 0; k < collections[c].length; k++) note(styleFontName(collections[c][k]));
                }
            }
            return "OK\\n" + names.join("\\n");
        })();
        """
    }

    /// Illustrator で使えるフォントだけを返す。環境に無いフォントも app.textFonts に仮の項目（style が空で family が PostScript 名）で並ぶので除く
    static func installed(_ names: [String]) -> String {
        """
        (function () {
            var NAMES = \(IllustratorBridge.literal(names));
            var found = [];
            for (var i = 0; i < NAMES.length; i++) {
                try {
                    var font = app.textFonts.getByName(NAMES[i]);
                    if (!(font.style === "" && font.family === font.name)) found.push(NAMES[i]);
                } catch (e) { }
            }
            return "OK\\n" + found.join("\\n");
        })();
        """
    }

    /// 旧名 → 新名で置き換え、変えたテキストオブジェクトの数を返す
    static func apply(_ settings: ConverterSettings, map: [String: String]) -> String {
        prelude(settings) + """
            var OLD = \(IllustratorBridge.literal(Array(map.keys)));
            var NEW = \(IllustratorBridge.literal(Array(map.values)));
            var nameMap = {}, fontCache = {};
            for (var m = 0; m < OLD.length; m++) nameMap["_" + OLD[m]] = NEW[m];
            function fontObject(name) {
                if (!fontCache["_" + name]) fontCache["_" + name] = app.textFonts.getByName(name);
                return fontCache["_" + name];
            }
            var frames = collectTargetFrames();
            if (frames === null) return "ERR\\nnoSelection";
            var changed = 0;
            for (var i = 0; i < frames.length; i++) {
                var frame = frames[i];
                var runs = collectFontRuns(frame);
                var hasMapped = false;
                for (var r = 0; r < runs.length; r++) { if (runs[r].fontName && nameMap["_" + runs[r].fontName]) { hasMapped = true; break; } }
                if (!hasMapped) continue;
                // 外側（レイヤー）から解除する。ロックしたレイヤーの中のアイテムは解除できないため
                var containers = [frame].concat(ancestors(frame));
                var savedLocked = [], savedHidden = [];
                for (var a = containers.length - 1; a >= 0; a--) {
                    savedLocked[a] = containers[a].locked;
                    if (OPT.locked && savedLocked[a]) setLocked(containers[a], false);
                    savedHidden[a] = isHidden(containers[a]);
                    if (OPT.hidden && savedHidden[a]) setHidden(containers[a], false);
                }
                var frameChanged = false;
                var offset = frame.textRange.start;
                for (var r2 = 0; r2 < runs.length; r2++) {
                    var newName = runs[r2].fontName ? nameMap["_" + runs[r2].fontName] : null;
                    if (!newName) continue;
                    var range = frame.textRange;
                    range.start = offset + runs[r2].start;
                    range.end = offset + runs[r2].end;
                    try { range.characterAttributes.textFont = fontObject(newName); frameChanged = true; } catch (e) { }
                }
                // 内側から戻し、外側のレイヤーを最後にロックする
                for (var b = 0; b < containers.length; b++) {
                    if (OPT.hidden && savedHidden[b]) setHidden(containers[b], true);
                    if (OPT.locked && savedLocked[b]) setLocked(containers[b], true);
                }
                if (frameChanged) changed++;
            }
            if (OPT.styles) {
                var collections = [doc.paragraphStyles, doc.characterStyles];
                for (var c = 0; c < collections.length; c++) {
                    for (var k = 0; k < collections[c].length; k++) {
                        var styleName = styleFontName(collections[c][k]);
                        var mapped = styleName ? nameMap["_" + styleName] : null;
                        if (mapped) { try { collections[c][k].characterAttributes.textFont = fontObject(mapped); } catch (e) { } }
                    }
                }
            }
            return "OK\\n" + changed;
        })();
        """
    }

    /// 共通の部分：ドキュメントの確認と対象の集め方。collectTargetFrames() は選択が空なら null
    private static func prelude(_ settings: ConverterSettings) -> String {
        """
        (function () {
            var OPT = \(options(settings));
            if (app.documents.length === 0) return "ERR\\nnoDocument";
            var doc = app.activeDocument;
            function selectedItems() {
                var selection = doc.selection, items = [];
                if (!selection) return items;
                // 文字の選択中は TextRange になり [0] が無い。そのストーリーのテキストフレームを対象にする
                if (selection.typename === "TextRange") {
                    for (var i = 0; i < selection.story.textFrames.length; i++) items.push(selection.story.textFrames[i]);
                    return items;
                }
                for (var j = 0; j < selection.length; j++) items.push(selection[j]);
                return items;
            }
            function ancestors(item) {
                var list = [], parent = item.parent;
                while (parent && (parent.typename === "Layer" || parent.typename === "GroupItem")) { list.push(parent); parent = parent.parent; }
                return list;
            }
            function isHidden(container) { return container.typename === "Layer" ? !container.visible : container.hidden; }
            function setLocked(container, locked) { try { container.locked = locked; } catch (e) { } }
            function setHidden(container, hidden) {
                try { if (container.typename === "Layer") container.visible = !hidden; else container.hidden = hidden; } catch (e) { }
            }
            function lockedEffective(item) {
                if (item.locked) return true;
                var list = ancestors(item);
                for (var i = 0; i < list.length; i++) if (list[i].locked) return true;
                return false;
            }
            function hiddenEffective(item) {
                if (isHidden(item)) return true;
                var list = ancestors(item);
                for (var i = 0; i < list.length; i++) if (isHidden(list[i])) return true;
                return false;
            }
            function intersects(a, b) { return !(a[2] < b[0] || a[0] > b[2] || a[3] > b[1] || a[1] < b[3]); }
            function documentFrames(rect) {
                var list = [];
                for (var i = 0; i < doc.textFrames.length; i++) {
                    var frame = doc.textFrames[i];
                    if (!OPT.locked && lockedEffective(frame)) continue;
                    if (!OPT.hidden && hiddenEffective(frame)) continue;
                    if (rect && !intersects(frame.geometricBounds, rect)) continue;
                    list.push(frame);
                }
                return list;
            }
            function framesInSelection(items, list) {
                for (var i = 0; i < items.length; i++) {
                    if (items[i].typename === "TextFrame") list.push(items[i]);
                    else if (items[i].typename === "GroupItem") framesInSelection(items[i].pageItems, list);
                }
            }
            function collectTargetFrames() {
                if (OPT.target === "document") return documentFrames(null);
                if (OPT.target === "artboard") return documentFrames(doc.artboards[doc.artboards.getActiveArtboardIndex()].artboardRect);
                var items = selectedItems();
                if (items.length === 0) return null;
                var list = [];
                framesInSelection(items, list);
                return list;
            }
            function styleFontName(style) {
                try { var font = style.characterAttributes.textFont; return font ? font.name : null; } catch (e) { return null; }
            }
            // 同じフォントが続く区間。start と end はフレームの中の文字番号（end は含まない）
            function collectFontRuns(frame) {
                var runs = [], chars = frame.characters, count = chars.length, i = 0;
                while (i < count) {
                    var font = chars[i].characterAttributes.textFont, name = font ? font.name : "";
                    var j = i + 1;
                    while (j < count) {
                        var next = chars[j].characterAttributes.textFont;
                        if ((next ? next.name : "") !== name) break;
                        j++;
                    }
                    runs.push({ fontName: name, start: i, end: j });
                    i = j;
                }
                return runs;
            }

        """
    }
}

// MARK: - 画面

@MainActor
final class FontConverterWindow {
    static let shared = FontConverterWindow()
    private var window: NSWindow?

    func show() {
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 520),
                                  styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            window.title = L("Illustratorのフォントを統一")
            window.isReleasedWhenClosed = false
            let hosting = NSHostingView(rootView: FontConverterView().frame(minWidth: 560, maxWidth: .infinity, minHeight: 480, maxHeight: .infinity))
            hosting.sizingOptions = [.minSize]
            window.contentView = hosting
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func close() { window?.performClose(nil) }
}

@MainActor
final class FontConverterModel: ObservableObject {
    enum Phase {
        case settings
        case working(String)
        case confirm([FontConverterRules.Change])
        case done(Int)
    }

    @Published var settings = ConverterSettings()
    @Published var phase: Phase = .settings
    /// 確認で適用する旧フォント名
    @Published var chosen = Set<String>()
    @Published var error: String?

    /// 使われているフォントを集め、変換先を Illustrator で確かめて、確認の一覧を作る
    func scan() {
        phase = .working(L("Illustratorのフォントを調べています…"))
        let settings = settings
        Task {
            do {
                let used = try await IllustratorBridge.run(IllustratorFontScripts.scan(settings))
                var plans: [(String, FontConverterRules.Plan)] = []
                for name in used {
                    if let plan = FontConverterRules.plan(name, settings) { plans.append((name, plan)) }
                }
                let probe = Array(Set(plans.flatMap { FontConverterRules.probeNames($0.1) }))
                let installed = probe.isEmpty ? [] : Set(try await IllustratorBridge.run(IllustratorFontScripts.installed(probe)))
                let changes = plans.map { FontConverterRules.classify($0.0, $0.1, installed: installed) }
                guard !changes.isEmpty else {
                    phase = .settings
                    error = L("変更対象のフォントが見つかりませんでした。")
                    return
                }
                chosen = Set(changes.compactMap { if case .missing = $0 { return nil } else { return $0.old } })
                phase = .confirm(changes.sorted { $0.old < $1.old })
            } catch {
                phase = .settings
                self.error = Self.message(error)
            }
        }
    }

    func apply(_ changes: [FontConverterRules.Change]) {
        var map: [String: String] = [:]
        for change in changes where chosen.contains(change.old) {
            if case .missing = change { continue }
            map[change.old] = change.new
        }
        guard !map.isEmpty else { phase = .settings; return }
        phase = .working(L("フォントを置き換えています…"))
        let settings = settings
        Task {
            do {
                let result = try await IllustratorBridge.run(IllustratorFontScripts.apply(settings, map: map))
                phase = .done(Int(result.first ?? "") ?? 0)
            } catch {
                phase = .settings
                self.error = Self.message(error)
            }
        }
    }

    private static func message(_ error: Error) -> String {
        switch error as? IllustratorBridge.Failure {
        case .notRunning: return L("Illustratorが起動していません。")
        case .refused(let reason):
            switch reason {
            case "noDocument": return L("ドキュメントが開かれていません。")
            case "noSelection": return L("テキストオブジェクトを選択してください。")
            default: return L("対象となるテキストが見つかりませんでした。")
            }
        case .script(let detail): return L("Illustratorに送れませんでした。") + (detail.isEmpty ? "" : "\n" + detail)
        case nil: return error.localizedDescription
        }
    }
}

private struct FontConverterView: View {
    @StateObject private var model = FontConverterModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch model.phase {
            case .settings: ConverterSettingsForm(model: model)
            case .working(let text):
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                    Text(text).foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            case .confirm(let changes): ConverterConfirmList(model: model, changes: changes)
            case .done(let count):
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "checkmark.circle").font(.system(size: 36)).foregroundStyle(.green).accessibilityHidden(true)
                    Text(L("処理が完了しました。")).font(.headline)
                    Text(L("変更数") + L(" :") + " \(count)").foregroundStyle(.secondary)
                    Spacer()
                    HStack {
                        Spacer()
                        Button(L("設定に戻る")) { model.phase = .settings }
                        Button(L("閉じる")) { FontConverterWindow.shared.close() }.keyboardShortcut(.defaultAction)
                    }
                }
                .padding(20)
            }
        }
        .alert(L("Illustratorのフォントを統一"), isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK") {}
        } message: {
            Text(model.error ?? "")
        }
    }
}

/// 対象範囲・変換設定（文字セット・N・新ゴ/新ゴNT・UD・AP版、Max・MaxN）・処理オプション
private struct ConverterSettingsForm: View {
    @ObservedObject var model: FontConverterModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox(L("対象範囲")) {
                Picker(L("対象範囲"), selection: $model.settings.target) {
                    Text(L("選択オブジェクト")).tag(ConverterSettings.Target.selection)
                    Text(L("ドキュメント全体")).tag(ConverterSettings.Target.document)
                    Text(L("アクティブアートボード")).tag(ConverterSettings.Target.artboard)
                }
                .pickerStyle(.radioGroup).labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
                .help(L("フォント種別を変更する範囲を選びます。選択オブジェクト、ドキュメント全体、アクティブアートボード内から選択できます。"))
            }
            GroupBox(L("変換設定")) {
                VStack(spacing: 12) {
                    HStack(alignment: .top, spacing: 28) {
                        column(L("文字セット"), help: L("文字セットを Std / Pro / Pr5 / Pr6 から選びます。N の有無は別の「N設定」で切り替えます。")) {
                            Picker(L("文字セット"), selection: charsetBinding) {
                                Text(L("現状維持")).tag(String?.none)
                                ForEach(["Std", "Pro", "Pr5", "Pr6"], id: \.self) { Text(verbatim: $0).tag(String?.some($0)) }
                            }
                        }
                        VStack(alignment: .leading, spacing: 12) {
                            column(L("N（JIS2004対応）"), help: L("N あり/なしを切り替えます。例：Pr6 → Pr6N。現状維持では現在の N 状態を保ちます。")) {
                                switchPicker(nBinding, off: L("Nなし"), on: L("Nあり"))
                            }
                            column(L("新ゴ / 新ゴNT"), help: L("新ゴと新ゴNTを切り替えます。対象は新ゴ系ファミリーのみです。")) {
                                switchPicker($model.settings.nt, off: L("NTなし"), on: L("NTあり"))
                            }
                        }
                        VStack(alignment: .leading, spacing: 12) {
                            column(L("UD"), help: L("UD 書体があるファミリーだけ、UD あり/なしを切り替えます。対応しないファミリーでは無視されます。")) {
                                switchPicker($model.settings.ud, off: L("UDなし"), on: L("UDあり"))
                            }
                            column(L("AP版"), help: L("AP版書体")) {
                                switchPicker($model.settings.p, off: L("Pなし"), on: L("Pあり"))
                            }
                        }
                    }
                    HStack(spacing: 8) {
                        Button("Max") { preset(withN: false) }
                            .help(L("N なしで収録文字数が最も多い文字セットを選び、UD・P・NT をありにします。"))
                        Button("MaxN") { preset(withN: true) }
                            .help(L("N ありを含めて収録文字数が最も多い文字セットを選び、UD・P・NT をありにします。"))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            GroupBox(L("処理オプション")) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(L("G-OTF学参書体をA-OTFに統合"), isOn: $model.settings.integrateGakusan)
                        .help(L("G-OTF の学参・常改・K書体を、通常の A-OTF 書体として扱って変換します。"))
                    Toggle(L("段落/文字スタイルも変更"), isOn: $model.settings.includeStyles)
                        .disabled(model.settings.target != .document)
                        .help(L("段落スタイル・文字スタイルに設定されたフォントも、同じ条件で変更します。"))
                    Toggle(L("ロックされたオブジェクトも対象にする"), isOn: $model.settings.includeLocked)
                        .help(L("ロック中のオブジェクトも一時的に解除して変更し、処理後に元のロック状態へ戻します。"))
                    Toggle(L("非表示オブジェクトも対象にする"), isOn: $model.settings.includeHidden)
                        .help(L("非表示のオブジェクトも一時的に表示して変更し、処理後に元の表示状態へ戻します。"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 0)
            HStack {
                Text(L("起動中のIllustratorの前面のドキュメントに対して実行します。"))
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(L("キャンセル")) { FontConverterWindow.shared.close() }.keyboardShortcut(.cancelAction)
                Button(L("OK")) { model.scan() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
    }

    /// 文字セット・N を手で変えたら Max・MaxN の扱い（AXIS を ProN に寄せる）を外す
    private var charsetBinding: Binding<String?> {
        Binding(get: { model.settings.charset }, set: { model.settings.charset = $0; model.settings.maxPreset = false })
    }

    private var nBinding: Binding<ConverterSettings.Switch> {
        Binding(get: { model.settings.n }, set: { model.settings.n = $0; model.settings.maxPreset = false })
    }

    /// Max は N なし、MaxN は N ありで、収録文字数の最も多い文字セット（Pr6）。UD・P・NT はあり
    private func preset(withN: Bool) {
        model.settings.charset = "Pr6"
        model.settings.n = withN ? .on : .off
        model.settings.ud = .on
        model.settings.p = .on
        model.settings.nt = .on
        model.settings.maxPreset = true
    }

    private func column<Content: View>(_ title: String, help: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.callout.weight(.semibold))
            content().pickerStyle(.radioGroup).labelsHidden()
        }
        .help(help)
    }

    private func switchPicker(_ selection: Binding<ConverterSettings.Switch>, off: String, on: String) -> some View {
        Picker("", selection: selection) {
            Text(L("現状維持")).tag(ConverterSettings.Switch.keep)
            Text(off).tag(ConverterSettings.Switch.off)
            Text(on).tag(ConverterSettings.Switch.on)
        }
    }
}

/// 変更内容の確認：項目ごとにオン・オフ。未インストールのものは変えない
private struct ConverterConfirmList: View {
    @ObservedObject var model: FontConverterModel
    let changes: [FontConverterRules.Change]

    var body: some View {
        let direct = changes.filter { if case .direct = $0 { return true } else { return false } }
        let nearest = changes.filter { if case .nearestWeight = $0 { return true } else { return false } }
        let missing = changes.filter { if case .missing = $0 { return true } else { return false } }
        VStack(alignment: .leading, spacing: 10) {
            Text(L("変更内容の確認")).font(.headline)
            List {
                if !direct.isEmpty {
                    Section(L("以下のフォントを変更します。")) { ForEach(direct, id: \.self) { row($0, selectable: true) } }
                }
                if !nearest.isEmpty {
                    Section(L("同じウェイトのフォントが見つかりません。近いウェイトに置換します。")) {
                        ForEach(nearest, id: \.self) { row($0, selectable: true) }
                    }
                }
                if !missing.isEmpty {
                    Section(L("次のフォントはインストールされていないため変更されません。")) {
                        ForEach(missing, id: \.self) { row($0, selectable: false) }
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            HStack {
                Button(L("戻る")) { model.phase = .settings }
                Spacer()
                Button(L("キャンセル")) { FontConverterWindow.shared.close() }.keyboardShortcut(.cancelAction)
                Button(L("実行")) { model.apply(changes) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.chosen.isEmpty)
            }
        }
        .padding(20)
    }

    private func row(_ change: FontConverterRules.Change, selectable: Bool) -> some View {
        HStack(spacing: 8) {
            if selectable {
                Toggle("", isOn: Binding(get: { model.chosen.contains(change.old) },
                                         set: { if $0 { model.chosen.insert(change.old) } else { model.chosen.remove(change.old) } }))
                    .labelsHidden()
            }
            Text(verbatim: change.old).textSelection(.enabled)
            Image(systemName: "arrow.right").foregroundStyle(.secondary).accessibilityLabel(L("から"))
            Text(verbatim: change.new).textSelection(.enabled)
                .foregroundStyle(selectable ? .primary : .secondary)
            if case .nearestWeight(_, _, let oldWeight, let newWeight) = change {
                Text(verbatim: "（\(oldWeight) → \(newWeight)）").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
