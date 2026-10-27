// swift-tools-version: 6.0
import PackageDescription

// shortcut: Swift 5 mode, move to Swift 6 when the panel types are concurrency-checked.
let package = Package(
    name: "IslandBar",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "IslandBar", targets: ["IslandBar"])
    ],
    targets: [
        .target(name: "IslandCore", swiftSettings: [.swiftLanguageMode(.v5)]),
        .executableTarget(
            name: "IslandBar",
            dependencies: ["IslandCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "IslandCoreTests",
            dependencies: ["IslandCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
