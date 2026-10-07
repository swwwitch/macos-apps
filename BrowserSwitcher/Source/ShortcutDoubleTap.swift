// Requires two separate presses within 400 ms; ignores key-repeat while held.
struct ShortcutDoubleTap {
    private var isDown = false
    private var firstPress: Double?
    mutating func handle(pressed: Bool, time: Double) -> Bool {
        if !pressed { isDown = false; return false }
        guard !isDown else { return false }
        isDown = true
        if let first = firstPress, time >= first, time - first <= 0.4 {
            firstPress = nil
            return true
        }
        firstPress = time
        return false
    }
}
