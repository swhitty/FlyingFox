// swift-tools-version: 5.10

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "FlyingFox",
    platforms: [
        .macOS(.v10_15), .iOS(.v13), .tvOS(.v13)
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
    dependencies: [
        // Depend on the Swift 5.10 release of SwiftSyntax
        .package(url: "https://github.com/apple/swift-syntax.git", from: "510.0.0"),
    ],
    targets: [
        .target(
            name: "FlyingFox",
            dependencies: ["FlyingSocks", "Macro"],
            path: "FlyingFox/Sources",
            swiftSettings: .upcomingFeatures
        ),
        .testTarget(
            name: "FlyingFoxTests",
            dependencies: ["FlyingFox", "Macro"],
            path: "FlyingFox/Tests",
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
            name: "FlyingSocksTests",
            dependencies: ["FlyingSocks"],
            path: "FlyingSocks/Tests",
            resources: [
                .copy("Resources")
            ],
            swiftSettings: .upcomingFeatures
        ),
        .target(
             name: "CSystemLinux",
             path: "CSystemLinux"
        ),
        .macro(
            name: "Macro",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ],
            path: "Macro/Sources",
            swiftSettings: .upcomingFeatures
        )
    ]
)

extension Array where Element == SwiftSetting {

    static var upcomingFeatures: [SwiftSetting] {
        [
            .enableUpcomingFeature("ExistentialAny"),
            //.enableExperimentalFeature("StrictConcurrency")
        ]
    }
}
