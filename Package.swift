// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MacControl",
    defaultLocalization: "fr",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MacControl", targets: ["MacControl"]),
        .executable(name: "smc-helper", targets: ["SMCHelper"])
    ],
    targets: [
        .target(
            name: "MacControlCore",
            path: "Sources/MacControlCore",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("AppKit")
            ]
        ),
        .executableTarget(
            name: "MacControl",
            dependencies: ["MacControlCore"],
            path: "Sources/MacControl",
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("AppKit"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .executableTarget(
            name: "SMCHelper",
            dependencies: ["MacControlCore"],
            path: "Sources/SMCHelper",
            linkerSettings: [
                .linkedFramework("IOKit")
            ]
        )
    ]
)
