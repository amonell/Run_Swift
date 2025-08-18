// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VirtualRunningCompanionModels",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "VirtualRunningCompanionModels",
            targets: ["VirtualRunningCompanionModels"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "VirtualRunningCompanionModels",
            dependencies: [],
            path: "VirtualRunningCompanion/Models"
        ),
        .testTarget(
            name: "VirtualRunningCompanionModelsTests",
            dependencies: ["VirtualRunningCompanionModels"],
            path: "Tests/VirtualRunningCompanionTests"
        ),
    ]
)