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
      name: "BuildFFmpegPlugin",
      capability: .command(
        intent: .custom(
          verb: "build-ffmpeg",
          description: "Clone FFmpeg from git and build XCFrameworks"
        )
      )
    ),
    // FFmpeg XCFramework binary targets
    .binaryTarget(
      name: "libavcodec",
      path: "xcframework/libavcodec.xcframework"
    ),
    .binaryTarget(
      name: "libavdevice",
      path: "xcframework/libavdevice.xcframework"
    ),
    .binaryTarget(
      name: "libavfilter",
      path: "xcframework/libavfilter.xcframework"
    ),
    .binaryTarget(
      name: "libavformat",
      path: "xcframework/libavformat.xcframework"
    ),
    .binaryTarget(
      name: "libavutil",
      path: "xcframework/libavutil.xcframework"
    ),
    .binaryTarget(
      name: "libpostproc",
      path: "xcframework/libpostproc.xcframework"
    ),
    .binaryTarget(
      name: "libswresample",
      path: "xcframework/libswresample.xcframework"
    ),
    .binaryTarget(
      name: "libswscale",
      path: "xcframework/libswscale.xcframework"
    ),
    .target(
      name: "CFFmpeg",
      dependencies: [
        "libavcodec",
        "libavdevice",
        "libavfilter",
        "libavformat",
        "libavutil",
        "libpostproc",
        "libswresample",
        "libswscale"
      ],
      publicHeadersPath: "."
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
