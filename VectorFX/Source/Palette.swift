import AppKit
import SwiftUI

/// Clicking a button must leave Illustrator in front with its selection.
final class PalettePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// The floating palette. Shown only while Illustrator is in front; the request survives switching apps.
@MainActor final class PaletteController {
    private let model: Model
    private var panel: PalettePanel?
    private var workspaceObserver: NSObjectProtocol?
    private var closeObserver: NSObjectProtocol?

    init(model: Model) {
        self.model = model
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateVisibility() }
        }
    }
    var isRequested: Bool { model.paletteRequested }

    func toggle() { model.paletteRequested ? hide() : show() }
    func show() {
        makePanelIfNeeded()
        model.paletteRequested = true
        updateVisibility()
        if Illustrator.front == nil { model.report(L("palette.waiting"), error: false) }
    }
    func hide() {
        model.paletteRequested = false
        panel?.orderOut(nil)
    }
    func updateVisibility() {
        model.updateRegistrations()
        guard let panel else { return }
        if model.paletteRequested && Illustrator.front != nil { panel.orderFrontRegardless() } else { panel.orderOut(nil) }
    }

    private func makePanelIfNeeded() {
        guard panel == nil else { return }
        let panel = PalettePanel(contentRect: NSRect(x: 0, y: 0, width: 250, height: 560),
                                 styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = L("palette.title")
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.minSize = NSSize(width: 200, height: 160)
        panel.contentView = NSHostingView(rootView: PaletteView(model: model))
        panel.center()
        _ = panel.setFrameUsingName("VectorFX.Palette")
        panel.setFrameAutosaveName("VectorFX.Palette")
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(panel.frame) }) { panel.center() }
        // The close button ends the request like the toggle key does.
        closeObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: panel, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.model.paletteRequested = false }
        }
        self.panel = panel
    }
}

struct PaletteView: View {
    @ObservedObject var model: Model
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    let visible = model.visibleCommands
                    if visible.isEmpty {
                        Text(L("palette.empty")).font(.callout).foregroundColor(.secondary).frame(maxWidth: .infinity, minHeight: 80)
                    }
                    ForEach(PaletteSection.allCases, id: \.self) { section in
                        let commands = visible.filter { $0.section == section }
                        if !commands.isEmpty {
                            Text(section.title).font(.caption.weight(.semibold)).foregroundColor(.secondary)
                                .padding(.top, 8).padding(.horizontal, 4)
                            ForEach(commands, id: \.id) { command in PaletteButton(model: model, command: command) }
                        }
                    }
                }.padding(8)
            }
            if let status = model.status {
                Divider()
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: status.isError ? "exclamationmark.triangle.fill" : "checkmark.circle").accessibilityHidden(true)
                    Text(status.text).lineLimit(3).frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.caption).foregroundColor(status.isError ? .orange : .secondary)
                .padding(8).help(status.text)
            }
        }
        .background(Color(nsColor: AppSurface.color)).tint(appTint)
    }
}

struct PaletteButton: View {
    @ObservedObject var model: Model
    let command: Command
    @State private var hovering = false
    private var background: Color {
        if let tag = model.color(command) { return tag.displayColor.opacity(hovering ? 0.38 : 0.24) }
        return hovering ? appTint.opacity(0.16) : Color(nsColor: .controlBackgroundColor)
    }
    var body: some View {
        let available = model.scriptExists(command)
        Button {
            // Option opens Illustrator's own dialog box for the effects applied with values.
            let dialog = command.dialogAlternative != nil && NSEvent.modifierFlags.contains(.option)
            model.run(command, dialog: dialog)
        } label: {
            HStack(spacing: 6) {
                Text(command.displayTitle).lineLimit(1).truncationMode(.tail)
                Spacer(minLength: 4)
                if !available { Image(systemName: "exclamationmark.triangle").foregroundColor(.orange).accessibilityLabel(L("script.missing")) }
                if let combo = model.keys[command.id] {
                    Text(combo.label).font(.system(size: 11, design: .monospaced))
                        .foregroundColor(model.failedKeys.contains(command.id) ? .orange : .secondary)
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 5).fill(background))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .disabled(!available)
        .onHover { hovering = $0 }
        .help(command.dialogAlternative != nil ? L("palette.optionHint") : (available ? command.displayTitle : L("script.missing")))
        .accessibilityLabel(command.displayTitle)
    }
}
