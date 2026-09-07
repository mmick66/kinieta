// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Kinieta",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "Kinieta", targets: ["Kinieta"])
    ],
    targets: [
        .target(
            name: "Kinieta",
            path: "Sources/Kinieta"
        ),
        .testTarget(
            name: "KinietaTests",
            dependencies: ["Kinieta"],
            path: "Tests/KinietaTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
