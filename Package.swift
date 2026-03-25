// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "JazzHands",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "JazzHands",
            path: "Orbit/Sources",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("Carbon"),
            ]
        ),
    ]
)
