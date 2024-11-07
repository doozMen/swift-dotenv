// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "swift-dotenv",
  platforms: [.iOS(.v13), .macOS(.v13)],
  products: [
    .library(
      name: "SwiftDotenv",
      targets: ["SwiftDotenv"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0")
  ],
  targets: [
    .target(
      name: "SwiftDotenv",
      dependencies: [
        .product(name: "Logging", package: "swift-log")
      ],
      path: "Sources"
    ),
    .testTarget(
      name: "SwiftDotenvTests",
      dependencies: ["SwiftDotenv"],
      path: "Tests",
      resources: [
        .process("Resources")
      ]
    ),
  ]
)
