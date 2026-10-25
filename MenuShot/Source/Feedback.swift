import AppKit

/// A white flash over the captured area, like the macOS screenshot. Shown after the capture, so it never appears in the picture.
@MainActor enum ScreenFlash {
    private static var window: NSWindow?

    /// `area`: global top-left coordinates in points (ScreenCaptureKit's), converted to AppKit's bottom-left ones.
    static func show(_ area: CGRect) {
        window?.orderOut(nil)
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let rect = NSRect(x: area.minX, y: primaryHeight - area.maxY, width: area.width, height: area.height)
        let flash = NSWindow(contentRect: rect, styleMask: .borderless, backing: .buffered, defer: false)
        // Above open menus (pop-up menu level 101); never takes focus, so the menu stays open.
        flash.level = .screenSaver
        flash.isOpaque = false; flash.hasShadow = false; flash.ignoresMouseEvents = true; flash.isReleasedWhenClosed = false
        flash.backgroundColor = .white; flash.alphaValue = 0.75
        flash.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        flash.orderFrontRegardless()
        window = flash
        // Reduce Motion: a short flash without the fade.
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { flash.orderOut(nil) }
            return
        }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.35
            flash.animator().alphaValue = 0
        }, completionHandler: { flash.orderOut(nil) })
    }
}

/// Selects a file in Path Finder when it is running (this Mac's file viewer) through AppleScript `reveal`, as ProjectFolder does;
/// otherwise in the default file viewer. NSWorkspace hands the file to Path Finder when it is the default viewer, but did not show it reliably.
@MainActor enum FileReveal {
    static let pathFinderIDs = ["com.cocoatech.PathFinder-setapp", "com.cocoatech.PathFinder"]

    static func reveal(_ url: URL) {
        if let id = pathFinderIDs.first(where: { !NSRunningApplication.runningApplications(withBundleIdentifier: $0).isEmpty }) {
            // Asks for Automation permission the first time; when refused or failing, Finder takes over.
            let path = url.path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            var error: NSDictionary?
            _ = NSAppleScript(source: "tell application id \"\(id)\"\nactivate\nreveal POSIX file \"\(path)\"\nend tell")?.executeAndReturnError(&error)
            if error == nil { return }
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
