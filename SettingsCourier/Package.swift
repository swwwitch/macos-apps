// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SettingsCourier",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "SettingsCourier", targets: ["SettingsCourier"])
    ],
    targets: [
        .executableTarget(
            name: "SettingsCourier",
            path: "Sources/SettingsCourier"
        )
    ]
)
