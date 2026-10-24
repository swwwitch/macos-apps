import Foundation

/// 計測用：環境変数 NOTMYTYPE_BENCH=select で起動すると、5秒後から0.3秒ごとに一覧の選択を30回切り替える。
/// 外から sample でメインスレッドの使用時間を測る（アクセシビリティで操作すると、その応答の負荷が混ざるため）
@MainActor
enum BenchMode {
    static func startIfRequested() {
        guard ProcessInfo.processInfo.environment["NOTMYTYPE_BENCH"] == "select" else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            let store = LibraryStore.shared
            store.sidebar = .all
            let ids = store.shownFamilies.prefix(60).map(\.id)
            step(ids, 0)
        }
    }

    private static func step(_ ids: [String], _ index: Int) {
        guard index < 30, index * 2 < ids.count else { return }
        LibraryStore.shared.selection = [ids[index * 2]]
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { step(ids, index + 1) }
    }
}
