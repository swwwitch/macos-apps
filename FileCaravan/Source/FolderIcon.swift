import AppKit
import CoreImage

// Finder's tag-based folder colors are not included in icon(forFile:).
func folderIcon(for url: URL) -> NSImage {
    let original = NSWorkspace.shared.icon(forFile: url.path)
    let freshURL = URL(fileURLWithPath: url.path)
    let values = try? freshURL.resourceValues(forKeys: [.labelNumberKey, .customIconKey])
    guard values?.customIcon == nil, let label = values?.labelNumber, label > 0 else { return original }
    let colors: [NSColor] = [.clear, .systemGray, .systemGreen, .systemPurple,
                             .systemBlue, .systemYellow, .systemRed, .systemOrange]
    guard colors.indices.contains(label),
          let data = original.tiffRepresentation, let input = CIImage(data: data),
          let filter = CIFilter(name: "CIColorMonochrome") else { return original }
    filter.setValue(input, forKey: kCIInputImageKey)
    filter.setValue(CIColor(color: colors[label]), forKey: kCIInputColorKey)
    filter.setValue(1.0, forKey: kCIInputIntensityKey)
    guard let output = filter.outputImage else { return original }
    let result = NSImage(size: original.size)
    result.addRepresentation(NSCIImageRep(ciImage: output))
    return result
}

