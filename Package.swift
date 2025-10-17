// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Signals",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .watchOS(.v10),
        .tvOS(.v17),
    ],
    products: [
        .library(
            name: "Signals",
            targets: ["Signals"],
        ),
    ],
    targets: [
        .target(
            name: "Signals",
        ),
        .testTarget(
            name: "SignalsTests",
            dependencies: ["Signals"],
        ),
    ]
)
