import AppKit
import SwiftUI

/// 時間のかかる処理（ライブラリの再構築・フォントキャッシュの消去・追加など）の進み具合。
/// メインウインドウを閉じていても分かるよう小さなパネルに出し、メインウインドウの下の欄にも棒を出す
@MainActor
final class TaskProgress: ObservableObject {
    static let shared = TaskProgress()

    @Published private(set) var isRunning = false
    @Published private(set) var title = ""
    @Published private(set) var detail = ""
    /// 0〜1。件数が分からない段階は nil（動き続ける棒）
    @Published private(set) var fraction: Double?
    private var panel: NSPanel?

    func begin(_ title: String, detail: String = "") {
        self.title = title
        self.detail = detail
        fraction = nil
        isRunning = true
        showPanel()
    }

    /// 件数が分かる段階：done／total を棒と「n／m」で出す
    func update(_ done: Int, of total: Int, detail: String? = nil) {
        fraction = total > 0 ? min(1, Double(done) / Double(total)) : nil
        self.detail = detail ?? L("%d／%d", done, total)
    }

    /// 件数が分からない段階に戻す
    func step(_ detail: String) {
        fraction = nil
        self.detail = detail
    }

    func end() {
        isRunning = false
        panel?.orderOut(nil)
    }

    private func showPanel() {
        if panel == nil {
            let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 380, height: 96),
                                styleMask: [.titled, .utilityWindow], backing: .buffered, defer: false)
            panel.isReleasedWhenClosed = false
            panel.hidesOnDeactivate = false
            panel.level = .floating
            panel.contentView = NSHostingView(rootView: TaskProgressView())
            self.panel = panel
        }
        panel?.title = title
        panel?.center()
        panel?.orderFront(nil)
    }
}

private struct TaskProgressView: View {
    @ObservedObject private var progress = TaskProgress.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(progress.title).font(.headline)
            if let fraction = progress.fraction {
                ProgressView(value: fraction)
            } else {
                ProgressView().progressViewStyle(.linear)
            }
            Text(progress.detail).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                .monospacedDigit()
        }
        .padding(16)
        .frame(width: 380)
    }
}

/// メインウインドウの下の欄に出す細い棒
struct TaskProgressBar: View {
    @ObservedObject private var progress = TaskProgress.shared

    var body: some View {
        if progress.isRunning {
            Group {
                if let fraction = progress.fraction {
                    ProgressView(value: fraction)
                } else {
                    ProgressView().progressViewStyle(.linear)
                }
            }
            .frame(width: 140)
            .help(progress.title)
        }
    }
}
