// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BundleIDInspector",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "BundleIDInspector", targets: ["BundleIDInspector"])
    ],
    targets: [
        .executableTarget(
            name: "BundleIDInspector",
            path: "Sources/BundleIDInspector"
        )
    ]
)
