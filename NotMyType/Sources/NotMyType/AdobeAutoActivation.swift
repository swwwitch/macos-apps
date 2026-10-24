import AppKit
import CoreText

/// Adobe アプリ向けの自動アクティベート（設定で選んだときだけ）。FontExplorer X Pro はアプリのプラグインで行うが、ここではプラグインを使わず、
/// Illustrator・InDesign が前面に来たときに開いているドキュメントのフォント名を問い合わせ、いま使えないフォントのうち
/// ライブラリに PostScript 名が完全に一致するファイルがあるものをアクティブにする。
/// Illustrator はドキュメントの XMP（stFnt:fontName、保存したときの一覧）、InDesign は document.fonts の status が INSTALLED でないもの。
/// 一度調べたドキュメントの答えは控え、同じ答えなら何もしない
@MainActor
final class AdobeAutoActivation {
    static let shared = AdobeAutoActivation()
    static let enabledKey = "adobeAutoActivation"

    private var observer: NSObjectProtocol?
    private var lastAnswers: [AdobeApp: String] = [:]
    private var running: Set<AdobeApp> = []

    var enabled: Bool { UserDefaults.standard.bool(forKey: Self.enabledKey) }

    func start() {
        guard observer == nil else { return }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { note in
            let id = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
            Task { @MainActor in AdobeAutoActivation.shared.applicationActivated(id) }
        }
    }

    private func applicationActivated(_ bundleID: String?) {
        guard enabled, let bundleID else { return }
        guard let app = [AdobeApp.illustrator, .indesign].first(where: { bundleID.hasPrefix($0.bundleID) }) else { return }
        check(app)
    }

    /// 開いているドキュメントのフォント名を聞き、足りないものをライブラリからアクティブにする
    func check(_ app: AdobeApp) {
        guard !running.contains(app) else { return }
        running.insert(app)
        Task {
            defer { running.remove(app) }
            guard let names = try? await IllustratorBridge.run(script(app), app: app) else { return }
            let answer = names.sorted().joined(separator: "\n")
            guard answer != lastAnswers[app] else { return }
            lastAnswers[app] = answer
            activate(names, for: app)
        }
    }

    private func activate(_ names: [String], for app: AdobeApp) {
        let store = LibraryStore.shared
        var byPostScript: [String: FontFile] = [:]
        // 同じ PostScript 名が複数あるときは、ウォッチフォルダーの順で優先のものを使う
        for file in store.byPriority(store.data.files) where FileManager.default.fileExists(atPath: file.path) {
            for face in file.faces where byPostScript[face.postScriptName] == nil { byPostScript[face.postScriptName] = file }
        }
        var targets: [FontFile] = []
        var seen = Set<UUID>()
        for name in names where !Self.isAvailable(name) {
            guard let file = byPostScript[name], !LibraryStore.isLocked(file), seen.insert(file.id).inserted else { continue }
            targets.append(file)
        }
        guard !targets.isEmpty else { return }
        store.setActive(targets, true)
        TransientMessage.show(L("%@のドキュメントのフォントを%d個アクティブにしました", app.name, targets.count))
    }

    /// いま使えるか（同じ PostScript 名のフォントが登録されているか）
    nonisolated static func isAvailable(_ postScriptName: String) -> Bool {
        let font = CTFontCreateWithName(postScriptName as CFString, 12, nil)
        return CTFontCopyPostScriptName(font) as String == postScriptName
    }

    private func script(_ app: AdobeApp) -> String {
        switch app {
        case .illustrator:
            return """
            (function () {
                var names = [], seen = {};
                for (var i = 0; i < app.documents.length; i++) {
                    var xmp = "";
                    try { xmp = app.documents[i].XMPString; } catch (e) { xmp = ""; }
                    var found = xmp.match(/<stFnt:fontName>[^<]*/g) || [];
                    for (var j = 0; j < found.length; j++) {
                        var name = found[j].substring(16);
                        if (name && !seen["_" + name]) { seen["_" + name] = true; names.push(name); }
                    }
                }
                return "OK\\n" + names.join("\\n");
            })();
            """
        case .indesign:
            return """
            (function () {
                var names = [], seen = {};
                for (var i = 0; i < app.documents.length; i++) {
                    var fonts = app.documents[i].fonts;
                    var ps = [], status = [];
                    try { ps = fonts.everyItem().postscriptName; status = fonts.everyItem().status; } catch (e) { continue; }
                    for (var j = 0; j < ps.length; j++) {
                        if (status[j] === FontStatus.INSTALLED) continue;
                        if (ps[j] && !seen["_" + ps[j]]) { seen["_" + ps[j]] = true; names.push(ps[j]); }
                    }
                }
                return "OK\\n" + names.join("\\n");
            })();
            """
        }
    }
}
