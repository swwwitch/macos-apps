import Foundation

enum ArrowMode: String, CaseIterable, Identifiable {
    case google, custom
    var id: String { rawValue }
}
struct ArrowSequence {
    static let mappings = [("zh", "←"), ("zj", "↓"), ("zk", "↑"), ("zl", "→")]
    private var prefix = false
    private var context = -1
    mutating func reset() { prefix = false }
    /// The first z is delivered unchanged. A match replaces that one preceding character.
    mutating func feed(_ character: String, context: Int, allowed: Bool) -> String? {
        if self.context != context { reset(); self.context = context }
        guard allowed else { reset(); return nil }
        if prefix, let pair = Self.mappings.first(where: { $0.0 == "z" + character }) { reset(); return pair.1 }
        prefix = character == "z"
        return nil
    }
}
