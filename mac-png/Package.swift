// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "QuickIconExporter",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "QuickIconExporter", targets: ["QuickIconExporter"])
    ],
    targets: [
        .executableTarget(
            name: "QuickIconExporter",
            path: "Sources/IconDrop"
        ),
        .testTarget(
            name: "IconDropTests",
            dependencies: ["QuickIconExporter"],
            path: "Tests/IconDropTests"
        )
    ]
)
