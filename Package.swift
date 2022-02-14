// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "FlyingFox",
	  platforms: [
	       .macOS(.v10_15), .iOS(.v13),
	    ],
    products: [
		.library(
            name: "FlyingFox",
            targets: ["FlyingFox"]
		)
    ],
    targets: [
        .target(
            name: "FlyingFox",
			path: "Sources"
		),
        .testTarget(
            name: "FlyingFoxTests",
			dependencies: ["FlyingFox"],
			path: "Tests"
		)
    ]
)
