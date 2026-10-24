// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotMyType",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "NotMyType", targets: ["NotMyType"])
    ],
    targets: [
        .executableTarget(
            name: "NotMyType",
            path: "Sources/NotMyType"
        )
    ]
)
