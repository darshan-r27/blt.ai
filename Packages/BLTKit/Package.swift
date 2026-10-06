// swift-tools-version: 6.4
import PackageDescription

let strictWarnings: [SwiftSetting] = [.treatAllWarnings(as: .error)]

let package = Package(
    name: "BLTKit",
    platforms: [.iOS(.v27)],
    products: [
        .library(name: "BLTCore", targets: ["BLTCore"]),
        .library(name: "BLTCatalog", targets: ["BLTCatalog"]),
        .library(name: "BLTProgress", targets: ["BLTProgress"]),
        .library(name: "BLTSession", targets: ["BLTSession"]),
        .library(name: "BLTDesign", targets: ["BLTDesign"]),
        .library(name: "BLTFeatures", targets: ["BLTFeatures"]),
    ],
    targets: [
        .target(name: "BLTCore", swiftSettings: strictWarnings),
        .target(name: "BLTCatalog", dependencies: ["BLTCore"], swiftSettings: strictWarnings),
        .target(name: "BLTProgress", dependencies: ["BLTCore"], swiftSettings: strictWarnings),
        .target(name: "BLTSession", dependencies: ["BLTCore", "BLTCatalog", "BLTProgress"], swiftSettings: strictWarnings),
        .target(name: "BLTDesign", dependencies: ["BLTCore"], swiftSettings: strictWarnings),
        .target(
            name: "BLTFeatures",
            dependencies: ["BLTCore", "BLTCatalog", "BLTProgress", "BLTSession", "BLTDesign"],
            swiftSettings: strictWarnings
        ),
        .testTarget(name: "BLTCoreTests", dependencies: ["BLTCore"], swiftSettings: strictWarnings),
        .testTarget(
            name: "BLTCatalogTests",
            dependencies: ["BLTCatalog", "BLTCore"],
            resources: [.copy("Fixtures")],
            swiftSettings: strictWarnings
        ),
        .testTarget(name: "BLTProgressTests", dependencies: ["BLTProgress", "BLTCore"], swiftSettings: strictWarnings),
        .testTarget(
            name: "BLTSessionTests",
            dependencies: ["BLTSession", "BLTCatalog", "BLTCore"],
            swiftSettings: strictWarnings
        ),
        .testTarget(name: "BLTDesignTests", dependencies: ["BLTDesign", "BLTCore"], swiftSettings: strictWarnings),
        .testTarget(
            name: "BLTFeaturesTests",
            dependencies: ["BLTFeatures", "BLTCatalog", "BLTCore", "BLTProgress", "BLTSession", "BLTDesign"],
            swiftSettings: strictWarnings
        ),
        .testTarget(name: "BLTContentTests", dependencies: ["BLTCatalog", "BLTCore"], swiftSettings: strictWarnings),
    ],
    swiftLanguageModes: [.v6]
)
