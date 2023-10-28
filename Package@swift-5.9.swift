// swift-tools-version: 5.9

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
        // Depend on the Swift 5.9 release of SwiftSyntax
        .package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.0"),
    ],
    targets: [
        .target(
            name: "FlyingFox",
            dependencies: ["FlyingSocks", "Macro"],
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
        ),
        .macro(
            name: "Macro",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ],
            path: "Macro/Sources"
        )
    ]
)
