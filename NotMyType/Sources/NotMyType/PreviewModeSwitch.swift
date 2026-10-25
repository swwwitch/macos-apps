import AppKit
import SwiftUI

/// Native segments sized to their localized labels, not equal-width cells.
struct PreviewModeSwitch: NSViewRepresentable {
    @Binding var showsGlyphs: Bool

    func makeCoordinator() -> Coordinator { Coordinator($showsGlyphs) }

    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl(labels: [L("プレビュー"), L("字形")],
                                         trackingMode: .selectOne,
                                         target: context.coordinator,
                                         action: #selector(Coordinator.changed(_:)))
        control.segmentStyle = .rounded
        control.segmentDistribution = .fit
        control.setAccessibilityLabel(L("プレビュー・字形"))
        updateNSView(control, context: context)
        return control
    }

    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        context.coordinator.selection = $showsGlyphs
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        control.font = font
        for (index, label) in [L("プレビュー"), L("字形")].enumerated() {
            control.setLabel(label, forSegment: index)
            let width = (label as NSString).size(withAttributes: [.font: font]).width
            control.setWidth(ceil(width) + 24, forSegment: index)
        }
        control.selectedSegment = showsGlyphs ? 1 : 0
        control.sizeToFit()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSSegmentedControl, context: Context) -> CGSize? {
        nsView.intrinsicContentSize
    }

    final class Coordinator: NSObject {
        var selection: Binding<Bool>
        init(_ selection: Binding<Bool>) { self.selection = selection }
        @objc func changed(_ sender: NSSegmentedControl) {
            selection.wrappedValue = sender.selectedSegment == 1
        }
    }
}
