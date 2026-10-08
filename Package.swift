// swift-tools-version: 6.2

// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import CompilerPluginSupport
import PackageDescription

let package = Package(
  name: "swift-data-writable",
  platforms: [
    .iOS(.v18),
    .macOS(.v15),
    .tvOS(.v18),
    .watchOS(.v11),
  ],
  products: [
    .library(
      name: "SwiftDataWritable",
      targets: ["SwiftDataWritable"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "604.0.0")
  ],
  targets: [
    .macro(
      name: "SwiftDataWritableMacros",
      dependencies: [
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
        .product(name: "SwiftDiagnostics", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
      ]
    ),
    .target(
      name: "SwiftDataWritable",
      dependencies: ["SwiftDataWritableMacros"]
    ),
    .testTarget(
      name: "SwiftDataWritableMacroTests",
      dependencies: [
        "SwiftDataWritableMacros",
        .product(name: "SwiftSyntaxMacroExpansion", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacrosGenericTestSupport", package: "swift-syntax"),
      ]
    ),
    .testTarget(
      name: "SwiftDataWritableRuntimeTests",
      dependencies: ["SwiftDataWritable"]
    ),
    .testTarget(
      name: "SwiftDataWritableUsageTests",
      dependencies: ["SwiftDataWritable"]
    ),
  ]
)
