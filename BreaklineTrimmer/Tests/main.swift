import AppKit
import ImageIO

// Build and run with test.sh. Checks the layout (cut direction, one side, gap, trimming) and the rendered pixels.

var failures = 0
var passes = 0
func check(_ condition: Bool, _ message: String) {
    if condition { passes += 1 } else { failures += 1; print("FAIL", message) }
}

/// Draws on a top-left origin canvas (y grows downward).
func makeImage(_ width: Int, _ height: Int, draw: (CGContext) -> Void) -> CGImage {
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.translateBy(x: 0, y: CGFloat(height)); context.scaleBy(x: 1, y: -1)
    draw(context)
    return context.makeImage()!
}

/// RGBA (0–255, premultiplied) of the pixel at x, y counted from the top left.
func pixel(_ image: CGImage, _ x: Int, _ y: Int) -> [Int] {
    var bytes = [UInt8](repeating: 0, count: 4)
    let context = CGContext(data: &bytes, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.draw(image, in: CGRect(x: -x, y: y - image.height + 1, width: image.width, height: image.height))
    return bytes.map(Int.init)
}

let red = CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)
let blue = CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1)
/// Top half red, bottom half blue (200×100).
let halves = makeImage(200, 100) { context in
    context.setFillColor(red); context.fill(CGRect(x: 0, y: 0, width: 200, height: 50))
    context.setFillColor(blue); context.fill(CGRect(x: 0, y: 50, width: 200, height: 50))
}
let size = CGSize(width: 200, height: 100)

var straight = TrimSettings()
straight.warpPercent = 0
straight.addRule = false
straight.gap = 10

// 1. A wide band in the middle: top and bottom parts, closed up to the gap.
do {
    let layout = try TrimLayout.make(imageSize: size, band: CGRect(x: 0, y: 40, width: 200, height: 20), settings: straight)
    check(layout.axis == .horizontal, "wide band cuts horizontally")
    check(!layout.keepsOneSide, "middle band keeps both sides")
    check(layout.bounds == CGRect(x: 0, y: 0, width: 200, height: 90), "two parts: 100 - 20 + 10 = 90 high, got \(layout.bounds)")
    check(layout.parts[1].offset == CGVector(dx: 0, dy: -10), "lower part moves up by 10")
    let output = TrimRenderer.render(halves, layout: layout, settings: straight)!
    check(output.width == 200 && output.height == 90, "rendered size")
    check(pixel(output, 100, 20) == [255, 0, 0, 255], "top part stays red")
    check(pixel(output, 100, 45)[3] == 0, "the gap is transparent")
    check(pixel(output, 100, 70) == [0, 0, 255, 255], "lower part is blue")
} catch { check(false, "middle band threw \(error)") }

// 2. A tall band: left and right parts; the right one moves left.
do {
    let layout = try TrimLayout.make(imageSize: size, band: CGRect(x: 80, y: 0, width: 40, height: 100), settings: straight)
    check(layout.axis == .vertical, "tall band cuts vertically")
    check(layout.bounds.size == CGSize(width: 170, height: 100), "200 - 40 + 10 = 170 wide, got \(layout.bounds)")
    check(layout.parts[1].offset == CGVector(dx: -30, dy: 0), "right part moves left by 30")
} catch { check(false, "tall band threw \(error)") }

// 3. A band reaching the top keeps the top only (the covered side).
do {
    let layout = try TrimLayout.make(imageSize: size, band: CGRect(x: 0, y: 0, width: 200, height: 30), settings: straight)
    check(layout.keepsOneSide, "band at the top keeps one side")
    check(layout.parts.count == 1, "one part")
    check(layout.bounds == CGRect(x: 0, y: 0, width: 200, height: 30), "kept area is the band, got \(layout.bounds)")
    let bottom = try TrimLayout.make(imageSize: size, band: CGRect(x: 0, y: 70, width: 200, height: 30), settings: straight)
    check(bottom.bounds == CGRect(x: 0, y: 70, width: 200, height: 30), "band at the bottom keeps the bottom, got \(bottom.bounds)")
    let output = TrimRenderer.render(halves, layout: bottom, settings: straight)!
    check(output.height == 30 && pixel(output, 5, 5) == [0, 0, 255, 255], "bottom part rendered from y 70")
} catch { check(false, "one-side band threw \(error)") }

// 4. A band from end to end cannot be cut.
do {
    _ = try TrimLayout.make(imageSize: size, band: CGRect(x: 0, y: 0, width: 200, height: 100), settings: straight)
    check(false, "whole image band should throw")
} catch let error as TrimLayoutError {
    check(error == .coversWholeImage(.horizontal), "whole image band error")
} catch { check(false, "unexpected error \(error)") }
check((try? TrimLayout.make(imageSize: size, band: .zero, settings: straight)) == nil, "empty band throws")

// 5. The band's width trims the image (and the cross scale widens it from the center).
do {
    let layout = try TrimLayout.make(imageSize: size, band: CGRect(x: 50, y: 40, width: 100, height: 20), settings: straight)
    check(layout.bounds == CGRect(x: 50, y: 0, width: 100, height: 90), "trimmed to the band width, got \(layout.bounds)")
    var wider = straight; wider.maskCrossScale = 150
    let widened = try TrimLayout.make(imageSize: size, band: CGRect(x: 50, y: 40, width: 100, height: 20), settings: wider)
    check(widened.bounds == CGRect(x: 25, y: 0, width: 150, height: 90), "150% across, got \(widened.bounds)")
    var taller = straight; taller.maskScale = 200
    let removedMore = try TrimLayout.make(imageSize: size, band: CGRect(x: 0, y: 40, width: 200, height: 20), settings: taller)
    check(removedMore.bounds.height == 100 - 40 + 10, "200% removes 40, got \(removedMore.bounds)")
    var moved = straight; moved.maskOffset = 10
    let offsetLayout = try TrimLayout.make(imageSize: size, band: CGRect(x: 0, y: 40, width: 200, height: 20), settings: moved)
    check(offsetLayout.cutLines[0].first?.y == 50, "offset +10 moves the cut down")
} catch { check(false, "trim checks threw \(error)") }

// 6. Break lines sit on the cut edges, move with the lower part, and are black.
do {
    var ruled = straight; ruled.addRule = true; ruled.ruleWidth = 2
    let layout = try TrimLayout.make(imageSize: size, band: CGRect(x: 0, y: 40, width: 200, height: 20), settings: ruled)
    check(layout.rules.count == 2, "two break lines")
    check(layout.rules[0].allSatisfy { $0.y == 40 } && layout.rules[1].allSatisfy { $0.y == 50 }, "lines at the cut edges")
    let output = TrimRenderer.render(halves, layout: layout, settings: ruled)!
    check(pixel(output, 100, 40) == [0, 0, 0, 255], "upper break line is black")
    check(pixel(output, 100, 50) == [0, 0, 0, 255], "lower break line is black")
    check(pixel(output, 100, 45)[3] == 0, "gap between the lines stays transparent")
    var round = ruled; round.roundCap = true; round.ruleWidth = 6
    let capped = try TrimLayout.make(imageSize: size, band: CGRect(x: 50, y: 40, width: 100, height: 20), settings: round)
    check(capped.bounds.minX == 47 && capped.bounds.maxX == 153, "round caps widen the canvas, got \(capped.bounds)")
    var curvedRule = ruled; curvedRule.warpPercent = 3; curvedRule.ruleWidth = 1
    let butt = try TrimLayout.make(imageSize: size, band: CGRect(x: 0, y: 40, width: 200, height: 20), settings: curvedRule)
    check(butt.bounds.minX == 0 && butt.bounds.width == 200, "butt caps on a curved edge keep the band width, got \(butt.bounds)")
    check(abs(TrimLayout.dashLength([CGPoint(x: 0, y: 0), CGPoint(x: 390, y: 0)], segments: 20) - 10) < 0.0001, "dash = length / (2n - 1)")
} catch { check(false, "rule checks threw \(error)") }

// 6b. The break line color (sRGB with opacity) and its "#RRGGBBAA" form.
do {
    var colored = straight; colored.addRule = true; colored.ruleWidth = 2; colored.ruleColor = RuleColor(red: 1, green: 0, blue: 0, alpha: 1)
    let layout = try TrimLayout.make(imageSize: size, band: CGRect(x: 0, y: 40, width: 200, height: 20), settings: colored)
    let output = TrimRenderer.render(halves, layout: layout, settings: colored)!
    check(pixel(output, 100, 50) == [255, 0, 0, 255], "red break line on blue, got \(pixel(output, 100, 50))")
    check(RuleColor(hex: "#FF000080")?.hex == "#FF000080" && RuleColor(hex: "00FF00")?.alpha == 1 && RuleColor(hex: "nope") == nil, "hex round-trip")
} catch { check(false, "color checks threw \(error)") }

// 6c. A background color fills the gap; the parts are drawn over it.
do {
    let layout = try TrimLayout.make(imageSize: size, band: CGRect(x: 0, y: 40, width: 200, height: 20), settings: straight)
    let output = TrimRenderer.render(halves, layout: layout, settings: straight, background: CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))!
    check(pixel(output, 100, 45) == [255, 255, 255, 255], "the gap is white, got \(pixel(output, 100, 45))")
    check(pixel(output, 100, 20) == [255, 0, 0, 255], "top part stays red over the background")
} catch { check(false, "background checks threw \(error)") }

// 7. Edge profiles are centered on the cut.
for style in CutStyle.allCases {
    var settings = TrimSettings(); settings.cutStyle = style; settings.warpPercent = 10
    let profile = TrimLayout.edgeProfile(settings, crossLength: 200, axisSize: 100)
    let offsets = profile.map(\.offset)
    check(abs((offsets.min()! + offsets.max()!)) < 0.0001, "\(style) profile is centered")
    check(profile.first?.ratio == 0 && profile.last?.ratio == 1, "\(style) runs across the whole band")
    check(offsets.max()! > 0, "\(style) bends")
}
do {
    var jagged = TrimSettings(); jagged.cutStyle = .jagged; jagged.jaggedRidges = 4; jagged.jaggedSize = 3
    check(TrimLayout.edgeProfile(jagged, crossLength: 100, axisSize: 100).count == 6, "4 ridges: 6 points")
    jagged.jaggedRidges = 0
    check(TrimLayout.edgeProfile(jagged, crossLength: 100, axisSize: 100).map(\.offset) == [0, 0], "0 ridges is straight")
    var flag = TrimSettings(); flag.warpPercent = 10
    let amplitude = TrimLayout.edgeProfile(flag, crossLength: 100, axisSize: 100).map(\.offset).max()!
    check(abs(amplitude - 5) < 0.01, "flag 10% of 100 px: amplitude 5, got \(amplitude)")
    // The two parts of a curved cut still mesh: the same edge, moved by the closing distance.
    var curved = TrimSettings(); curved.addRule = false; curved.gap = 0
    let layout = try TrimLayout.make(imageSize: size, band: CGRect(x: 0, y: 40, width: 200, height: 20), settings: curved)
    let upper = layout.cutLines[0], lower = layout.cutLines[1].map { CGPoint(x: $0.x, y: $0.y + layout.parts[1].offset.dy) }
    check(zip(upper, lower).allSatisfy { abs($0.y - $1.y) < 0.0001 && $0.x == $1.x }, "curved edges mesh at gap 0")
} catch { check(false, "profile checks threw \(error)") }

// 8. Transparency in the source is kept, and PNG data round-trips with its alpha and resolution.
do {
    let holed = makeImage(100, 100) { context in
        context.setFillColor(red); context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        context.clear(CGRect(x: 0, y: 0, width: 20, height: 20))
    }
    let layout = try TrimLayout.make(imageSize: CGSize(width: 100, height: 100), band: CGRect(x: 0, y: 45, width: 100, height: 10), settings: straight)
    let output = TrimRenderer.render(holed, layout: layout, settings: straight)!
    check(pixel(output, 5, 5)[3] == 0, "transparent corner stays transparent")
    let data = try TrimRenderer.fileData(output, format: .png, properties: [kCGImagePropertyDPIWidth: 144, kCGImagePropertyDPIHeight: 144])
    let reloaded = try SourceImage.load(data: data)
    check(reloaded.size == CGSize(width: output.width, height: output.height), "PNG keeps the size")
    check(reloaded.image.alphaInfo != .none && reloaded.image.alphaInfo != .noneSkipLast && reloaded.image.alphaInfo != .noneSkipFirst, "PNG keeps alpha")
    check((reloaded.properties[kCGImagePropertyDPIWidth] as? NSNumber)?.intValue == 144, "PNG keeps 144 dpi")
    check(pixel(reloaded.image, 5, 5)[3] == 0 && pixel(reloaded.image, 50, 80)[3] == 255, "PNG pixels round-trip")
    // PSD keeps the alpha and the resolution too; JPEG keeps the resolution and the color.
    let psd = try SourceImage.load(data: TrimRenderer.fileData(output, format: .psd, properties: [kCGImagePropertyDPIWidth: 144, kCGImagePropertyDPIHeight: 144]))
    check(psd.size == reloaded.size && pixel(psd.image, 5, 5)[3] == 0 && pixel(psd.image, 50, 80) == [255, 0, 0, 255], "PSD keeps size and alpha")
    check((psd.properties[kCGImagePropertyDPIWidth] as? NSNumber)?.intValue == 144, "PSD keeps 144 dpi")
    let white = TrimRenderer.render(holed, layout: layout, settings: straight, background: CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))!
    let jpeg = try SourceImage.load(data: TrimRenderer.fileData(white, format: .jpeg, properties: [kCGImagePropertyDPIWidth: 144, kCGImagePropertyDPIHeight: 144]))
    check(jpeg.size == reloaded.size && pixel(jpeg.image, 5, 5).allSatisfy { $0 > 240 } && pixel(jpeg.image, 50, 80)[0] > 240, "JPEG keeps size, white corner, red body")
    check((jpeg.properties[kCGImagePropertyDPIWidth] as? NSNumber)?.intValue == 144, "JPEG keeps 144 dpi")
    check(OutputFormat.allCases.map(\.fileExtension) == ["png", "jpg", "psd"] && !OutputFormat.jpeg.keepsTransparency, "format extensions")
} catch { check(false, "transparency checks threw \(error)") }

// 9. Out-of-range settings are clamped like the script's dialog.
do {
    var wild = TrimSettings()
    wild.maskScale = 0; wild.warpPercent = 500; wild.jaggedRidges = 999; wild.gap = -4; wild.dashSegments = 0; wild.ruleWidth = .nan
    let clamped = wild.clamped()
    check(clamped.maskScale == 1 && clamped.warpPercent == 100 && clamped.jaggedRidges == 100, "upper and lower limits")
    check(clamped.gap == 0 && clamped.dashSegments == 1 && clamped.ruleWidth == 1, "gap, segments and NaN")
}

// 10. A large image renders within a reasonable time.
do {
    let big = makeImage(4000, 3000) { $0.setFillColor(red); $0.fill(CGRect(x: 0, y: 0, width: 4000, height: 3000)) }
    var settings = TrimSettings(); settings.ruleDashed = true
    let start = Date()
    let layout = try TrimLayout.make(imageSize: CGSize(width: 4000, height: 3000), band: CGRect(x: 0, y: 1200, width: 4000, height: 400), settings: settings)
    let output = TrimRenderer.render(big, layout: layout, settings: settings)
    let elapsed = Date().timeIntervalSince(start)
    check(output != nil, "4000×3000 renders")
    print(String(format: "  4000×3000 render: %.2f s", elapsed))
} catch { check(false, "large image threw \(error)") }

print(failures == 0 ? "PASS \(passes) checks" : "FAILED \(failures) of \(passes + failures)")
exit(failures == 0 ? 0 : 1)
