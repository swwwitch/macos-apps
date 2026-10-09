// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PrefsPreset",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "PrefsPreset", targets: ["PrefsPreset"])
    ],
    targets: [
        .executableTarget(
            name: "PrefsPreset",
            path: "Sources/PrefsPreset",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
