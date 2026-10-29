import AppKit
import Darwin

/// The same runtime client used by macOS Keyboard settings. All selectors are checked
/// so Macs without a supported keyboard keep these controls unavailable.
enum KeyboardBacklight {
    private static let client: NSObject? = {
        guard dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_LAZY) != nil,
              let type = NSClassFromString("KeyboardBrightnessClient"),
              let method = class_getClassMethod(type, NSSelectorFromString("new")) else { return nil }
        typealias Factory = @convention(c) (AnyClass, Selector) -> Unmanaged<AnyObject>
        let make = unsafeBitCast(method_getImplementation(method), to: Factory.self)
        return make(type, NSSelectorFromString("new")).takeRetainedValue() as? NSObject
    }()

    private static var keyboard: UInt64? {
        guard let client, client.responds(to: NSSelectorFromString("copyKeyboardBacklightIDs")),
              let ids = client.perform(NSSelectorFromString("copyKeyboardBacklightIDs"))?.takeRetainedValue() as? [NSNumber] else { return nil }
        return ids.first(where: { flag("isKeyboardBuiltIn:", id: $0.uint64Value) == true })?.uint64Value ?? ids.first?.uint64Value
    }

    private static func flag(_ name: String, id: UInt64) -> Bool? {
        let selector = NSSelectorFromString(name)
        guard let client, client.responds(to: selector), let method = client.method(for: selector) else { return nil }
        typealias Read = @convention(c) (AnyObject, Selector, UInt64) -> Bool
        return unsafeBitCast(method, to: Read.self)(client, selector, id)
    }

    static var automatic: Bool? {
        guard let id = keyboard, flag("isAmbientFeatureAvailableOnKeyboard:", id: id) == true else { return nil }
        return flag("isAutoBrightnessEnabledForKeyboard:", id: id)
    }

    static var brightness: Double? {
        let selector = NSSelectorFromString("brightnessForKeyboard:")
        guard let id = keyboard, let client, client.responds(to: selector), let method = client.method(for: selector) else { return nil }
        typealias Read = @convention(c) (AnyObject, Selector, UInt64) -> Float
        let value = Double(unsafeBitCast(method, to: Read.self)(client, selector, id))
        return value.isFinite && (0...1).contains(value) ? value : nil
    }

    static func setAutomatic(_ value: Bool) -> Bool {
        let selector = NSSelectorFromString("enableAutoBrightness:forKeyboard:")
        guard let id = keyboard, let client, client.responds(to: selector), let method = client.method(for: selector) else { return false }
        typealias Write = @convention(c) (AnyObject, Selector, Bool, UInt64) -> Bool
        return unsafeBitCast(method, to: Write.self)(client, selector, value, id) && automatic == value
    }

    static func setBrightness(_ value: Double) -> Bool {
        let selector = NSSelectorFromString("setBrightness:forKeyboard:")
        guard value.isFinite, let id = keyboard, let client, client.responds(to: selector), let method = client.method(for: selector) else { return false }
        typealias Write = @convention(c) (AnyObject, Selector, Float, UInt64) -> Bool
        return unsafeBitCast(method, to: Write.self)(client, selector, Float(min(max(value, 0), 1)), id)
    }
}
