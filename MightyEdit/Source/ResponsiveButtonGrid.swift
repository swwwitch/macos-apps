import AppKit

/// Each category uses the same width thresholds, even with an incomplete last row.
final class ResponsiveButtonGrid: NSView {
    let buttons: [PaletteButton]
    var buttonHeight: CGFloat { didSet { updateGridHeight(); needsLayout = true } }
    private var gridHeight: NSLayoutConstraint!
    override var isFlipped: Bool { true }

    var preferredButtonWidth: CGFloat { buttons.first?.displayMode == .iconOnly ? 60 : 100 }

    static func columnCount(for width: CGFloat, buttonWidth: CGFloat = 100) -> Int {
        max(1, Int((max(0, width) + 8) / (buttonWidth + 8)))
    }

    init(buttons: [PaletteButton], buttonHeight: CGFloat) {
        self.buttons = buttons
        self.buttonHeight = buttonHeight
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        for button in buttons {
            button.translatesAutoresizingMaskIntoConstraints = true
            button.autoresizingMask = []
            addSubview(button)
        }
        gridHeight = heightAnchor.constraint(equalToConstant: 1)
        gridHeight.isActive = true
        updateGridHeight()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func setFrameSize(_ newSize: NSSize) {
        let changed = abs(newSize.width - frame.width) > 0.01
        super.setFrameSize(newSize)
        if changed { updateGridHeight(); needsLayout = true }
    }

    func refreshVisibility() { updateGridHeight(); needsLayout = true }

    private func updateGridHeight() {
        guard gridHeight != nil else { return }
        let columns = Self.columnCount(for: bounds.width, buttonWidth: preferredButtonWidth)
        let rows = (buttons.filter { !$0.isHidden }.count + columns - 1) / columns
        let height = CGFloat(rows) * buttonHeight + CGFloat(max(0, rows - 1)) * 8
        if gridHeight.constant != height { gridHeight.constant = height }
    }

    override func layout() {
        super.layout()
        updateGridHeight()
        let columns = Self.columnCount(for: bounds.width, buttonWidth: preferredButtonWidth)
        let width = min(preferredButtonWidth, max(0, bounds.width))
        for (index, button) in buttons.filter({ !$0.isHidden }).enumerated() {
            button.frame = NSRect(x: CGFloat(index % columns) * (width + 8),
                                  y: CGFloat(index / columns) * (buttonHeight + 8),
                                  width: width, height: buttonHeight)
        }
    }
}
