// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SiteMirror",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "SiteMirror", targets: ["SiteMirror"])
    ],
    targets: [
        .executableTarget(
            name: "SiteMirror",
            path: "Sources/SiteMirror"
        )
    ]
)
