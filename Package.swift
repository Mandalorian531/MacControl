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
        .executable(name: "smc-helper", targets: ["SMCHelper"]),
        .executable(name: "MacControlWidgets", targets: ["MacControlWidgets"])
    ],
    targets: [
        .target(
            name: "MacControlCore",
            path: "Sources/MacControlCore",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("AppKit"),
                .linkedFramework("Security")
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
                .linkedFramework("ServiceManagement"),
                .linkedFramework("WidgetKit")
            ]
        ),
        .executableTarget(
            name: "MacControlWidgets",
            dependencies: ["MacControlCore"],
            path: "Sources/MacControlWidgets",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ],
            linkerSettings: [
                .linkedFramework("WidgetKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("AppKit"),
                .unsafeFlags([
                    "-Xlinker", "-e",
                    "-Xlinker", "_NSExtensionMain"
                ])
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
