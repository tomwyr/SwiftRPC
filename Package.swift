// swift-tools-version: 6.2
import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "SwiftRPC",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "SwiftRPC", targets: ["SwiftRPC"]),
        .library(name: "SwiftRPCHummingbird", targets: ["SwiftRPCHummingbird"]),
        .library(name: "SwiftRPCVapor", targets: ["SwiftRPCVapor"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "602.0.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.115.1"),
        .package(url: "https://github.com/pointfreeco/swift-macro-testing", from: "0.6.5"),
        // https://github.com/pointfreeco/swift-snapshot-testing/issues/1085
        // Pinned to work around swift-macro-testing build issue:
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", exact: "1.18.9"),
    ],
    targets: [
        .macro(
            name: "SwiftRPCMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
            ],
        ),
        .target(
            name: "SwiftRPC",
            dependencies: ["SwiftRPCMacros"],
        ),
        .target(
            name: "SwiftRPCHummingbird",
            dependencies: [
                "SwiftRPC",
                .product(name: "Hummingbird", package: "hummingbird"),
            ],
        ),
        .target(
            name: "SwiftRPCVapor",
            dependencies: [
                "SwiftRPC",
                .product(name: "Vapor", package: "vapor"),
            ],
        ),
        .executableTarget(
            name: "SwiftRPCExamples",
            dependencies: [
                "SwiftRPC",
                "SwiftRPCMacros",
                "SwiftRPCHummingbird",
                "SwiftRPCVapor",
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "Vapor", package: "vapor"),
            ],
        ),
        .testTarget(
            name: "SwiftRPCMacrosTests",
            dependencies: [
                "SwiftRPCMacros",
                .product(name: "MacroTesting", package: "swift-macro-testing"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ],
        ),
        .testTarget(
            name: "SwiftRPCTests",
            dependencies: ["SwiftRPC"],
        ),
        .testTarget(
            name: "SwiftRPCHummingbirdTests",
            dependencies: [
                "SwiftRPC",
                "SwiftRPCHummingbird",
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdTesting", package: "hummingbird"),
            ],
        ),
        .testTarget(
            name: "SwiftRPCVaporTests",
            dependencies: [
                "SwiftRPC",
                "SwiftRPCVapor",
                .product(name: "Vapor", package: "vapor"),
                .product(name: "VaporTesting", package: "vapor"),
            ],
        ),
        .testTarget(
            name: "SwiftRPCIntegrationTests",
            dependencies: [
                "SwiftRPC",
                "SwiftRPCHummingbird",
                "SwiftRPCVapor",
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "Vapor", package: "vapor"),
            ],
        ),
    ],
)
