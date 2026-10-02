// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "default-app-switcher",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "das", targets: ["DASApp"]),
        .executable(name: "das-helper", targets: ["DASHelper"]),
    ],
    targets: [
        .target(name: "DASCore", path: "Sources/Core"),
        .target(name: "DASCLI", dependencies: ["DASCore"], path: "Sources/CLI"),
        .executableTarget(name: "DASApp", dependencies: ["DASCLI"], path: "Sources/App"),
        .executableTarget(
            name: "DASHelper", dependencies: ["DASCore"], path: "Sources/Helper"),
        .executableTarget(
            name: "DASTests", dependencies: ["DASCore", "DASCLI"],
            path: "Tests/DASTests"),
    ]
)
