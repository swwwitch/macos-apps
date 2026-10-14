// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MarkdownKitchen",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MarkdownKitchen", targets: ["MarkdownKitchen"])
    ],
    targets: [
        .executableTarget(
            name: "MarkdownKitchen",
            path: "Sources/MarkdownKitchen"
        )
    ]
)
