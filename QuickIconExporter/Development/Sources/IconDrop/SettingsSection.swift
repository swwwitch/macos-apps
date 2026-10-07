import AppKit
import SwiftUI

/// Settings-only shared grouping. Does not alter persisted values or actions.
enum SettingsUI {
    static var launchTitle: String { StartupWindow.text("起動・常駐", "Startup & Background", "启动与后台", "시작 및 백그라운드") }
    static var displayTitle: String { StartupWindow.text("表示", "Display", "显示", "표시") }
    static var shortcutTitle: String { StartupWindow.text("アプリを呼び出すホットキー", "Show app shortcut", "显示应用快捷键", "앱 표시 단축키") }
    @MainActor static func tabs(_ sections: [(String, NSView)], in container: NSView) {
        let tabs = NSTabView(frame: container.bounds.insetBy(dx: 12, dy: 12))
        tabs.autoresizingMask = [.width, .height]
        tabs.font = .systemFont(ofSize: 13)
        for (title, view) in sections {
            let item = NSTabViewItem(identifier: title)
            item.label = title
            let scroll = NSScrollView()
            scroll.hasVerticalScroller = true
            scroll.drawsBackground = false
            let document = SettingsDocumentView()
            document.translatesAutoresizingMaskIntoConstraints = false
            scroll.documentView = document
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor).isActive = true
            view.translatesAutoresizingMaskIntoConstraints = false
            document.addSubview(view)
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 20),
                view.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -20),
                view.topAnchor.constraint(equalTo: document.topAnchor, constant: 20),
                view.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -20)
            ])
            item.view = scroll
            tabs.addTabViewItem(item)
        }
        container.addSubview(tabs)
    }
    @MainActor static func group(_ title: String, _ views: [NSView]) -> NSBox {
        let box = NSBox()
        box.title = title
        box.titleFont = .systemFont(ofSize: 13, weight: .semibold)
        box.contentViewMargins = NSSize(width: 12, height: 12)
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        box.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: box.contentView!.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: box.contentView!.trailingAnchor),
            stack.topAnchor.constraint(equalTo: box.contentView!.topAnchor),
            stack.bottomAnchor.constraint(equalTo: box.contentView!.bottomAnchor)
        ])
        for view in views {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        return box
    }
}

private final class SettingsDocumentView: NSView {
    override var isFlipped: Bool { true }
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }
    var body: some View {
        GroupBox(label: Text(title).font(.system(size: 13, weight: .semibold))) {
            VStack(alignment: .leading, spacing: 10, content: content)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
        }
    }
}

/// Keep settings tabs inside the content area, matching MightyEdit's NSTabView.
/// SwiftUI's automatic settings toolbar can hide all labels in an overflow menu.
struct SettingsTabs: NSViewRepresentable {
    let sections: [(String, AnyView)]
    func makeNSView(context: Context) -> NSTabView {
        let tabs = NSTabView()
        tabs.font = .systemFont(ofSize: 13)
        for (title, content) in sections {
            let item = NSTabViewItem(identifier: title)
            item.label = title
            item.view = NSHostingView(rootView: page(content))
            tabs.addTabViewItem(item)
        }
        return tabs
    }
    func updateNSView(_ tabs: NSTabView, context: Context) {
        for (index, section) in sections.enumerated() where index < tabs.numberOfTabViewItems {
            let item = tabs.tabViewItem(at: index)
            item.label = section.0
            (item.view as? NSHostingView<AnyView>)?.rootView = page(section.1)
        }
    }
    private func page(_ content: AnyView) -> AnyView {
        AnyView(ScrollView {
            content.frame(maxWidth: .infinity, alignment: .leading).padding(20)
        })
    }
}
