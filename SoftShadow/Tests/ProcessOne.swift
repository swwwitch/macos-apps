import Foundation

@main struct ProcessOne {
    static func main() throws {
        let input = URL(fileURLWithPath: CommandLine.arguments[1])
        let result = try ShadowProcessor.process(url: input, addBorderWhenMissing: true, shadowSize: 27)
        print(result.output.path)
    }
}
