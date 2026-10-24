// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FontSwitcher",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "FontSwitcher", targets: ["FontSwitcher"])
    ],
    targets: [
        .executableTarget(
            name: "FontSwitcher",
            path: "Sources/FontSwitcher"
        )
    ]
)
