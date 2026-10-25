import AppKit
import ScreenCaptureKit
import UniformTypeIdentifiers

enum CaptureError: Error {
    /// No menu of another app was open.
    case noMenu
    /// Screen Recording is not allowed (ScreenCaptureKit refused).
    case permission
    case failed(String)
}

/// One picture: the menu bar and the open menus only, on a transparent background.
struct MenuPicture {
    let image: CGImage
    /// Pixels per point (2 on Retina). Saved as the PNG's resolution so the picture opens at its on-screen size.
    let scale: CGFloat
}

enum MenuCapture {
    /// Room around the menus for the drawn shadow, in points.
    static let shadowMargin: CGFloat = 28

    /// Asks without prompting.
    static var hasPermission: Bool { CGPreflightScreenCaptureAccess() }

    /// Whether another app's menu is on screen. Window bounds and levels need no permission, so the hotkey can decide
    /// between capturing now and counting down without touching ScreenCaptureKit.
    static func menuIsOpen() -> Bool {
        let own = ProcessInfo.processInfo.processIdentifier
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        return list.contains { info in
            guard info[kCGWindowLayer as String] as? Int == MenuLayout.menuLayer, info[kCGWindowOwnerPID as String] as? Int32 != own,
                  let bounds = info[kCGWindowBounds as String] as? NSDictionary, let rect = CGRect(dictionaryRepresentation: bounds) else { return false }
            return rect.width >= 8 && rect.height >= 8
        }
    }

    /// Captures each window on its own (so nothing behind it comes along) and puts them together.
    /// A pop-up button's menu captured together with other windows on a display filter brings its parent window along (measured on macOS 26).
    /// A menu window captured on its own brings its submenus along (the whole menu tree, scaled to fit the requested size),
    /// so the root menu is captured once at the size of all the menus.
    static func capture(range: BarRange, shadow: Bool) async throws -> MenuPicture {
        let content: SCShareableContent
        do { content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true) }
        catch { throw hasPermission ? CaptureError.failed(error.localizedDescription) : CaptureError.permission }
        let own = ProcessInfo.processInfo.processIdentifier
        let windows = content.windows.filter { $0.isOnScreen && $0.owningApplication?.processID != own }
        let boxes = windows.map { WindowBox(id: $0.windowID, layer: $0.windowLayer, frame: $0.frame, owner: $0.owningApplication?.processID ?? 0) }
        let frontmost = await MainActor.run { NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0 }
        // The display under the pointer first, so a menu on another screen is only used when this one has none.
        let pointer = topLeftPointer()
        let displays = content.displays.sorted { a, _ in a.frame.contains(pointer) }
        let margin = shadow ? shadowMargin : 0
        let found = displays.lazy.compactMap { d in MenuLayout.plan(windows: boxes, display: d.frame, range: range, margin: margin, frontmost: frontmost).map { (d, $0) } }.first
        writeDiagnostics(windows: windows, frontmost: frontmost, plan: found?.1)
        guard let (display, plan) = found else { throw CaptureError.noMenu }
        let byID = Dictionary(uniqueKeysWithValues: windows.map { ($0.windowID, $0) })
        let scale = CGFloat(SCContentFilter(display: display, excludingWindows: []).pointPixelScale)

        var shots: [Shot] = []
        for box in plan.bar {
            // A status item that went away is skipped; the rest of the bar is still fine.
            guard let window = byID[box.id], let image = try? await shot(window, size: box.frame.size, scale: scale) else { continue }
            shots.append(Shot(frame: box.frame, image: image, isMenu: false))
        }
        let menus = plan.menus.dropFirst().reduce(plan.menus[0].frame) { $0.union($1.frame) }
        guard let root = byID[plan.menus[0].id] else { throw CaptureError.noMenu }
        do { shots.append(Shot(frame: menus, image: try await shot(root, size: menus.size, scale: scale), isMenu: true)) }
        catch { throw CaptureError.failed(error.localizedDescription) }
        guard let image = compose(shots, crop: plan.crop, scale: scale, shadow: shadow)
        else { throw CaptureError.failed("compose") }
        return MenuPicture(image: image, scale: scale)
    }

    struct Shot {
        /// Where the image goes, in global points.
        let frame: CGRect
        let image: CGImage
        let isMenu: Bool
    }

    private static func shot(_ window: SCWindow, size: CGSize, scale: CGFloat) async throws -> CGImage {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        config.width = max(1, Int((size.width * scale).rounded()))
        config.height = max(1, Int((size.height * scale).rounded()))
        // With the system shadow the window is scaled down inside the same size; without it the image matches the frame exactly.
        config.ignoreShadowsSingleWindow = true
        config.showsCursor = false
        config.backgroundColor = .clear
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }

    static func compose(_ shots: [Shot], crop: CGRect, scale: CGFloat, shadow: Bool) -> CGImage? {
        let width = Int((crop.width * scale).rounded()), height = Int((crop.height * scale).rounded())
        let space = shots.first?.image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        guard width > 0, height > 0,
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { return nil }
        context.interpolationQuality = .none
        for shot in shots {
            context.saveGState()
            if shadow && shot.isMenu {
                // Close to the system menu shadow: soft, slightly below.
                context.setShadow(offset: CGSize(width: 0, height: -6 * scale), blur: 18 * scale, color: CGColor(gray: 0, alpha: 0.3))
            }
            context.draw(shot.image, in: MenuLayout.placement(of: shot.frame, in: crop, scale: scale))
            context.restoreGState()
        }
        return context.makeImage()
    }

    /// Overwrites ~/Library/Logs/MenuShot/LastCapture.txt with the windows considered for the last capture:
    /// level, owner, bundle ID and frame only (no titles, no pictures), a few kilobytes at most.
    private static func writeDiagnostics(windows: [SCWindow], frontmost: Int32, plan: MenuLayout.Plan?) {
        let interesting = windows.filter { [MenuLayout.menuBarLayer, MenuLayout.statusLayer, MenuLayout.menuLayer].contains($0.windowLayer) || $0.windowLayer > MenuLayout.menuLayer }
        let used = Set((plan.map { $0.bar + $0.menus } ?? []).map(\.id))
        var lines = ["MenuShot \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "") \(Date())", "frontmost pid \(frontmost)",
                     "crop \(plan.map { "\($0.crop)" } ?? "none")", "used id layer pid bundle frame"]
        for w in interesting.prefix(80) {
            lines.append("\(used.contains(w.windowID) ? "*" : " ") \(w.windowID) \(w.windowLayer) \(w.owningApplication?.processID ?? 0) \(w.owningApplication?.bundleIdentifier ?? "-") \(w.frame)")
        }
        let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/MenuShot")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? (lines.joined(separator: "\n") + "\n").write(to: folder.appendingPathComponent("LastCapture.txt"), atomically: true, encoding: .utf8)
    }

    /// The pointer in global top-left coordinates (ScreenCaptureKit's), from AppKit's bottom-left ones.
    private static func topLeftPointer() -> CGPoint {
        let location = NSEvent.mouseLocation
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: location.x, y: primaryHeight - location.y)
    }

    // MARK: - Output

    /// Writes a PNG next to the others without overwriting: "Menu 2026-10-26 2.10.33.png", then " 2", " 3"…
    /// The file is written under a hidden name first so an interrupted save leaves no broken picture.
    static func save(_ picture: MenuPicture, in folder: URL, prefix: String, date: Date = Date()) throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let stamp = DateFormatter()
        stamp.locale = Locale(identifier: "en_US_POSIX"); stamp.dateFormat = "yyyy-MM-dd H.mm.ss"
        let base = "\(prefix) \(stamp.string(from: date))"
        var url = folder.appendingPathComponent(base + ".png"), number = 2
        while FileManager.default.fileExists(atPath: url.path) { url = folder.appendingPathComponent("\(base) \(number).png"); number += 1 }
        let temporary = folder.appendingPathComponent(".\(UUID().uuidString).png")
        guard let destination = CGImageDestinationCreateWithURL(temporary as CFURL, UTType.png.identifier as CFString, 1, nil) else { throw CaptureError.failed("destination") }
        let dpi = 72 * picture.scale
        CGImageDestinationAddImage(destination, picture.image, [kCGImagePropertyDPIWidth: dpi, kCGImagePropertyDPIHeight: dpi] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { try? FileManager.default.removeItem(at: temporary); throw CaptureError.failed("write") }
        do { try FileManager.default.moveItem(at: temporary, to: url) }
        catch { try? FileManager.default.removeItem(at: temporary); throw error }
        return url
    }

    /// PNG and TIFF, sized in points so pasting into Keynote or Pages keeps the on-screen size.
    @MainActor static func copy(_ picture: MenuPicture) {
        let rep = NSBitmapImageRep(cgImage: picture.image)
        rep.size = NSSize(width: CGFloat(picture.image.width) / picture.scale, height: CGFloat(picture.image.height) / picture.scale)
        let board = NSPasteboard.general
        board.clearContents()
        board.declareTypes([.png, .tiff], owner: nil)
        if let png = rep.representation(using: .png, properties: [:]) { board.setData(png, forType: .png) }
        if let tiff = rep.tiffRepresentation { board.setData(tiff, forType: .tiff) }
    }

    /// The default folder of the macOS screenshot (⇧⌘5 › Options › Save to), else the Desktop.
    static var systemScreenshotFolder: URL {
        let desktop = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        guard let path = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location") else { return desktop }
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
        var isFolder: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isFolder) && isFolder.boolValue ? url : desktop
    }
}
