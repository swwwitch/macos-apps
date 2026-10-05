import SwiftUI
import AppKit

/// An AppKit destination reads Finder/Dock file URLs directly from the dragging pasteboard.
struct ApplicationDropZone: ViewModifier {
    let clicked: () -> Void
    var dragSource: Application? = nil
    var requiredClickCount = 1
    let choose: (Application) -> Void
    @State private var targeted = false

    func body(content: Content) -> some View {
        content
            .background(targeted ? Color.accentColor.opacity(0.20) : .clear)
            .overlay {
                Rectangle().stroke(targeted ? Color.accentColor : .clear, lineWidth: 2)
                    .allowsHitTesting(false)
            }
            .overlay {
                NativeApplicationDropTarget(clicked: clicked, dragSource: dragSource, requiredClickCount: requiredClickCount, choose: choose, hover: { targeted = $0 })
            }
    }
}

struct NativeApplicationDropTarget: NSViewRepresentable {
    let clicked: () -> Void
    let dragSource: Application?
    let requiredClickCount: Int
    let choose: (Application) -> Void
    let hover: (Bool) -> Void
    @Environment(\.isEnabled) private var enabled

    func makeNSView(context: Context) -> ApplicationDropNSView {
        let view = ApplicationDropNSView()
        view.registerForDraggedTypes([.fileURL, .URL, .string, NSPasteboard.PasteboardType("NSFilenamesPboardType")])
        updateNSView(view, context: context)
        return view
    }
    func updateNSView(_ view: ApplicationDropNSView, context: Context) {
        view.requiredClickCount = requiredClickCount
        view.clicked = clicked
        view.dragSource = dragSource
        view.choose = choose
        view.hover = hover
        view.enabled = enabled
    }
}
