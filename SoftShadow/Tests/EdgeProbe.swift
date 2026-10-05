import AppKit
import ImageIO

func inspect(_ path: String) {
    let url = URL(fileURLWithPath: path)
    let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
    let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
    let row = image.width * 4
    var bytes = [UInt8](repeating: 0, count: row * image.height)
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: &bytes, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: row, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)!
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    func a(_ x: Int, _ y: Int) -> Int { Int(bytes[y * row + x * 4 + 3]) }
    var minX=image.width, minY=image.height, maxX=0, maxY=0
    for y in 0..<image.height { for x in 0..<image.width where a(x,y) >= 245 { minX=min(minX,x); minY=min(minY,y); maxX=max(maxX,x); maxY=max(maxY,y) } }
    print("\(url.lastPathComponent) \(image.width)x\(image.height) opaque=(\(minX),\(minY))-(\(maxX),\(maxY))")
    let midX=(minX+maxX)/2, midY=(minY+maxY)/2
    print(" left alpha:", (max(0,minX-4)...min(image.width-1,minX+4)).map { a($0,midY) })
    print(" right alpha:", (max(0,maxX-4)...min(image.width-1,maxX+4)).map { a($0,midY) })
    print(" bottom alpha:", (max(0,minY-4)...min(image.height-1,minY+4)).map { a(midX,$0) })
    print(" top alpha:", (max(0,maxY-4)...min(image.height-1,maxY+4)).map { a(midX,$0) })
    func rgba(_ x: Int, _ y: Int) -> [Int] { let o=y*row+x*4; return [Int(bytes[o]),Int(bytes[o+1]),Int(bytes[o+2]),Int(bytes[o+3])] }
    print(" edge RGBA L/R/B/T:", rgba(minX,midY), rgba(maxX,midY), rgba(midX,minY), rgba(midX,maxY))
    print(" inside RGBA L/R/B/T:", rgba(minX+1,midY), rgba(maxX-1,midY), rgba(midX,minY+1), rgba(midX,maxY-1))
    print(" corner RGBA TL/TR/BL/BR:", rgba(0, image.height - 1), rgba(image.width - 1, image.height - 1), rgba(0, 0), rgba(image.width - 1, 0))
    let probes = [0, 1, 2, 4, 8, 12, 16, 20, 24, 28, 32]
    print(" top-left diagonal alpha:", probes.filter { $0 < min(image.width, image.height) }.map { a($0, image.height - 1 - $0) })
    print(" content TL diagonal alpha:", probes.filter { minX + $0 < image.width && maxY - $0 >= 0 }.map { a(minX + $0, maxY - $0) })
}

@main struct EdgeProbe { static func main() { for path in CommandLine.arguments.dropFirst() { inspect(path) } } }
