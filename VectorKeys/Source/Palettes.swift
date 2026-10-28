import AppKit
import Combine
import SwiftUI

/// Clicking a script must preserve Illustrator's text/object selection and focus.
final class CategoryPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor final class CategoryPalettes {
    private let model: AppModel
    private var panels: [String: CategoryPanel] = [:]
    private var changes: AnyCancellable?
    /// User intent survives automatic hiding when another application becomes frontmost.
    private var requested: Set<String> = []
    private var workspaceObserver: NSObjectProtocol?
    private var closeObserver: NSObjectProtocol?
    private func updateVisibility() {
        let illustratorFront = Illustrator.front != nil
        for (category, panel) in panels {
            if illustratorFront && requested.contains(category) { panel.orderFrontRegardless() }
            else { panel.orderOut(nil) }
        }
    }

    init(model: AppModel) {
        self.model = model
        model.didExecute = { [weak self] script in
            guard let self else { return }
            for (category, panel) in self.panels where self.model.library.paletteMode(category) == 2 && self.model.scripts(in: category).contains(where: { $0.id == script.id }) {
                self.requested.remove(category)
                panel.orderOut(nil)
            }
        }
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateVisibility() }
        }
        closeObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { [weak self] note in
            MainActor.assumeIsolated {
                guard let self, let panel = note.object as? CategoryPanel,
                      let category = self.panels.first(where: { $0.value === panel })?.key else { return }
                self.requested.remove(category)
            }
        }
        changes = model.$library.sink { [weak self] library in
            // Published fires before the assignment. Reconcile against the published value next turn.
            DispatchQueue.main.async { self?.reconcile(library) }
        }
    }
    deinit {
        if let workspaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver) }
        if let closeObserver { NotificationCenter.default.removeObserver(closeObserver) }
    }
    private func title(_ category: String) -> String {
        category == AppModel.allCategories ? L("category.all") :
            category == AppModel.uncategorized ? L("category.none") : category
    }
    private func valid(_ category: String, in library: Library) -> Bool {
        category == AppModel.allCategories || category == AppModel.uncategorized || library.categoryList.contains(category)
    }
    private func reconcile(_ library: Library) {
        for category in Array(panels.keys) where !valid(category, in: library) || !library.allowsPalette(category) {
            requested.remove(category)
            panels.removeValue(forKey: category)?.close()
        }
    }
    func show(_ category: String) {
        guard valid(category, in: model.library), model.library.allowsPalette(category) else { return }
        if panels[category] != nil {
            if requested.contains(category) && model.library.paletteMode(category) != 2 { requested.remove(category) }
            else { requested.insert(category) }
            updateVisibility()
            return
        }
        let panel = CategoryPanel(contentRect: NSRect(x: 0, y: 0, width: 280, height: 360),
            styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = title(category)
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.minSize = NSSize(width: 220, height: 150)
        panel.contentView = NSHostingView(rootView: CategoryPaletteView(model: model, category: category))
        let frameName = "VectorKeys.Palette." + Data(category.utf8).map { String(format: "%02x", $0) }.joined()
        panel.center()
        _ = panel.setFrameUsingName(frameName)
        panel.setFrameAutosaveName(frameName)
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(panel.frame) }) { panel.center() }
        panels[category] = panel
        requested.insert(category)
        updateVisibility()
    }
    func rename(_ old: String, to new: String) {
        guard let previous = panels.removeValue(forKey: old) else { return }
        let wasVisible = requested.remove(old) != nil
        let frame = previous.frame
        previous.close()
        if wasVisible {
            show(new)
            panels[new]?.setFrame(frame, display: true)
        }
    }
}

struct CategoryPaletteView: View {
    @ObservedObject var model: AppModel
    let category: String
    private var scripts: [ScriptEntry] { model.scripts(in: category) }
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 6) {
                    if scripts.isEmpty {
                        Text(L("palette.empty")).font(.callout).foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 80).padding(12)
                    }
                    ForEach(scripts) { script in
                        Button { model.runFromWindow(script) } label: {
                            HStack(spacing: 8) {
                                Text(script.name).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                                if let hotkey = script.hotkey {
                                    Text(hotkey.fullLabel).font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary)
                                }
                                if script.hasUnsupportedSteps || !script.isAvailable {
                                    Image(systemName: "exclamationmark.triangle").foregroundColor(.orange)
                                }
                            }
                            .padding(.horizontal, 10).padding(.vertical, 9).frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 6).fill(script.tagColor?.displayColor.opacity(0.22) ?? Color(nsColor: .controlBackgroundColor)))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).disabled(!script.enabled || !script.isAvailable)
                        .help(script.isAvailable ? L("palette.hint") : L(script.hasUnsupportedSteps ? "legacy.unsupported" : "code.unavailableHint"))
                    }
                }.padding(10)
            }
            if let record = model.records.first {
                Divider()
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: record.isError ? "exclamationmark.triangle.fill" : "checkmark.circle")
                    Text(record.name + " · " + record.text).lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.caption).foregroundColor(record.isError ? .orange : .secondary)
                .padding(10).help(record.text)
                .accessibilityLabel(record.name + " " + record.text)
            }
        }
        .background(Color(nsColor: AppSurface.color)).tint(appTint)
    }
}
