// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MoreApps",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8)
    ],
    products: [
        .library(
            name: "MoreApps",
            targets: ["MoreApps"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MoreApps",
            resources: [
                .process("Resources")
            ]),
        .testTarget(
            name: "MoreAppsTests",
            dependencies: ["MoreApps"],
            path: "Tests"),
    ]
) 
