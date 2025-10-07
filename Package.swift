// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

let shouldIncludeBinaryTargets = ProcessInfo.processInfo.environment["SWIFT_FFMPEG_SKIP_BINARIES"] != "1"

let binaryTargetNames = [
  "libavcodec",
  "libavdevice",
  "libavfilter",
  "libavformat",
  "libavutil",
  "libpostproc",
  "libswresample",
  "libswscale"
]

var targets: [Target] = [
  .plugin(
    name: "BuildFFmpegPlugin",
    capability: .command(
      intent: .custom(
        verb: "build-ffmpeg",
        description: "Clone FFmpeg from git and build XCFrameworks"
      )
    )
  )
]

if shouldIncludeBinaryTargets {
  targets += binaryTargetNames.map { name in
    .binaryTarget(
      name: name,
      path: "xcframework/\(name).xcframework"
    )
  }
}

let cFFmpegDependencies: [Target.Dependency] = shouldIncludeBinaryTargets ? binaryTargetNames.map { .target(name: $0) } : []

targets += [
  .target(
    name: "CFFmpeg",
    dependencies: cFFmpegDependencies,
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
  )
]

let package = Package(
  name: "SwiftFFmpeg",
  platforms: [.macOS(.v10_15)],
  products: [
    .library(
      name: "SwiftFFmpeg",
      targets: ["SwiftFFmpeg"]
    )
  ],
  targets: targets
)
