import AppKit
import SwiftUI

/// Native tabs, matching SettingsTabs. No offset keyboard-focus ring on the selected tab.
struct MainTabs: NSViewRepresentable {
    @Binding var selection: Int
    var storesSelection = false
    let sections: [(String, AnyView)]
    init(sections: [(String, AnyView)], selection: Binding<Int>, storesSelection: Bool = false) {
        self.sections = sections; _selection = selection; self.storesSelection = storesSelection
    }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    final class Coordinator: NSObject, NSTabViewDelegate {
        var parent: MainTabs
        init(_ parent: MainTabs) { self.parent = parent }
        func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
            guard let item = tabViewItem else { return }
            let index = tabView.indexOfTabViewItem(item)
            if parent.selection != index { parent.selection = index }
            if parent.storesSelection { UserDefaults.standard.set(index, forKey: "shared.settings.selectedTabIndex") }
        }
    }
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
        if sections.indices.contains(selection) { tabs.selectTabViewItem(at: selection) }
        tabs.delegate = context.coordinator
        return tabs
    }
    func updateNSView(_ tabs: NSTabView, context: Context) {
        context.coordinator.parent = self
        if sections.indices.contains(selection), tabs.selectedTabViewItem != tabs.tabViewItem(at: selection) { tabs.selectTabViewItem(at: selection) }
        for (index, section) in sections.enumerated() where index < tabs.numberOfTabViewItems {
            let item = tabs.tabViewItem(at: index)
            item.label = section.0
            (item.view as? NSHostingView<AnyView>)?.rootView = section.1
        }
    }
}
