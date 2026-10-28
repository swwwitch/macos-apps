import AppKit
import SwiftUI

/// Native draggable dividers. Widths are local to this Mac, independent of the script library.
struct ResizableColumns: NSViewRepresentable {
    let categories: AnyView
    let scripts: AnyView
    let detail: AnyView
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSSplitView {
        let split = NSSplitView(frame: NSRect(x: 0, y: 0, width: 1020, height: 500))
        split.isVertical = true
        split.dividerStyle = .thin
        split.delegate = context.coordinator
        let views = [categories, scripts, detail].map { NSHostingView(rootView: $0) }
        context.coordinator.views = views
        for view in views {
            view.sizingOptions = []
            split.addArrangedSubview(view)
        }
        split.adjustSubviews()
        let saved = UserDefaults.standard.array(forKey: Coordinator.key) as? [Double]
        let first = max(130, min(saved?.first ?? 154, split.bounds.width - 582))
        let second = max(220, min(saved?.dropFirst().first ?? 286, split.bounds.width - first - 362))
        split.setPosition(first, ofDividerAt: 0)
        split.setPosition(first + split.dividerThickness + second, ofDividerAt: 1)
        context.coordinator.initialWidths = [first, second]
        context.coordinator.ready = true
        return split
    }
    func updateNSView(_ split: NSSplitView, context: Context) {
        for (view, content) in zip(context.coordinator.views, [categories, scripts, detail]) { view.rootView = content }
    }
    final class Coordinator: NSObject, NSSplitViewDelegate {
        static let key = "mainColumnWidths"
        var views: [NSHostingView<AnyView>] = []
        var ready = false
        var initialWidths: [CGFloat]?
        func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
            dividerIndex == 0 ? 130 : splitView.subviews[0].frame.width + splitView.dividerThickness + 220
        }
        func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
            let remaining: CGFloat = dividerIndex == 0 ? 220 + 360 + splitView.dividerThickness * 2 : 360 + splitView.dividerThickness
            return max(130, splitView.bounds.width - remaining)
        }
        func splitView(_ splitView: NSSplitView, canCollapseSubview subview: NSView) -> Bool { false }
        func splitView(_ splitView: NSSplitView, resizeSubviewsWithOldSize oldSize: NSSize) {
            guard splitView.subviews.count == 3 else { return }
            let usable = splitView.bounds.width - splitView.dividerThickness * 2
            guard usable >= 710 else { return }
            let restore = ready ? initialWidths : nil
            let first = max(130, min(restore?.first ?? splitView.subviews[0].frame.width, usable - 580))
            let second = max(220, min(restore?.last ?? splitView.subviews[1].frame.width, usable - first - 360))
            if ready { initialWidths = nil }
            var x: CGFloat = 0
            for (view, width) in zip(splitView.subviews, [first, second, max(360, usable - first - second)]) {
                view.frame = NSRect(x: x, y: 0, width: width, height: splitView.bounds.height)
                x += width + splitView.dividerThickness
            }
        }
        func splitViewDidResizeSubviews(_ notification: Notification) {
            guard ready, initialWidths == nil, let split = notification.object as? NSSplitView, split.subviews.count == 3 else { return }
            UserDefaults.standard.set(split.subviews.prefix(2).map { Double($0.frame.width) }, forKey: Self.key)
        }
    }
}
