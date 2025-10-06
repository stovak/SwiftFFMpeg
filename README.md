# SwiftFFmpeg

![Tests](https://github.com/stovak/SwiftFFMpeg/actions/workflows/tests.yml/badge.svg)

A Swift wrapper for the FFmpeg API.

> Note: SwiftFFmpeg is still in development, and the API is not guaranteed to be stable. It's subject to change without warning.

## Installation

### Prerequisites

You need to install [FFmpeg](http://ffmpeg.org/) (Requires FFmpeg 8.0 or higher) before using this library. On macOS:

```bash
brew install ffmpeg
```

### Swift Package Manager

SwiftFFmpeg uses [SwiftPM](https://swift.org/package-manager/) as its build tool and bundles FFmpeg as XCFrameworks for a self-contained, portable installation.

To depend on SwiftFFmpeg in your own project, add a `dependencies` clause to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/stovak/SwiftFFmpeg.git", from: "1.0.1")
]
```

**Important:** Before building, you need to generate the XCFrameworks first (see below).

### Building FFmpeg XCFrameworks

The package requires pre-built XCFrameworks. You have two options:

#### Option 1: Using the Plugin (Recommended)

```bash
swift package plugin build-ffmpeg
```

This will:
- Clone FFmpeg 7.1 from the official git repository
- Compile for your architecture (arm64 or x86_64)
- Build XCFrameworks with proper structure
- Place frameworks in `xcframework/` directory
- Automatically make them available to the package

**Note:** Building takes 10-30 minutes depending on your machine.

#### Option 2: Manual Build

Run the build script directly:

```bash
./Scripts/build.sh
```

The build process:
1. Clones FFmpeg from `https://git.ffmpeg.org/ffmpeg.git` (release/7.1 branch)
2. Configures and compiles FFmpeg with GPL support
3. Creates framework structures for all FFmpeg libraries (libavcodec, libavdevice, libavfilter, libavformat, libavutil, libpostproc, libswresample, libswscale)
4. Builds architecture-specific XCFrameworks in `output/xcframework/`

After building, copy the frameworks:

```bash
mkdir -p xcframework
cp -R output/xcframework/* xcframework/
```

### Packaging for Distribution (Advanced)

To create distributable zip files with checksums for remote hosting:

```bash
./Scripts/package_xcframeworks.sh
```

This creates zip files and checksums for each XCFramework, which can be uploaded to GitHub Releases or other hosting and referenced via URL in `Package.swift` using `.binaryTarget` with remote URLs.

## Documentation

- [API documentation](https://sunlubo.github.io/SwiftFFmpeg)

## Usage

```swift
import Foundation
import SwiftFFmpeg

if CommandLine.argc < 2 {
    print("Usage: \(CommandLine.arguments[0]) <input file>")
    exit(1)
}
let input = CommandLine.arguments[1]

let fmtCtx = try AVFormatContext(url: input)
try fmtCtx.findStreamInfo()

fmtCtx.dumpFormat(isOutput: false)

guard let stream = fmtCtx.videoStream else {
    fatalError("No video stream.")
}
guard let codec = AVCodec.findDecoderById(stream.codecParameters.codecId) else {
    fatalError("Codec not found.")
}
let codecCtx = AVCodecContext(codec: codec)
codecCtx.setParameters(stream.codecParameters)
try codecCtx.openCodec()

let pkt = AVPacket()
let frame = AVFrame()

while let _ = try? fmtCtx.readFrame(into: pkt) {
    defer { pkt.unref() }

    if pkt.streamIndex != stream.index {
        continue
    }

    try codecCtx.sendPacket(pkt)

    while true {
        do {
            try codecCtx.receiveFrame(frame)
        } catch let err as AVError where err == .tryAgain || err == .eof {
            break
        }

        let str = String(
            format: "Frame %3d (type=%@, size=%5d bytes) pts %4lld key_frame %d",
            codecCtx.frameNumber,
            frame.pictureType.description,
            frame.pktSize,
            frame.pts,
            frame.isKeyFrame
        )
        print(str)

        frame.unref()
    }
}

print("Done.")
```
