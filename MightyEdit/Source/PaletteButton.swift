import AppKit

enum PaletteDisplayMode: Int, CaseIterable {
    case both, iconOnly, textOnly
    var title: String {
        switch self {
        case .both: return L("display.both")
        case .iconOnly: return L("display.iconOnly")
        case .textOnly: return L("display.textOnly")
        }
    }
    var next: Self { Self(rawValue: (rawValue + 1) % Self.allCases.count)! }
    static var saved: Self { Self(rawValue: UserDefaults.standard.integer(forKey: "paletteDisplayMode")) ?? .both }
}

/// Retains NSButton's action/accessibility tracking without activating the palette.
final class PaletteButton: NSButton {
    var displayMode = PaletteDisplayMode.saved { didSet { needsDisplay = true } }
    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric) }
    var isHovered = false { didSet { needsDisplay = true } }
    private var hoverArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        cell = PaletteButtonCell(textCell: "")
        setButtonType(.momentaryChange)
        isBordered = false
        refusesFirstResponder = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverArea { removeTrackingArea(hoverArea) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area)
        hoverArea = area
        if let point = window?.mouseLocationOutsideOfEventStream {
            isHovered = bounds.contains(convert(point, from: nil))
        }
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); needsDisplay = true }
}

final class PaletteButtonCell: NSButtonCell {
    override func draw(withFrame frame: NSRect, in controlView: NSView) {
        guard let button = controlView as? PaletteButton else { return }
        let hovered = button.isHovered && isEnabled
        let pressed = isHighlighted && isEnabled
        let rect = frame.insetBy(dx: 0.5, dy: 0.5)
        let shape = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        let fill = pressed ? NSColor.controlAccentColor.withAlphaComponent(0.24)
            : hovered ? NSColor.controlAccentColor.withAlphaComponent(0.10)
            : NSColor.labelColor.withAlphaComponent(0.065)
        fill.setFill()
        shape.fill()
        if hovered || pressed {
            NSColor.controlAccentColor.withAlphaComponent(pressed ? 0.8 : 0.4).setStroke()
            shape.lineWidth = 1
            shape.stroke()
        }
        let color = isEnabled ? NSColor.labelColor : NSColor.disabledControlTextColor
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12), .foregroundColor: color, .paragraphStyle: paragraph
        ]
        paragraph.lineBreakMode = .byCharWrapping
        let labelHeight: CGFloat = button.displayMode == .iconOnly ? 0 : max(17, min(34, ceil((title as NSString).boundingRect(
            with: NSSize(width: frame.width - 8, height: 34), options: .usesLineFragmentOrigin,
            attributes: attributes).height)))
        let iconHeight: CGFloat = button.displayMode == .textOnly ? 0 : 22
        let gap: CGFloat = button.displayMode == .both ? 6 : 0
        let total = labelHeight + iconHeight + gap
        let offset: CGFloat = pressed ? 1 : 0
        let top = frame.midY - total / 2 + (controlView.isFlipped ? offset : -offset)
        let iconY = controlView.isFlipped ? top : top + labelHeight + gap
        let labelY = controlView.isFlipped ? top + iconHeight + gap : top
        if iconHeight > 0, let icon = image?.withSymbolConfiguration(.init(paletteColors: [color])) {
            let scale = min(24 / icon.size.width, iconHeight / icon.size.height)
            let size = NSSize(width: icon.size.width * scale, height: icon.size.height * scale)
            icon.draw(in: NSRect(x: frame.midX - size.width / 2, y: iconY + (iconHeight - size.height) / 2,
                                width: size.width, height: size.height),
                      from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        }
        if labelHeight > 0 { (title as NSString).draw(with: NSRect(x: frame.minX + 4, y: labelY, width: frame.width - 8, height: labelHeight),
                                options: .usesLineFragmentOrigin, attributes: attributes) }
    }
}
