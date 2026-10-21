// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HeatWatch",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "CSensors",
            linkerSettings: [.linkedFramework("IOKit"), .linkedFramework("CoreFoundation")]
        ),
        .target(name: "HeatWatchCore", dependencies: ["CSensors"]),
        .executableTarget(name: "HeatWatch", dependencies: ["HeatWatchCore"]),
        .testTarget(name: "HeatWatchCoreTests", dependencies: ["HeatWatchCore"]),
    ]
)
