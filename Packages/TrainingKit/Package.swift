// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TrainingKit",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "TrainingCore", targets: ["TrainingCore"]),
        .library(name: "GarminAPI", targets: ["GarminAPI"]),
        .library(name: "FITReader", targets: ["FITReader"]),
        .library(name: "Metrics", targets: ["Metrics"]),
        .library(name: "Projections", targets: ["Projections"]),
        .library(name: "Storage", targets: ["Storage"]),
        .library(name: "Sync", targets: ["Sync"]),
    ],
    dependencies: [
        .package(url: "https://github.com/garmin/fit-swift-sdk.git", from: "21.221.0"),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.20"),
    ],
    targets: [
        .target(name: "TrainingCore"),
        .target(name: "GarminAPI", dependencies: ["TrainingCore"]),
        .target(name: "FITReader", dependencies: [
            "TrainingCore",
            .product(name: "FITSwiftSDK", package: "fit-swift-sdk"),
            .product(name: "ZIPFoundation", package: "ZIPFoundation"),
        ]),
        .target(name: "Metrics", dependencies: ["TrainingCore", "FITReader"]),
        .target(name: "Projections", dependencies: ["TrainingCore"]),
        .target(name: "Storage", dependencies: ["TrainingCore"]),
        .target(name: "Sync", dependencies: ["TrainingCore", "GarminAPI", "FITReader", "Metrics", "Projections", "Storage"]),
        .testTarget(name: "TrainingCoreTests", dependencies: ["TrainingCore"]),
        .testTarget(name: "GarminAPITests", dependencies: ["GarminAPI"], resources: [.copy("Fixtures")]),
        .testTarget(name: "FITReaderTests", dependencies: ["FITReader"]),
        .testTarget(name: "MetricsTests", dependencies: ["Metrics"]),
        .testTarget(name: "ProjectionsTests", dependencies: ["Projections"]),
        .testTarget(name: "StorageTests", dependencies: ["Storage"]),
        .testTarget(name: "SyncTests", dependencies: [
            "Sync",
            "TrainingCore",
            "GarminAPI",
            "FITReader",
            "Storage",
            .product(name: "FITSwiftSDK", package: "fit-swift-sdk"),
            .product(name: "ZIPFoundation", package: "ZIPFoundation"),
        ]),
    ]
)
