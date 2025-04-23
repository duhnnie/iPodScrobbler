// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "iPodScrobbler",
    platforms: [
        .macOS(.v10_15)
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(name: "iPodReader", url: "https://github.com/duhnnie/iPodReader", branch: "main"),
        .package(name: "LastFM.swift", url: "https://github.com/duhnnie/LastFM.swift", from: "1.2.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .executableTarget(
            name: "iPodScrobbler",
            dependencies: [
                .product(name: "iPodReader", package: "iPodReader"),
                .product(name: "LastFM", package: "LastFM.swift")
            ]        ),
        .testTarget(
            name: "iPodScrobblerTests",
            dependencies: ["iPodScrobbler"]),
    ]
)
