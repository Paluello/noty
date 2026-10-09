// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "NotyKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "NotyCore", targets: ["NotyCore"]),
        .library(name: "NotyCanvas", targets: ["NotyCanvas"]),
    ],
    targets: [
        // Model and .noty file format. No UI dependencies (ADR-0002, ADR-0016).
        .target(name: "NotyCore"),
        // Notebook editor: PencilKit canvases, paper, tools.
        .target(name: "NotyCanvas", dependencies: ["NotyCore"]),
        .testTarget(name: "NotyCoreTests", dependencies: ["NotyCore"]),
    ]
)
