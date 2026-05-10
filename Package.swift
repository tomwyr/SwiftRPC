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
        // .library(name: "SwiftRPCHummingbird", targets: ["SwiftRPCHummingbird"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "509.0.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
    ],
    targets: [
        .macro(
            name: "SwiftRPCMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "SwiftRPC",
            dependencies: [
                "SwiftRPCMacros"
            ]
        ),
        .executableTarget(
            name: "SwiftRPCHummingbird",
            dependencies: [
                "SwiftRPC",
                "SwiftRPCMacros",
                .product(name: "Hummingbird", package: "hummingbird"),
            ]
        ),
        .testTarget(
            name: "SwiftRPCMacroTests",
            dependencies: [
                "SwiftRPCMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
