import AppKit
import CoreImage

/// Writes .webloc and QR code PNG files. Existing files are never replaced: a number is added instead (B10).
enum LinkFiles {
    static func webloc(url: String) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: ["URL": url], format: .xml, options: 0)
    }

    /// QR code as PNG, generated on this Mac (the macro used api.qrserver.com; nothing is sent now).
    /// About 400 px with a 40 px white margin, as in the macro's size=400x400&margin=40.
    static func qrPNG(text: String) -> Data? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(text.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let code = filter.outputImage else { return nil }
        let modules = code.extent.width
        let scale = max(1, floor(400 / modules))
        let side = Int(modules * scale) + 80
        let scaled = code.transformed(by: CGAffineTransform(scaleX: scale, y: scale)).transformed(by: CGAffineTransform(translationX: 40, y: 40))
        let canvas = CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: side, height: side))
        let image = scaled.composited(over: canvas)
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cg = context.createCGImage(image, from: canvas.extent) else { return nil }
        let rep = NSBitmapImageRep(cgImage: cg)
        return rep.representation(using: .png, properties: [:])
    }

    /// `name.ext`, or `name 2.ext`, `name 3.ext`… when taken.
    static func freeURL(in folder: URL, name: String, ext: String) -> URL {
        let manager = FileManager.default
        var candidate = folder.appendingPathComponent(name).appendingPathExtension(ext)
        var number = 2
        while manager.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(name) \(number)").appendingPathExtension(ext)
            number += 1
        }
        return candidate
    }

    static func write(_ data: Data, to folder: URL, name: String, ext: String) throws -> URL {
        let target = freeURL(in: folder, name: name, ext: ext)
        // withoutOverwriting: a file created between the check and the write is still not replaced.
        try data.write(to: target, options: .withoutOverwriting)
        return target
    }

    static var desktop: URL { FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop") }
}
