// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Quick",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Quick",
            path: "Sources/Quick",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
