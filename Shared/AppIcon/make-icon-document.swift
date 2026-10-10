// 既存の.icnsからIcon Composer形式（.icon）を作る。
// 使い方: make-icon-document <入力.icns> <出力.icon>
// タイルの外接矩形で切り抜いて1024pxの全面レイヤーにし、タイルの色を背景の塗りにする。
import AppKit

let arguments = CommandLine.arguments
guard arguments.count == 3,
      let image = NSImage(contentsOf: URL(fileURLWithPath: arguments[1])),
      let source = image.representations
        .compactMap({ $0 as? NSBitmapImageRep })
        .max(by: { $0.pixelsWide < $1.pixelsWide }) else {
    FileHandle.standardError.write("make-icon-document: 入力の.icnsを読めません\n".data(using: .utf8)!)
    exit(1)
}

let width = source.pixelsWide, height = source.pixelsHigh
var minX = width, minY = height, maxX = -1, maxY = -1
for y in 0..<height {
    for x in 0..<width where (source.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.5 {
        minX = min(minX, x); maxX = max(maxX, x)
        minY = min(minY, y); maxY = max(maxY, y)
    }
}
guard maxX >= minX, maxY >= minY else { exit(1) }

// 左端から少し内側、天地中央の色をタイルの色とみなす。
let tile = source.colorAt(x: minX + (maxX - minX) / 12, y: (minY + maxY) / 2)!.usingColorSpace(.sRGB)!

let size = 1024
let output = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: output)
NSGraphicsContext.current?.imageInterpolation = .high
let sourceImage = NSImage(size: NSSize(width: width, height: height))
sourceImage.addRepresentation(source)
// colorAtのyは上から、drawのfromは下から数える。
sourceImage.draw(
    in: NSRect(x: 0, y: 0, width: size, height: size),
    from: NSRect(x: minX, y: height - 1 - maxY, width: maxX - minX + 1, height: maxY - minY + 1),
    operation: .copy, fraction: 1)
NSGraphicsContext.restoreGraphicsState()

let documentURL = URL(fileURLWithPath: arguments[2])
let assetsURL = documentURL.appendingPathComponent("Assets")
try? FileManager.default.removeItem(at: documentURL)
try FileManager.default.createDirectory(at: assetsURL, withIntermediateDirectories: true)
try output.representation(using: .png, properties: [:])!.write(to: assetsURL.appendingPathComponent("art.png"))

let fill = String(format: "srgb:%.5f,%.5f,%.5f,1.00000", tile.redComponent, tile.greenComponent, tile.blueComponent)
let json = """
{
  "fill" : { "solid" : "\(fill)" },
  "groups" : [
    {
      "layers" : [ { "image-name" : "art.png", "name" : "art" } ],
      "shadow" : { "kind" : "neutral", "opacity" : 0.5 },
      "translucency" : { "enabled" : false, "value" : 0.5 }
    }
  ],
  "supported-platforms" : { "squares" : [ "macOS" ] }
}

"""
try json.write(to: documentURL.appendingPathComponent("icon.json"), atomically: true, encoding: .utf8)
