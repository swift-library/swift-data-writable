// swift-tools-version: 6.2
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import PackageDescription

let package = Package(
  name: "ReleaseConsumer",
  platforms: [.iOS(.v18), .macOS(.v15), .tvOS(.v18), .watchOS(.v11)],
  products: [.library(name: "ReleaseConsumer", targets: ["ReleaseConsumer"])],
  dependencies: [
    .package(
      url: "https://github.com/swift-library/swift-data-writable.git", revision: "release-candidate"
    )
  ],
  targets: [
    .target(
      name: "ReleaseConsumer",
      dependencies: [.product(name: "SwiftDataWritable", package: "swift-data-writable")]
    ),
    .testTarget(
      name: "ReleaseConsumerTests",
      dependencies: [
        "ReleaseConsumer",
        .product(name: "SwiftDataWritable", package: "swift-data-writable"),
      ]
    ),
  ]
)
