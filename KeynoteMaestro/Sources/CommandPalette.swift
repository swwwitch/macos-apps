import AppKit
import SwiftUI
import Combine

/// Mouse clicks must never activate this panel or replace Keynote's selection.
final class CommandPalettePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor final class CommandPalette: NSObject, NSWindowDelegate {
    private let panel: CommandPalettePanel
    private let model: Model
    private var observation: AnyCancellable?
    private var workspaceObserver: NSObjectProtocol?
    private var requestedVisible = false
    private static let width: CGFloat = 230
    init(model: Model) {
        self.model = model
        let hasSavedFrame = UserDefaults.standard.string(forKey: "NSWindow Frame CommandPalette") != nil
        panel = CommandPalettePanel(contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 400),
            styleMask: [.titled, .closable, .utilityWindow, .nonactivatingPanel], backing: .buffered, defer: false)
        super.init()
        panel.delegate = self
        panel.title = L("palette.title")
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let host = NSHostingView(rootView: ScrollView { CommandPaletteView(model: model) })
        host.sizingOptions = []
        panel.contentView = host
        panel.setFrameAutosaveName("CommandPalette")
        resizeToFit()
        if !hasSavedFrame { panel.center() }
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateVisibility() }
        }
        observation = model.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.resizeToFit() }
        }
    }
    private func resizeToFit() {
        let top = panel.frame.maxY
        let measured = NSHostingController(rootView: CommandPaletteView(model: model))
            .sizeThatFits(in: NSSize(width: Self.width, height: 10_000))
        let screen = NSScreen.screens.first { $0.visibleFrame.intersects(panel.frame) } ?? NSScreen.main
        let available = max(160, (screen?.visibleFrame.height ?? 800) - 80)
        // Keep the requested narrow width even when an older, wider frame was saved.
        panel.setContentSize(NSSize(width: Self.width, height: min(available, max(100, ceil(measured.height)))))
        var origin = NSPoint(x: panel.frame.minX, y: top - panel.frame.height)
        if let bounds = screen?.visibleFrame {
            origin.x = max(bounds.minX, min(origin.x, bounds.maxX - panel.frame.width))
            origin.y = max(bounds.minY, min(origin.y, bounds.maxY - panel.frame.height))
        }
        panel.setFrameOrigin(origin)
    }
    func windowWillClose(_ notification: Notification) { requestedVisible = false }
    private func updateVisibility() {
        if requestedVisible && KeynoteHotkeyScope.permits(NSWorkspace.shared.frontmostApplication?.bundleIdentifier) {
            resizeToFit()
            panel.orderFrontRegardless()
        } else { panel.orderOut(nil) }
    }
    func show() {
        requestedVisible = true
        resizeToFit()
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(panel.frame) }) { panel.center() }
        updateVisibility()
    }
}

private struct CommandPaletteView: View {
    @ObservedObject var model: Model
    var body: some View {
        let groups = model.paletteVisibility.groups
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(groups) { group in
                if group.dividerBefore { Divider().padding(.vertical, 3) }
                if let headingKey = group.headingKey {
                    Text(L(headingKey)).font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
                        .padding(.top, group.id == 2 ? 4 : 0).accessibilityAddTraits(.isHeader)
                }
                ForEach(group.commands, id: \.self) { command in
                    Button { model.runPaletteCommand(command) } label: {
                        Text(L("palette.button." + command.rawValue))
                            .font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }.buttonStyle(.bordered).controlSize(.regular)
                        .help(L("command." + command.rawValue))
                        .accessibilityLabel(L("command." + command.rawValue))
                        .disabled(model.paletteBusy || !model.paletteTargetAvailable || model.paused)
                }
            }
            if groups.isEmpty {
                Text(L("palette.empty")).font(.caption).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Divider().padding(.top, 3)
                Text(model.paletteTargetAvailable ? model.status : L("palette.target"))
                    .font(.caption).foregroundColor(model.statusIsError ? .red : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(L("palette.settings")) { (NSApp.delegate as? AppDelegate)?.showPreferences(tab: 3) }
                .controlSize(.small)
        }.padding(12).frame(maxWidth: .infinity, alignment: .topLeading)
            .background(Color(nsColor: AppSurface.color))
    }
}

struct PaletteSettingsView: View {
    @ObservedObject var model: Model
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsSection(L("palette.showHotkey")) {
                HotkeyField(id: PaletteDisplayHotkey.fieldID,
                            combo: Binding(get: { model.paletteDisplayHotkey.combo }, set: { model.setPaletteDisplayHotkey($0) }),
                            allowsClear: true, others: model.otherPaletteHotkeys, registered: !model.paletteDisplayFailed)
                Text(L("palette.showHotkeyHint")).font(.caption).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            SettingsSection(L("palette.tab")) {
                Text(L("palette.visibilityHint")).font(.caption).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button(L("palette.showAll")) { model.setAllPaletteVisible(true) }
                    Button(L("palette.hideAll")) { model.setAllPaletteVisible(false) }
                }.controlSize(.small)
            }
            ForEach(PaletteCommands.groups.indices, id: \.self) { index in
                SettingsSection(L(PaletteCommands.settingsHeadingKeys[index])) {
                    ForEach(PaletteCommands.groups[index], id: \.self) { command in
                        Toggle(L("palette." + command.rawValue), isOn: Binding(
                            get: { model.paletteVisibility.includes(command) },
                            set: { model.setPaletteVisible(command, $0) }))
                    }
                }
            }
        }
    }
}
