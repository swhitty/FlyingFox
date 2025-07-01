// swift-tools-version:5.10

import PackageDescription

let package = Package(
    name: "FlyingFox",
    platforms: [
        .macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v8)
    ],
    products: [
        .library(
            name: "FlyingFox",
            targets: ["FlyingFox"]
        ),
        .library(
            name: "FlyingSocks",
            targets: ["FlyingSocks"]
        )
    ],
    targets: [
        .target(
            name: "FlyingFox",
            dependencies: ["FlyingSocks"],
            path: "FlyingFox/Sources",
            exclude: .excludeFiles,
            swiftSettings: .upcomingFeatures
        ),
        .testTarget(
            name: "FlyingFoxXCTests",
            dependencies: ["FlyingFox"],
            path: "FlyingFox/XCTests",
            resources: [
                .copy("Stubs")
            ],
            swiftSettings: .upcomingFeatures
        ),
        .target(
            name: "FlyingSocks",
            dependencies: [.target(name: "CSystemLinux", condition: .when(platforms: [.linux]))],
            path: "FlyingSocks/Sources",
            swiftSettings: .upcomingFeatures
        ),
        .testTarget(
            name: "FlyingSocksXCTests",
            dependencies: ["FlyingSocks"],
            path: "FlyingSocks/XCTests",
            resources: [
                .copy("Resources")
            ],
            swiftSettings: .upcomingFeatures
        ),
        .target(
             name: "CSystemLinux",
             path: "CSystemLinux"
        )
    ]
)

extension Array where Element == String {
    static var excludeFiles: [String] {
        #if os(Linux)
        ["JSONPredicatePattern.swift"]
        #else
        []
        #endif
    }
}

extension Array where Element == SwiftSetting {

    static var upcomingFeatures: [SwiftSetting] {
        [
            .enableUpcomingFeature("BareSlashRegexLiterals"),
            .enableUpcomingFeature("ConciseMagicFile"),
            .enableUpcomingFeature("DeprecateApplicationMain"),
            .enableUpcomingFeature("DisableOutwardActorInference"),
            .enableUpcomingFeature("ExistentialAny"),
            .enableUpcomingFeature("ForwardTrailingClosures"),
            .enableUpcomingFeature("GlobalConcurrency"),
            .enableUpcomingFeature("ImportObjcForwardDeclarations"),
            .enableUpcomingFeature("IsolatedDefaultValues"),
            //.enableExperimentalFeature("StrictConcurrency")
        ]
    }
}
