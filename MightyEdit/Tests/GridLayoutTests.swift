import AppKit

@main struct GridLayoutTests {
    static func main() {
        _ = NSApplication.shared
        let buttons = (0..<10).map { index -> PaletteButton in
            let button = PaletteButton(frame: .zero)
            button.displayMode = .both
            button.title = "操作\(index)"
            return button
        }
        let grid = ResponsiveButtonGrid(buttons: buttons, buttonHeight: 74)
        for (width, columns) in [(CGFloat(124), 1), (CGFloat(196), 1), (CGFloat(224), 2), (CGFloat(324), 3), (CGFloat(440), 4), (CGFloat(764), 7), (CGFloat(324), 3)] {
            grid.setFrameSize(NSSize(width: width, height: 1000))
            grid.layout()
            precondition(ResponsiveButtonGrid.columnCount(for: width) == columns)
            for (index, button) in buttons.enumerated() {
                precondition(abs(button.frame.minY - CGFloat(index / columns) * 82) < 0.01)
                precondition(button.frame.minX >= 0 && button.frame.maxX <= width + 0.01)
                precondition(button.frame.width == 100 && button.frame.height == 74)
            }
            let rows = (buttons.count + columns - 1) / columns
            let height = grid.constraints.first { $0.firstAttribute == .height && $0.secondItem == nil }!.constant
            precondition(height == CGFloat(rows * 74 + (rows - 1) * 8))
        }
        for height: CGFloat in [44, 48, 74] {
            grid.buttonHeight = height
            grid.layout()
            precondition(buttons.allSatisfy { $0.frame.height == height })
        }
        buttons[0].isHidden = true
        buttons[2].isHidden = true
        grid.refreshVisibility()
        grid.layout()
        precondition(buttons[1].frame.origin == .zero)
        precondition(buttons[3].frame.minY == 0)
        buttons.forEach { $0.isHidden = true }
        grid.refreshVisibility()
        precondition(grid.constraints.first { $0.firstAttribute == .height && $0.secondItem == nil }!.constant == 0)
        buttons.forEach { $0.isHidden = false }
        grid.refreshVisibility()
        grid.layout()
        precondition(buttons[0].frame.origin == .zero)
        buttons.forEach { $0.displayMode = .iconOnly }
        for (width, columns) in [(CGFloat(60), 1), (CGFloat(127), 1), (CGFloat(128), 2), (CGFloat(200), 3), (CGFloat(332), 5)] {
            grid.setFrameSize(NSSize(width: width, height: 1000)); grid.layout()
            precondition(buttons.allSatisfy { $0.frame.width == 60 })
            precondition(buttons[columns].frame.minY == grid.buttonHeight + 8)
        }
        buttons.forEach { $0.displayMode = .textOnly }
        grid.setFrameSize(NSSize(width: 440, height: 1000)); grid.layout()
        precondition(buttons.allSatisfy { $0.frame.width == 100 })
        print("Passed fixed-width grids for all display modes, column thresholds and visibility")
    }
}
