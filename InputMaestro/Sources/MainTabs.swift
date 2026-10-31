import AppKit
import SwiftUI

/// Native tabs, matching SettingsTabs. No offset keyboard-focus ring on the selected tab.
struct MainTabs: NSViewRepresentable {
    let sections: [(String, AnyView)]
    func makeNSView(context: Context) -> NSTabView {
        let tabs = NSTabView()
        tabs.font = .systemFont(ofSize: 13)
        tabs.focusRingType = .none
        for (title, content) in sections {
            let item = NSTabViewItem(identifier: title)
            item.label = title
            item.view = NSHostingView(rootView: content)
            tabs.addTabViewItem(item)
        }
        return tabs
    }
    func updateNSView(_ tabs: NSTabView, context: Context) {
        for (index, section) in sections.enumerated() where index < tabs.numberOfTabViewItems {
            let item = tabs.tabViewItem(at: index)
            item.label = section.0
            (item.view as? NSHostingView<AnyView>)?.rootView = section.1
        }
    }
}
