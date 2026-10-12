// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Toki",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Toki", targets: ["Toki"])],
    targets: [.executableTarget(name: "Toki")]
)
