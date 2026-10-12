import Foundation

/// Mouse pointer size (System Settings → Accessibility → Display → Pointer size), 1 = standard … 4.
/// The window server's cursor scale changes the pointer at once. The universalaccess preference is also written,
/// but macOS refuses that write for apps without Full Disk Access (measured), so System Settings and the next login
/// keep their own value. Writing only the preference changes nothing until re-login.
enum PointerSize {
    static let range: ClosedRange<Double> = 1...4
    private static let domain = "com.apple.universalaccess" as CFString
    private static let key = "mouseDriverCursorSize" as CFString

    private typealias ConnectionFunction = @convention(c) () -> Int32
    private typealias GetFunction = @convention(c) (Int32, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetFunction = @convention(c) (Int32, Float) -> Int32
    private static let handle = dlopen("/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices", RTLD_NOW)
    private static func symbol<T>(_ name: String, as type: T.Type) -> T? {
        dlsym(handle, name).map { unsafeBitCast($0, to: type) }
    }

    /// The scale the pointer is drawn at now, or the saved preference when the window server cannot be asked.
    static var current: Double {
        if let connection = symbol("CGSMainConnectionID", as: ConnectionFunction.self),
           let get = symbol("CGSGetCursorScale", as: GetFunction.self) {
            var scale: Float = 0
            if get(connection(), &scale) == 0, scale > 0 { return Double(scale) }
        }
        CFPreferencesAppSynchronize(domain)
        return (CFPreferencesCopyAppValue(key, domain) as? NSNumber)?.doubleValue ?? 1
    }

    /// Applies the size at once and saves it. Returns false when the pointer could not be changed.
    @discardableResult
    static func set(_ value: Double) -> Bool {
        let size = min(max(value, range.lowerBound), range.upperBound)
        CFPreferencesSetAppValue(key, NSNumber(value: size), domain)
        CFPreferencesAppSynchronize(domain)
        guard let connection = symbol("CGSMainConnectionID", as: ConnectionFunction.self),
              let setScale = symbol("CGSSetCursorScale", as: SetFunction.self) else { return false }
        return setScale(connection(), Float(size)) == 0
    }

    /// "2.5" / "1" for messages and labels.
    static func text(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }
}
