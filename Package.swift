// swift-tools-version:6.0

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
            swiftSettings: .upcomingFeatures
        ),
        .testTarget(
            name: "FlyingFoxTests",
            dependencies: ["FlyingFox"],
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
        )
    ]
)

extension Array where Element == SwiftSetting {

    static var upcomingFeatures: [SwiftSetting] {
        [
            .enableUpcomingFeature("ExistentialAny"),
            .swiftLanguageMode(.v6)
        ]
    }
}
