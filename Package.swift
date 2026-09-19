// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Medha",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Medha", targets: ["Medha"]),
        .executable(name: "MedhaTestRunner", targets: ["MedhaTestRunner"]),
        .library(name: "MedhaKit", targets: ["MedhaKit"])
    ],
    dependencies: [
        .package(path: "Packages/GRDB")
    ],
    targets: [
        .target(
            name: "MedhaKit",
            dependencies: [
                .product(name: "GRDB", package: "GRDB")
            ],
            path: "Sources/MedhaKit"
        ),
        .executableTarget(
            name: "Medha",
            dependencies: [
                "MedhaKit"
            ],
            path: "Sources/MedhaApp"
        ),
        .executableTarget(
            name: "MedhaTestRunner",
            dependencies: [
                "MedhaKit"
            ],
            path: "Sources/MedhaTestRunner"
        )
    ]
)
