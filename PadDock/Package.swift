// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "PadDock", platforms: [.macOS(.v14)], products: [.library(name: "PadDockCore", targets: ["PadDockCore"])], targets: [
    .target(name: "PadDockCore", path: "Sources/Core"),
    .testTarget(name: "PadDockCoreTests", dependencies: ["PadDockCore"], path: "Tests/PadDockCoreTests")
])
