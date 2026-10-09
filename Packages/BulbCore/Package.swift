// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BulbCore",
    platforms: [.iOS("26.0"), .watchOS("26.0"), .macOS(.v15)],
    products: [.library(name: "BulbCore", targets: ["BulbCore"])],
    targets: [
        .target(name: "BulbCore"),
        .testTarget(name: "BulbCoreTests", dependencies: ["BulbCore"])
    ]
)
