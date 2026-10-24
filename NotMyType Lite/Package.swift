// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotMyTypeLite",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "NotMyTypeLite", targets: ["NotMyTypeLite"])
    ],
    targets: [
        .executableTarget(
            name: "NotMyTypeLite",
            path: "Sources/NotMyTypeLite"
        )
    ]
)
