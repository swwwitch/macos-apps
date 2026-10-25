import AppKit
import SwiftUI

/// A small floating panel near the top right of the screen with the pointer. It never takes focus
/// from the app being used, so typing continues there; its buttons still accept clicks.
@MainActor final class NoticePanel {
    private var panel: NSPanel?
    private var closeWork: DispatchWorkItem?

    func show<Content: View>(seconds: Double?, @ViewBuilder content: () -> Content) {
        close()
        let host = NSHostingView(rootView: content()
            .padding(14)
            .frame(width: 360, alignment: .leading)
            .background(VisualEffect())
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.12))))
        let size = host.fittingSize
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
        panel.isFloatingPanel = true; panel.level = .statusBar; panel.hidesOnDeactivate = false
        panel.backgroundColor = .clear; panel.isOpaque = false; panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = host
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: frame.maxX - size.width - 16, y: frame.maxY - size.height - 16))
        }
        panel.orderFrontRegardless()
        self.panel = panel
        if let seconds {
            let work = DispatchWorkItem { [weak self] in self?.close() }
            closeWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
        }
    }
    func close() {
        closeWork?.cancel(); closeWork = nil
        panel?.orderOut(nil); panel = nil
    }
}

struct VisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView(); view.material = .popover; view.state = .active; view.blendingMode = .behindWindow
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

struct RewriteNotice: View {
    let rules: [String]
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(String(format: L("notice.rewritten"), rules.joined(separator: L("listSeparator"))), systemImage: "wand.and.stars")
                .font(.headline).foregroundColor(appTint)
            Text(text).font(.callout).lineLimit(6).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
        }
        .accessibilityElement(children: .combine)
    }
}

struct DropboxNotice: View {
    let item: (name: String, isFolder: Bool)?
    let direct: () -> Void
    let dismiss: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L("dropbox.ready"), systemImage: "link").font(.headline).foregroundColor(appTint)
            if let item {
                Text(String(format: L(item.isFolder ? "dropbox.folder" : "dropbox.file"), item.name)).font(.callout).lineLimit(2)
            }
            Text(L("dropbox.detail")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button(L("dropbox.direct"), action: direct)
                Button(L("ok"), action: dismiss).keyboardShortcut(.defaultAction)
            }
        }
    }
}
