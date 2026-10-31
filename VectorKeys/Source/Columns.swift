import AppKit
import SwiftUI

/// Three action columns or four component columns, with independent local widths.
struct ResizableColumns: NSViewRepresentable {
    let groups: AnyView?
    let categories: AnyView
    let scripts: AnyView
    let detail: AnyView
    init(groups: AnyView? = nil, categories: AnyView, scripts: AnyView, detail: AnyView) {
        self.groups = groups; self.categories = categories; self.scripts = scripts; self.detail = detail
    }
    private var contents: [AnyView] { (groups.map { [$0] } ?? []) + [categories, scripts, detail] }
    func makeCoordinator() -> Coordinator { Coordinator(four: groups != nil) }
    func makeNSView(context: Context) -> NSSplitView {
        let split = NSSplitView(frame: NSRect(x: 0, y: 0, width: 1020, height: 500))
        split.isVertical = true; split.dividerStyle = .thin; split.delegate = context.coordinator
        let coordinator = context.coordinator
        coordinator.views = contents.map { NSHostingView(rootView: $0) }
        for view in coordinator.views { view.sizingOptions = []; split.addArrangedSubview(view) }
        coordinator.layout(split, preferred: UserDefaults.standard.array(forKey: coordinator.key) as? [Double])
        coordinator.ready = true
        return split
    }
    func updateNSView(_ split: NSSplitView, context: Context) {
        for (view, content) in zip(context.coordinator.views, contents) { view.rootView = content }
    }
    final class Coordinator: NSObject, NSSplitViewDelegate {
        let minimums: [CGFloat]
        let defaults: [Double]
        let key: String
        var views: [NSHostingView<AnyView>] = []
        var ready = false
        init(four: Bool) {
            minimums = four ? [120, 120, 200, 380] : [130, 220, 450]
            defaults = four ? [140, 140, 260] : [154, 286]
            key = four ? "componentColumnWidths" : "mainColumnWidths"
        }
        func layout(_ split: NSSplitView, preferred: [Double]? = nil) {
            let count = minimums.count
            guard split.subviews.count == count else { return }
            var remaining = split.bounds.width - CGFloat(count - 1) * split.dividerThickness
            guard remaining >= minimums.reduce(0, +) else { return }
            var x: CGFloat = 0
            for i in 0..<count {
                let requested: CGFloat
                if let preferred, preferred.indices.contains(i) { requested = CGFloat(preferred[i]) }
                else if ready { requested = split.subviews[i].frame.width }
                else { requested = i < defaults.count ? CGFloat(defaults[i]) : remaining }
                let reserved = minimums.dropFirst(i + 1).reduce(0, +)
                let width = i == count - 1 ? remaining : max(minimums[i], min(requested, remaining - reserved))
                split.subviews[i].frame = NSRect(x: x, y: 0, width: width, height: split.bounds.height)
                x += width + split.dividerThickness; remaining -= width
            }
        }
        func splitView(_ split: NSSplitView, constrainMinCoordinate proposed: CGFloat, ofSubviewAt index: Int) -> CGFloat {
            split.subviews.prefix(index).reduce(0) { $0 + $1.frame.width + split.dividerThickness } + minimums[index]
        }
        func splitView(_ split: NSSplitView, constrainMaxCoordinate proposed: CGFloat, ofSubviewAt index: Int) -> CGFloat {
            split.bounds.width - minimums.dropFirst(index + 1).reduce(0, +) - CGFloat(minimums.count - index - 1) * split.dividerThickness
        }
        func splitView(_ split: NSSplitView, canCollapseSubview subview: NSView) -> Bool { false }
        func splitView(_ split: NSSplitView, resizeSubviewsWithOldSize oldSize: NSSize) { layout(split) }
        func splitViewDidResizeSubviews(_ note: Notification) {
            guard ready, let split = note.object as? NSSplitView else { return }
            UserDefaults.standard.set(split.subviews.dropLast().map { Double($0.frame.width) }, forKey: key)
        }
    }
}
