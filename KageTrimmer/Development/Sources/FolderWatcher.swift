import AppKit
import ImageIO

/// Watches one folder and hands newly added window screenshots to `onCapture`.
/// macOS screenshots carry their capture type in an extended attribute; other tools (CleanShot X…)
/// are recognised by the EXIF "Screenshot" comment plus a transparent shadow margin or transparent rounded corners.
@MainActor final class FolderWatcher {
    static let shared = FolderWatcher()
    static let enabledKey = "watchFolderEnabled"
    static let pathKey = "watchFolderPath"
    static let bookmarkKey = "watchFolderBookmark"
    static let stateChanged = Notification.Name("KageTrimmerWatchFolderStateChanged")

    var onCapture: (([URL]) -> Void)?
    /// False when watching is on but the folder could not be opened.
    private(set) var isWatching = false
    private var source: DispatchSourceFileSystemObject?
    private var scopedFolder: URL?
    private var watchedFolder: URL?
    private var known: Set<String> = []
    /// New files whose size is still changing, with the size seen at the previous scan.
    private var growing: [String: Int] = [:]
    private var scanScheduled = false

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    /// The chosen folder, else the macOS screenshot location, else the Desktop.
    static var folder: URL {
        if let path = UserDefaults.standard.string(forKey: pathKey), !path.isEmpty { return URL(fileURLWithPath: path, isDirectory: true) }
        return defaultFolder
    }

    static var defaultFolder: URL {
        #if !APP_STORE
        if let location = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location") {
            let path = (location as NSString).expandingTildeInPath
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue {
                return URL(fileURLWithPath: path, isDirectory: true)
            }
        }
        #endif
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory())
    }

    static func setFolder(_ url: URL) {
        UserDefaults.standard.set(url.path, forKey: pathKey)
        // The App Store build can only reopen a folder the user chose through a security-scoped bookmark.
        if let bookmark = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
        } else {
            UserDefaults.standard.removeObject(forKey: bookmarkKey)
        }
    }

    func restart() {
        stop()
        defer { NotificationCenter.default.post(name: Self.stateChanged, object: nil) }
        guard Self.isEnabled else { return }
        var folder = Self.folder
        if let bookmark = UserDefaults.standard.data(forKey: Self.bookmarkKey) {
            var stale = false
            if let resolved = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale),
               resolved.standardizedFileURL.path == folder.standardizedFileURL.path {
                folder = resolved
                if resolved.startAccessingSecurityScopedResource() { scopedFolder = resolved }
                if stale { Self.setFolder(resolved) }
            }
        }
        let descriptor = open(folder.path, O_EVTONLY)
        guard descriptor >= 0 else { stop(); return }
        watchedFolder = folder
        known = Set(listing(of: folder))
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write], queue: .main)
        source.setEventHandler { [weak self] in self?.scheduleScan(after: 1.0) }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        self.source = source
        isWatching = true
    }

    func stop() {
        source?.cancel(); source = nil
        scopedFolder?.stopAccessingSecurityScopedResource(); scopedFolder = nil
        watchedFolder = nil
        known = []; growing = [:]
        isWatching = false
    }

    /// Visible regular files only: macOS writes a hidden ".Screenshot…" file first and renames it when done.
    private func listing(of folder: URL) -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return names.filter { !$0.hasPrefix(".") }
    }

    private func scheduleScan(after delay: TimeInterval) {
        guard !scanScheduled else { return }
        scanScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.scanScheduled = false
            self?.scan()
        }
    }

    /// A new file is evaluated once its size is the same at two scans, so a file still being written is not read.
    private func scan() {
        guard let folder = watchedFolder else { return }
        let current = Set(listing(of: folder))
        var ready: [URL] = []
        for name in current.subtracting(known) {
            let url = folder.appendingPathComponent(name)
            guard let size = (try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])).flatMap({ $0.isRegularFile == true ? $0.fileSize : nil }) else {
                known.insert(name); continue
            }
            if size > 0, growing[name] == size {
                growing[name] = nil
                known.insert(name)
                ready.append(url)
            } else {
                growing[name] = size
            }
        }
        // Forget removed and renamed names so a file put back later counts as new.
        known.formIntersection(current)
        growing = growing.filter { current.contains($0.key) }
        if !growing.isEmpty { scheduleScan(after: 0.7) }
        guard !ready.isEmpty else { return }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let windows = ready.filter(Self.isWindowScreenshot)
            guard !windows.isEmpty else { return }
            DispatchQueue.main.async { self?.onCapture?(windows) }
        }
    }

    nonisolated static func isWindowScreenshot(_ url: URL) -> Bool {
        if let type = screenCaptureType(url) { return type == "window" }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
              (exif[kCGImagePropertyExifUserComment] as? String) == "Screenshot",
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return false }
        // A window captured with a background (CleanShot's wallpaper or plain colour) is opaque and not recognised.
        return ShadowProcessor.detectContent(in: image).hadShadow || hasTransparentCorners(image)
    }

    /// A window captured without a shadow keeps transparent rounded corners; area captures are opaque to the edge.
    nonisolated static func hasTransparentCorners(_ image: CGImage) -> Bool {
        let width = image.width, height = image.height
        guard width > 2, height > 2 else { return false }
        return [(0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)].allSatisfy { x, y in
            guard let pixel = image.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)) else { return false }
            var rgba: [UInt8] = [0, 0, 0, 0]
            let drew = rgba.withUnsafeMutableBytes { storage -> Bool in
                guard let context = CGContext(data: storage.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                              space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
                context.draw(pixel, in: CGRect(x: 0, y: 0, width: 1, height: 1))
                return true
            }
            return drew && rgba[3] < 128
        }
    }

    /// "window", "selection" or "display" for a macOS screenshot; nil for anything else.
    nonisolated static func screenCaptureType(_ url: URL) -> String? {
        let name = "com.apple.metadata:kMDItemScreenCaptureType"
        let length = getxattr(url.path, name, nil, 0, 0, 0)
        guard length > 0 else { return nil }
        var data = Data(count: length)
        let read = data.withUnsafeMutableBytes { getxattr(url.path, name, $0.baseAddress, length, 0, 0) }
        guard read == length else { return nil }
        return try? PropertyListSerialization.propertyList(from: data, format: nil) as? String
    }
}

/// 「フォルダ監視」 tab.
@MainActor final class FolderWatchSettingsController: NSObject {
    private let enabled = NSButton(checkboxWithTitle: L("フォルダを監視して自動で処理する"), target: nil, action: nil)
    private let pathLabel = NSTextField(labelWithString: "")
    private let message = NSTextField(wrappingLabelWithString: "")

    func makeView() -> NSView {
        enabled.state = FolderWatcher.isEnabled ? .on : .off
        enabled.target = self; enabled.action = #selector(enabledChanged)
        let folderLabel = NSTextField(labelWithString: L("監視するフォルダ"))
        pathLabel.lineBreakMode = .byTruncatingMiddle
        pathLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let choose = NSButton(title: L("選択…"), target: self, action: #selector(chooseFolder))
        let folderRow = NSStackView(views: [folderLabel, pathLabel, choose]); folderRow.spacing = 8; folderRow.alignment = .firstBaseline
        let help = NSTextField(wrappingLabelWithString: L("ウインドウのスクリーンショットがこのフォルダに追加されたとき、メインウインドウで選んでいる影の大きさで処理します。範囲指定や画面全体のスクリーンショットは処理しません。CleanShot Xでは、ウインドウの背景を「透明」にし、保存先をこのフォルダにしてください。"))
        help.font = .systemFont(ofSize: 11); help.textColor = .secondaryLabelColor
        message.font = .systemFont(ofSize: 11); message.textColor = .systemRed
        let group = SettingsUI.group(L("フォルダ監視"), [enabled, folderRow, help, message])
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: FolderWatcher.stateChanged, object: nil)
        refresh()
        return group
    }

    @objc private func refresh() {
        let folder = FolderWatcher.folder
        pathLabel.stringValue = (folder.path as NSString).abbreviatingWithTildeInPath
        pathLabel.toolTip = folder.path
        let failed = FolderWatcher.isEnabled && !FolderWatcher.shared.isWatching
        message.stringValue = failed ? L("フォルダを監視できません。フォルダを選び直してください。") : ""
        message.isHidden = !failed
    }

    @objc private func enabledChanged() {
        UserDefaults.standard.set(enabled.state == .on, forKey: FolderWatcher.enabledKey)
        FolderWatcher.shared.restart()
    }

    @objc private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = L("監視するフォルダを選択")
        panel.prompt = L("選択")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = FolderWatcher.folder
        let finish: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            FolderWatcher.setFolder(url)
            FolderWatcher.shared.restart()
            self?.refresh()
        }
        if let window = enabled.window { panel.beginSheetModal(for: window, completionHandler: finish) } else { finish(panel.runModal()) }
    }
}
