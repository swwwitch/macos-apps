import Foundation
import CoreText

func L(_ value: String) -> String { value }

@main
struct AdobeFontActivationTests {
    static func main() {
        // Use an independently generated font with a unique PostScript name.
        // Never run this test against a user's font or Adobe's cache.
        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        precondition(url.lastPathComponent == "NMTProbe20261025.ttf")
        precondition(CTFontManagerGetScopeForURL(url as CFURL) == .none)
        assert(AdobeFontActivation.setEnabled(true, url: url) != nil)
        var error: Unmanaged<CFError>?
        precondition(CTFontManagerRegisterFontsForURL(url as CFURL, .session, &error))
        defer {
            _ = AdobeFontActivation.setEnabled(true, url: url)
            CTFontManagerUnregisterFontsForURL(url as CFURL, .session, nil)
        }
        assert(AdobeFontActivation.setEnabled(false, url: url) == nil)
        assert(AdobeFontActivation.wasDisabledHere(url))
        assert(CTFontManagerGetScopeForURL(url as CFURL) == .none)
        assert(AdobeFontActivation.setEnabled(false, url: url) == nil)
        assert(AdobeFontActivation.setEnabled(true, url: url) == nil)
        assert(!AdobeFontActivation.wasDisabledHere(url))
        assert(CTFontManagerGetScopeForURL(url as CFURL) != .none)
        assert(AdobeFontActivation.setEnabled(true, url: url) == nil)
        print("PASS: unregistered rejection, disable, retained identity, repeated disable, re-enable, repeated enable")
    }
}
