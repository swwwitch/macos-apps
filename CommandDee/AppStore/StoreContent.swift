import SwiftUI
import AppKit
var storeTitle: String { S("ファイルを複製・整理する", "Duplicate and organize files", "复制并整理文件", "파일 복제 및 정리") }
var storeDetail: String { S("フォルダーを選択し、対象ファイルを指定します。", "Choose a folder, then select files.", "选择文件夹，然后选择文件。", "폴더를 선택한 다음 파일을 선택하세요.") }
@MainActor final class FileModel: ObservableObject {
    @Published var folder: URL?
    @Published var files: [URL] = []
    @Published var selected = Set<URL>()
    @Published var status = ""
    @Published var busy = false
    @Published var mode = 0
    private var scoped = false
    func choose() {
        let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if scoped, let folder { folder.stopAccessingSecurityScopedResource() }
        folder = url; scoped = url.startAccessingSecurityScopedResource(); reload()
    }
    func reload() {
        guard let folder else { return }
        do { files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]).sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }; selected = [] }
        catch { status = error.localizedDescription }
    }
    func execute() {
        let targets = files.filter { selected.contains($0) }
        guard !busy, !targets.isEmpty else { return }
        if mode == 5 && targets.count != 2 { status = S("入れ替えは2項目を選択してください。", "Select exactly two items to swap.", "请选择两个项目交换名称。", "이름을 바꿀 두 항목을 선택하세요."); return }
        if mode >= 3 {
            let alert = NSAlert(); alert.messageText = S("名前を変更しますか？", "Rename these items?", "更改名称？", "이름을 변경할까요?")
            alert.informativeText = targets.map(\.lastPathComponent).joined(separator: "\n") + "\n" + S("取り消しはできません。", "Undo is unavailable.", "无法撤销。", "실행 취소할 수 없습니다.")
            alert.addButton(withTitle: S("変更", "Rename", "更改", "변경")); alert.addButton(withTitle: S("キャンセル", "Cancel", "取消", "취소"))
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        busy = true; StoreDelegate.shared.processing = true
        let action = mode
        DispatchQueue.global(qos: .userInitiated).async {
            var results: [String] = []
            if action == 5 {
                do { results = try Duplicator.swapNames(targets).map(\.lastPathComponent) } catch { results = [error.localizedDescription] }
            } else {
                for source in targets {
                    do {
                        let result: URL
                        switch action {
                        case 1: result = try Duplicator.duplicateDated(source)
                        case 2: result = try Duplicator.duplicateDated(source, edited: true)
                        case 3: result = try Duplicator.renameVersion(source)
                        case 4: result = try Duplicator.renameParentToggled(source)
                        default: result = try Duplicator.duplicate(source)
                        }
                        results.append("✓ " + result.lastPathComponent)
                    } catch { results.append(source.lastPathComponent + ": " + error.localizedDescription) }
                }
            }
            let report = results.joined(separator: "\n")
            DispatchQueue.main.async { self.busy = false; StoreDelegate.shared.processing = false; self.reload(); self.status = report }
        }
    }
}
struct StoreContent: View {
    @StateObject private var model = FileModel()
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Button(S("フォルダーを選択…", "Choose Folder…", "选择文件夹…", "폴더 선택…")) { model.choose() }; Text(model.folder?.path ?? "").lineLimit(1) }.disabled(model.busy)
            Picker(S("処理", "Operation", "操作", "작업"), selection: $model.mode) {
                Text(S("連番で複製", "Duplicate with Version", "按版本复制", "버전 번호로 복제")).tag(0)
                Text(S("日付で複製", "Duplicate with Date", "按日期复制", "날짜로 복제")).tag(1)
                Text(S("編集用に複製", "Duplicate for Editing", "复制用于编辑", "편집용 복제")).tag(2)
                Text(S("連番へ名前変更", "Rename with Version", "版本重命名", "버전 번호로 이름 변경")).tag(3)
                Text(S("親フォルダー名を切替", "Toggle Parent Folder Name", "切换父文件夹名称", "상위 폴더 이름 전환")).tag(4)
                Text(S("2項目の名前を入替", "Swap Two Names", "交换两个名称", "두 이름 맞바꾸기")).tag(5)
            }.disabled(model.busy)
            List(model.files, id: \.self, selection: $model.selected) { Text($0.lastPathComponent) }.disabled(model.busy)
            HStack { Button(S("実行", "Run", "执行", "실행")) { model.execute() }.disabled(model.busy || model.selected.isEmpty); if model.busy { ProgressView().controlSize(.small) } }
            ScrollView { Text(model.status).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(height: 100)
        }
    }
}
