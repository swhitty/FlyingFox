// swift-tools-version:5.5

import PackageDescription

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
    targets: [
        .target(
            name: "FlyingFox",
            dependencies: ["FlyingSocks"],
            path: "FlyingFox/Sources"
        ),
        .testTarget(
            name: "FlyingFoxTests",
            dependencies: ["FlyingFox"],
            path: "FlyingFox/Tests",
            resources: [
                .copy("Stubs")
            ]
        ),
        .target(
            name: "FlyingSocks",
            dependencies: [.target(name: "CSystemLinux", condition: .when(platforms: [.linux]))],
            path: "FlyingSocks/Sources"
        ),
        .testTarget(
            name: "FlyingSocksTests",
            dependencies: ["FlyingSocks"],
            path: "FlyingSocks/Tests",
            resources: [
                .copy("Resources")
            ]
        ),
        .target(
             name: "CSystemLinux",
             path: "CSystemLinux"
        )
    ]
)
