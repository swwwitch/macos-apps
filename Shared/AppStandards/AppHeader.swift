import AppKit
import SwiftUI

// Main-window header uses the same icon resource as the distributed app.
func currentAppIcon() -> NSImage {
    let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") as? String ?? "AppIcon"
    let filename = name.hasSuffix(".icns") ? name : name + ".icns"
    if let url = Bundle.main.resourceURL?.appendingPathComponent(filename),
       let image = NSImage(contentsOf: url) { return image }
    return NSApp.applicationIconImage
}
/// Shown under the header icon: version, then build in parentheses (「1.4.5」「（15）」).
func appVersionText() -> String {
    let info = Bundle.main.infoDictionary ?? [:]
    let version = info["CFBundleShortVersionString"] as? String ?? ""
    guard let build = info["CFBundleVersion"] as? String, !build.isEmpty, build != version else { return version }
    let japanese = Bundle.main.preferredLocalizations.first?.hasPrefix("ja") ?? false
    return version + "\n" + (japanese ? "（\(build)）" : "(\(build))")
}
func appVersionLabel() -> NSTextField {
    let label = NSTextField(labelWithString: appVersionText())
    label.font = .systemFont(ofSize: 10)
    label.textColor = .secondaryLabelColor
    label.alignment = .center
    label.maximumNumberOfLines = 2
    return label
}
/// SwiftUI form of appVersionLabel(), placed under the header icon.
struct AppVersionLabel: View {
    var body: some View {
        Text(appVersionText()).font(.system(size: 10)).foregroundStyle(.secondary)
            .multilineTextAlignment(.center).fixedSize()
    }
}
func appHeader(_ title: String, subtitle: String = "", size: CGFloat = 44, showsVersion: Bool = true) -> NSStackView {
    let icon = NSImageView(image: currentAppIcon())
    icon.imageScaling = .scaleProportionallyUpOrDown
    icon.setAccessibilityElement(false)
    icon.widthAnchor.constraint(equalToConstant: size).isActive = true
    icon.heightAnchor.constraint(equalToConstant: size).isActive = true
    let iconColumn = NSStackView(views: showsVersion ? [icon, appVersionLabel()] : [icon])
    iconColumn.orientation = .vertical; iconColumn.alignment = .centerX; iconColumn.spacing = 4
    let label = NSTextField(labelWithString: title)
    label.font = .systemFont(ofSize: size == 44 ? 20 : 15, weight: .semibold)
    let detail = NSTextField(wrappingLabelWithString: subtitle)
    detail.font = .systemFont(ofSize: size == 44 ? 12 : 11)
    detail.textColor = .secondaryLabelColor
    let text = NSStackView(views: subtitle.isEmpty ? [label] : [label, detail])
    text.orientation = .vertical; text.alignment = .leading; text.spacing = 4
    let row = NSStackView(views: [iconColumn, text])
    row.orientation = .horizontal; row.alignment = .centerY; row.spacing = 12
    return row
}
