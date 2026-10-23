// swift-tools-version:5.9
// ZikrKit — нативный слой данных Zikr Adventure (ZKR-49).
// Только Foundation (+ os под #if canImport(os)); без сторонних зависимостей.
import PackageDescription

let strict: [SwiftSetting] = [.enableExperimentalFeature("StrictConcurrency")]

let package = Package(
    name: "ZikrKit",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "ZikrCore", targets: ["ZikrCore"]),
        .library(name: "ZikrDomain", targets: ["ZikrDomain"]),
        .library(name: "ZikrPersistence", targets: ["ZikrPersistence"]),
    ],
    targets: [
        .target(name: "ZikrCore", swiftSettings: strict),
        .target(name: "ZikrDomain", dependencies: ["ZikrCore"], swiftSettings: strict),
        .target(name: "ZikrPersistence", dependencies: ["ZikrCore", "ZikrDomain"], swiftSettings: strict),
        .testTarget(name: "ZikrCoreTests", dependencies: ["ZikrCore"]),
        .testTarget(name: "ZikrDomainTests", dependencies: ["ZikrDomain"]),
        .testTarget(
            name: "ZikrPersistenceTests",
            dependencies: ["ZikrPersistence", "ZikrDomain", "ZikrCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
