import AppKit
import Carbon
import Combine

/// 照合元の読み込み・キーの記録・照合結果
@MainActor
final class HotkeyStore: ObservableObject {
    static let shared = HotkeyStore()

    /// 照合する範囲：すべてのアプリ／指定したアプリで効くものだけ
    enum Target: String { case allApps, specified }

    /// 照合の対象に指定したアプリ
    struct ChosenApp: Equatable {
        let bundleID: String
        let name: String
        init(bundleID: String, name: String? = nil) {
            self.bundleID = bundleID
            self.name = name ?? HotkeyScanners.appName(bundleID: bundleID)
        }
        init?(_ app: NSRunningApplication?) {
            guard let app, let id = app.bundleIdentifier else { return nil }
            self.init(bundleID: id, name: app.localizedName)
        }
    }

    @Published private(set) var target: Target = Target(rawValue: UserDefaults.standard.string(forKey: "lookup.target") ?? "") ?? .allApps {
        didSet { UserDefaults.standard.set(target.rawValue, forKey: "lookup.target") }
    }
    @Published var chosenApp: ChosenApp? = UserDefaults.standard.string(forKey: "lookup.app").map { ChosenApp(bundleID: $0) } {
        didSet { UserDefaults.standard.set(chosenApp?.bundleID, forKey: "lookup.app") }
    }
    /// 最後に前面にあったほかのアプリ（「アプリを指定」に切り替えたときの初期値）
    private var frontmostApp: NSRunningApplication?
    @Published var combo: KeyCombo?
    @Published var isRecording = false
    @Published var isLoading = false
    /// 照合元ごとに読み込んだもの（メニューは起動中のアプリぶん）
    @Published private(set) var entries: [HotkeySource: [HotkeyEntry]] = [:]
    @Published private(set) var loadedAt: Date?
    @Published private(set) var reserved = false
    @Published private(set) var interceptors: [InterceptorInfo] = []
    @Published var message: String?
    /// 設定の読み込み・同期で照合元が書き換わったら増える（設定画面の一覧を作り直す）
    @Published private(set) var settingsRevision = 0

    private var loadTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []

    init() {
        let center = NSWorkspace.shared.notificationCenter
        let me = ProcessInfo.processInfo.processIdentifier
        if let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != me { frontmostApp = front }
        observers.append(center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated {
                guard let app, app.processIdentifier != me, app.activationPolicy == .regular else { return }
                HotkeyStore.shared.frontmostApp = app
            }
        })
        // 記録中にほかのアプリへ移ったら記録をやめる（キーを止め続けない）
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { HotkeyStore.shared.cancelRecording() }
        })
        // アプリの起動・終了でメニューの結果は古くなる
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { HotkeyStore.shared.menusAreStale = true }
            })
        }
        observers.append(DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String), object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { KeyNames.prepare() }
        })
    }

    private var menusAreStale = true
    /// ［読み直す］を押した後か（以後この起動中はほかのアプリのコンテナも読む。フルディスクアクセスがあれば最初から読む）
    private var readsContainers = false

    var activeSources: [HotkeySource] { HotkeySource.ordered.filter(\.isIncluded) }

    // MARK: 読み込み

    /// すべての照合元を読み直す（includeContainers：［読み直す］から呼ぶときに true）
    func reload(includeContainers: Bool = false) {
        if includeContainers { readsContainers = true }
        let containers = readsContainers || HotkeyScanners.hasFullDiskAccess
        loadTask?.cancel()
        KeyNames.prepare()
        isLoading = true
        message = nil
        let sources = activeSources
        let targets = sources.contains(.menus) ? menuTargets() : []
        loadTask = Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) { () -> [HotkeySource: [HotkeyEntry]] in
                var collected: [HotkeySource: [HotkeyEntry]] = [:]
                for source in sources where source != .menus { collected[source] = HotkeyScanners.scan(source, containers: containers) }
                if !targets.isEmpty { collected[.menus] = Self.scanMenus(targets) }
                return collected
            }.value
            guard let self, !Task.isCancelled else { return }
            self.entries = result
            self.loadedAt = Date()
            self.menusAreStale = false
            self.isLoading = false
            self.refreshLiveState()
        }
    }

    /// 前回の読み込みが古ければ読み直す（記録のたびに呼ぶ）
    /// 設定の共有（読み込み・同期）で UserDefaults が書き換わった後に、照合元と結果を読み直す
    func settingsImported() {
        CustomSources.invalidate()
        settingsRevision += 1
        reload()
    }

    func reloadIfNeeded() {
        if loadedAt == nil || menusAreStale || Date().timeIntervalSince(loadedAt ?? .distantPast) > 30 { reload() } else { refreshLiveState() }
    }

    /// メニューを読む対象（通常のアプリ。このアプリ自身は除く）
    private func menuTargets() -> [MenuHotkeys.Target] {
        let me = ProcessInfo.processInfo.processIdentifier
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.processIdentifier != me && !$0.isTerminated }
            .map { MenuHotkeys.Target(pid: $0.processIdentifier, name: $0.localizedName ?? $0.bundleIdentifier ?? "?", bundleID: $0.bundleIdentifier) }
    }

    nonisolated private static func scanMenus(_ targets: [MenuHotkeys.Target]) -> [HotkeyEntry] {
        let lock = NSLock()
        var all: [HotkeyEntry] = []
        DispatchQueue.concurrentPerform(iterations: targets.count) { index in
            let found = MenuHotkeys.scan(targets[index])
            lock.lock(); all += found; lock.unlock()
        }
        return all
    }

    /// システムの専有・イベントタップは毎回その場で調べる
    private func refreshLiveState() {
        interceptors = EventTapProbe.interceptors()
        if let combo { reserved = ExclusiveHotkeyProbe.isReserved(combo) } else { reserved = false }
    }

    // MARK: 記録

    func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        message = nil
        KeyRecorder.shared.start { [weak self] combo in
            guard let self else { return }
            self.isRecording = false
            guard let combo else { return }
            self.combo = combo
            self.reloadIfNeeded()
        }
    }

    func cancelRecording() {
        guard isRecording else { return }
        KeyRecorder.shared.cancel()
        isRecording = false
    }

    // MARK: 結果

    var allEntries: [HotkeyEntry] {
        activeSources.flatMap { entries[$0] ?? [] }
    }

    /// 記録したキーに一致するもの。有効・動作中のものを先に
    var matches: [HotkeyEntry] {
        guard let combo else { return [] }
        return sorted(allEntries.filter { $0.matches(combo) && inTarget($0) })
    }

    /// 「アプリを指定」に切り替えるときは、直前に使っていたアプリを選んでおく
    func selectTarget(_ newValue: Target) {
        if newValue == .specified && target != .specified, let app = ChosenApp(frontmostApp) { chosenApp = app }
        target = newValue
    }

    /// 照合する範囲に入るか。アプリを指定したときは、そのアプリのメニューと、そのアプリで効くものだけ
    private func inTarget(_ entry: HotkeyEntry) -> Bool {
        guard target == .specified, let app = chosenApp else { return true }
        if entry.source == .menus { return entry.ownerBundleID == app.bundleID }
        return entry.apps.applies(to: app.bundleID)
    }

    /// 定義元が動いていて、設定でも有効か
    func isEffective(_ entry: HotkeyEntry) -> Bool {
        entry.isEnabled && (entry.isRunning ?? true)
    }

    private func sorted(_ list: [HotkeyEntry]) -> [HotkeyEntry] {
        let order = Dictionary(uniqueKeysWithValues: HotkeySource.ordered.enumerated().map { ($1, $0) })
        return list.sorted {
            let left = (isEffective($0) ? 0 : 1, order[$0.source] ?? 0, $0.combo.display, $0.title)
            let right = (isEffective($1) ? 0 : 1, order[$1.source] ?? 0, $1.combo.display, $1.title)
            return left < right
        }
    }

    func count(for source: HotkeySource) -> Int { entries[source]?.count ?? 0 }
}
