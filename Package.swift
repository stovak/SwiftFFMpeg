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
      capability: .buildTool()
    ),
    .systemLibrary(
      name: "CFFmpeg",
      pkgConfig: "libavformat"
    ),
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
      name: "libswresample",
      path: "xcframework/libswresample.xcframework"
    ),
    .binaryTarget(
      name: "libswscale",
      path: "xcframework/libswscale.xcframework"
    ),
    .binaryTarget(
      name: "libpostproc",
      path: "xcframework/libpostproc.xcframework"
    ),
    .target(
      name: "SwiftFFmpeg",
      dependencies: [
        "CFFmpeg",
        "libavcodec",
        "libavdevice",
        "libavfilter",
        "libavformat",
        "libavutil",
        "libswresample",
        "libswscale",
        "libpostproc"
      ],
      plugins: ["UnzipXCFrameworkPlugin"]
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
