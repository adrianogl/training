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
        .library(name: "Reports", targets: ["Reports"]),
        .library(name: "WorkoutAnalysis", targets: ["WorkoutAnalysis"]),
        .library(name: "Narrative", targets: ["Narrative"]),
        .library(name: "Insights", targets: ["Insights"]),
        .library(name: "RemoteSync", targets: ["RemoteSync"]),
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
        .target(name: "Reports", dependencies: ["TrainingCore", "FITReader", "Metrics", "Storage"]),
        .target(name: "WorkoutAnalysis", dependencies: ["TrainingCore", "FITReader"]),
        .target(name: "Narrative", dependencies: ["WorkoutAnalysis", "Metrics"]),
        .target(name: "Insights", dependencies: [
            "TrainingCore", "FITReader", "Metrics", "Projections", "Storage", "Sync", "Reports", "WorkoutAnalysis", "Narrative",
        ]),
        .target(name: "RemoteSync", dependencies: ["Storage", "GarminAPI", "Metrics"]),
        .executableTarget(name: "trainingctl", dependencies: ["TrainingCore", "GarminAPI", "Storage", "Sync", "Reports"]),
        .testTarget(name: "TrainingCoreTests", dependencies: ["TrainingCore"]),
        .testTarget(name: "GarminAPITests", dependencies: ["GarminAPI"], resources: [.copy("Fixtures")]),
        .testTarget(name: "FITReaderTests", dependencies: ["FITReader"]),
        .testTarget(name: "MetricsTests", dependencies: ["Metrics"]),
        .testTarget(name: "ProjectionsTests", dependencies: ["Projections"]),
        .testTarget(name: "StorageTests", dependencies: ["Storage"]),
        .testTarget(name: "WorkoutAnalysisTests", dependencies: ["WorkoutAnalysis", "FITReader", "TrainingCore"]),
        .testTarget(name: "NarrativeTests", dependencies: ["Narrative", "WorkoutAnalysis", "Metrics"]),
        .testTarget(name: "InsightsTests", dependencies: [
            "Insights", "TrainingCore", "FITReader", "Metrics", "Projections", "Storage", "Reports", "Narrative", "Sync",
        ]),
        .testTarget(name: "ReportsTests", dependencies: ["Reports", "Storage", "Metrics", "TrainingCore"]),
        .testTarget(name: "RemoteSyncTests", dependencies: ["RemoteSync", "Storage", "GarminAPI", "Metrics"]),
        .testTarget(name: "trainingctlTests", dependencies: ["trainingctl", "Sync"]),
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
