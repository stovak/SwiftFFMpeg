// swift-tools-version:5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "SwiftFFmpeg",
  platforms: [.macOS(.v10_15)],
  products: [
    .library(
      name: "SwiftFFmpeg",
      targets: ["SwiftFFmpeg"]
    )
  ],
  targets: [
    .systemLibrary(
      name: "CFFmpeg",
      pkgConfig: "libavformat",
      providers: [
        .brew(["ffmpeg"])
      ]
    ),
    .target(
      name: "SwiftFFmpeg",
      dependencies: ["CFFmpeg"]
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
