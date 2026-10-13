import AppKit

// Shared main-content surface. The native traffic-light/title-bar area is untouched.
enum AppSurface {
    static let color = NSColor(name: "SharedMainSurface") { appearance in
        let value: CGFloat = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? 0.16 : 236.0 / 255.0
        return NSColor(srgbRed: value, green: value, blue: value, alpha: 1)
    }
    static func install(in content: NSView) {
        let background = AppSurfaceView(frame: content.bounds)
        background.autoresizingMask = [.width, .height]
        content.addSubview(background, positioned: .below, relativeTo: nil)
    }
}
final class AppSurfaceView: NSView {
    override init(frame: NSRect) { super.init(frame: frame); clipsToBounds = true }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var isOpaque: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func draw(_ dirtyRect: NSRect) {
        let value: CGFloat = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? 0.16 : 236.0 / 255.0
        NSColor(srgbRed: value, green: value, blue: value, alpha: 1).setFill()
        bounds.intersection(dirtyRect).fill()
    }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); needsDisplay = true }
}
