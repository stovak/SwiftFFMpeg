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
    .plugin(
      name: "FetchFFmpegXCFrameworks",
      capability: .command(
        intent: .custom(
          verb: "download-ffmpeg-xcframeworks",
          description: "Download the latest stovak/ffmpeg-framework XCFramework artifact into the package."
        ),
        permissions: [
          .writeToPackageDirectory(reason: "Place the downloaded FFmpeg XCFrameworks under the xcframework/ directory.")
        ]
      )
    ),
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
