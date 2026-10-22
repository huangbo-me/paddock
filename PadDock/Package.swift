// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "PadDock", platforms: [.macOS(.v14)], products: [.library(name: "PadDockCore", targets: ["PadDockCore"])], targets: [
    .target(name: "PadDockCore", path: "Sources/Core"),
    .target(name: "PadDockKeychainSupport", path: "Sources/KeychainSupport", publicHeadersPath: "include", linkerSettings: [.linkedFramework("Security")]),
    .target(name: "PadDockStorage", dependencies: ["PadDockCore", "PadDockKeychainSupport"], path: "Sources/Storage"),
    .testTarget(name: "PadDockStorageTests", dependencies: ["PadDockStorage", "PadDockCore"], path: "Tests/PadDockStorageTests"),
    .testTarget(name: "PadDockCoreTests", dependencies: ["PadDockCore"], path: "Tests/PadDockCoreTests")
])
