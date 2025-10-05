// swift-tools-version:5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "SwiftFFmpeg",
  products: [
    .library(
      name: "SwiftFFmpeg",
      targets: ["SwiftFFmpeg"]
    )
  ],
  targets: [
    .plugin(
      name: "UnzipXCFrameworkPlugin",
      capability: .command(
        intent: .custom(
          verb: "build-frameworks",
          description: "Build or unzip XCFrameworks for FFmpeg libraries"
        )
      )
    ),
    .systemLibrary(
      name: "CFFmpeg",
      pkgConfig: "libavformat"
    ),
    .target(
      name: "SwiftFFmpeg",
      dependencies: [
        "CFFmpeg"
      ]
    ),
    .executableTarget(
      name: "Examples",
      dependencies: ["SwiftFFmpeg"]
    ),
    .testTarget(
      name: "Tests",
      dependencies: ["SwiftFFmpeg"]
    ),
  ]
)
