import AppKit
// Separates the front sheet from the rear one with a tile-colored gap (only where it covers the rear sheet).
let input = URL(fileURLWithPath: CommandLine.arguments[1]), output = URL(fileURLWithPath: CommandLine.arguments[2])
let gap = Double(CommandLine.arguments.count > 3 ? CommandLine.arguments[3] : "20")!
let rep = NSBitmapImageRep(data: try! Data(contentsOf: input))!
let (left, top, right, bottom, radius) = (438.0, 378.0, 930.0, 985.0, 70.0)
func distance(_ x: Double, _ y: Double) -> Double {   // signed distance to the front sheet (outside > 0)
    let cx = (left + right) / 2, cy = (top + bottom) / 2, hx = (right - left) / 2, hy = (bottom - top) / 2
    let qx = abs(x - cx) - hx + radius, qy = abs(y - cy) - hy + radius
    return hypot(max(qx, 0), max(qy, 0)) + min(max(qx, qy), 0) - radius
}
var p = [Int](repeating: 0, count: 4), t = [Int](repeating: 0, count: 4)
for y in 330...860 {
    rep.getPixel(&t, atX: 300, y: y)               // tile color on the same row, left of the rear sheet
    for x in 380...790 {
        let d = distance(Double(x) + 0.5, Double(y) + 0.5)
        guard d > 0, d < gap + 1 else { continue }
        rep.getPixel(&p, atX: x, y: y)
        guard min(p[0], p[1], p[2]) > 150 else { continue }   // rear sheet or its shadow, not the tile
        let alpha = min(1, gap + 1 - d) * min(1, d)          // soft outer edge; d<1 blends with the front edge
        var out = p
        for i in 0..<3 { out[i] = Int((Double(p[i]) * (1 - alpha) + Double(t[i]) * alpha).rounded()) }
        rep.setPixel(&out, atX: x, y: y)
    }
}
try! rep.representation(using: .png, properties: [:])!.write(to: output)
