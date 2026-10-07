import AppKit
import UniformTypeIdentifiers

/// Activation notifications show the palette without activating MightyEdit.
final class AppAutoShow: NSObject {
    private struct Target: Codable {
        let bundleID: String
        let name: String
    }
    private var targets: [Target] = []
    private var observer: NSObjectProtocol?
    private var departureObserver: NSObjectProtocol?
    private var toggle: NSButton?
    private var list: NSStackView?
    private let note = NSTextField(wrappingLabelWithString: "")
    var showPalette: (() -> Void)?
    var externalAppDeactivated: ((NSRunningApplication) -> Void)?
    var externalAppActivated: ((NSRunningApplication) -> Void)?
    private let ownID = Bundle.main.bundleIdentifier ?? "jp.local.TextPalette"

    override init() {
        if let data = UserDefaults.standard.data(forKey: "autoShowApplications"),
           let saved = try? JSONDecoder().decode([Target].self, from: data) { targets = saved }
        super.init()
    }
    func start() {
        guard observer == nil else { return }
        departureObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didDeactivateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            guard let self, let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
            self.externalAppDeactivated?(app)
        }
        observer = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                                                                      object: nil, queue: .main) { [weak self] notification in
            guard let self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let id = app.bundleIdentifier, id != self.ownID,
                  NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier else { return }
            self.externalAppActivated?(app)
            guard UserDefaults.standard.bool(forKey: "autoShowEnabled"), self.targets.contains(where: { $0.bundleID == id }) else { return }
            self.showPalette?()
        }
    }
    deinit { for token in [observer, departureObserver].compactMap({ $0 }) { NSWorkspace.shared.notificationCenter.removeObserver(token) } }

    func makeSettingsView() -> NSView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        let document = AutoShowDocumentView()
        document.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = document
        document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor).isActive = true
        let column = NSStackView()
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 14
        column.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(column)
        let heading = NSTextField(labelWithString: L("auto.heading"))
        heading.font = .boldSystemFont(ofSize: 18)
        column.addArrangedSubview(heading)
        let enabled = NSButton(checkboxWithTitle: L("auto.enable"), target: self, action: #selector(toggleEnabled(_:)))
        enabled.state = UserDefaults.standard.bool(forKey: "autoShowEnabled") ? .on : .off
        toggle = enabled
        column.addArrangedSubview(enabled)
        let explanation = NSTextField(wrappingLabelWithString: L("auto.explanation"))
        column.addArrangedSubview(explanation)
        let buttons = NSStackView()
        buttons.spacing = 10
        let add = NSButton(title: L("auto.addApp"), target: self, action: #selector(addApplications))
        add.bezelStyle = .rounded
        buttons.addArrangedSubview(add)
        let running = NSButton(title: L("auto.addRunning"), target: self, action: #selector(chooseRunning(_:)))
        running.bezelStyle = .rounded
        buttons.addArrangedSubview(running)
        column.addArrangedSubview(buttons)
        let rows = NSStackView()
        rows.orientation = .vertical
        rows.alignment = .leading
        rows.spacing = 12
        column.addArrangedSubview(rows)
        rows.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
        list = rows
        note.font = .systemFont(ofSize: 12)
        note.textColor = .secondaryLabelColor
        column.addArrangedSubview(note)
        let behavior = NSTextField(wrappingLabelWithString: L("auto.behavior"))
        behavior.font = .systemFont(ofSize: 12)
        column.addArrangedSubview(behavior)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 24),
            column.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -24),
            column.topAnchor.constraint(equalTo: document.topAnchor, constant: 24),
            column.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -24),
            explanation.widthAnchor.constraint(equalTo: column.widthAnchor),
            note.widthAnchor.constraint(equalTo: column.widthAnchor),
            behavior.widthAnchor.constraint(equalTo: column.widthAnchor)
        ])
        refresh()
        return scroll
    }
    @objc private func toggleEnabled(_ sender: NSButton) {
        UserDefaults.standard.set(sender.state == .on, forKey: "autoShowEnabled")
        refresh()
    }
    private func save() {
        if let data = try? JSONEncoder().encode(targets) { UserDefaults.standard.set(data, forKey: "autoShowApplications") }
        refresh()
    }
    private func refresh() {
        guard let list else { return }
        for view in list.arrangedSubviews { list.removeArrangedSubview(view); view.removeFromSuperview() }
        for target in targets {
            let row = NSStackView()
            row.spacing = 12
            let title = NSTextField(wrappingLabelWithString: target.name + "\n" + target.bundleID)
            title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            row.addArrangedSubview(title)
            let remove = NSButton(title: L("auto.removeApp"), target: self, action: #selector(removeApplication(_:)))
            remove.identifier = NSUserInterfaceItemIdentifier(target.bundleID)
            remove.bezelStyle = .rounded
            row.addArrangedSubview(remove)
            list.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: list.widthAnchor).isActive = true
        }
        note.stringValue = targets.isEmpty ? L("auto.empty") : L("auto.count", String(targets.count), UserDefaults.standard.bool(forKey: "autoShowEnabled") ? L("state.on") : L("state.off"))
    }
    @objc private func removeApplication(_ sender: NSButton) {
        targets.removeAll { $0.bundleID == sender.identifier?.rawValue }
        save()
    }
    private func add(_ id: String, name: String) {
        guard id != ownID, !targets.contains(where: { $0.bundleID == id }) else { return }
        targets.append(Target(bundleID: id, name: name))
    }
    @objc private func addApplications() {
        let picker = NSOpenPanel()
        picker.title = L("auto.pickerTitle")
        picker.prompt = L("action.add")
        picker.allowedContentTypes = [.applicationBundle]
        picker.allowsMultipleSelection = true
        picker.canChooseDirectories = false
        picker.directoryURL = URL(fileURLWithPath: "/Applications")
        let completion: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard let self, response == .OK else { return }
            var invalid = false
            for url in picker.urls {
                guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier else { invalid = true; continue }
                self.add(id, name: FileManager.default.displayName(atPath: url.path))
            }
            self.save()
            if invalid { self.note.stringValue += L("auto.invalid") }
        }
        if let window = toggle?.window { picker.beginSheetModal(for: window, completionHandler: completion) }
        else { picker.begin(completionHandler: completion) }
    }
    @objc private func chooseRunning(_ sender: NSButton) {
        let menu = NSMenu()
        var seen = Set<String>()
        for app in NSWorkspace.shared.runningApplications.sorted(by: { ($0.localizedName ?? "") < ($1.localizedName ?? "") }) {
            guard app.activationPolicy == .regular, let id = app.bundleIdentifier, id != ownID, seen.insert(id).inserted else { continue }
            let item = menu.addItem(withTitle: app.localizedName ?? id, action: #selector(addRunning(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = id
            item.state = targets.contains { $0.bundleID == id } ? .on : .off
        }
        if menu.items.isEmpty { menu.addItem(withTitle: L("auto.noneRunning"), action: nil, keyEquivalent: "") }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.maxY), in: sender)
    }
    @objc private func addRunning(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        add(id, name: sender.title)
        save()
    }
}
private final class AutoShowDocumentView: NSView { override var isFlipped: Bool { true } }
