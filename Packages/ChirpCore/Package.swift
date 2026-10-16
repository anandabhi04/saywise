// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChirpCore",
    platforms: [.macOS(.v15)],
    products: [.library(name: "ChirpCore", targets: ["ChirpCore"])],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.11.0"),
    ],
    targets: [
        .target(name: "ChirpCore", dependencies: [.product(name: "GRDB", package: "GRDB.swift")]),
        .testTarget(name: "ChirpCoreTests", dependencies: ["ChirpCore"]),
    ]
)
