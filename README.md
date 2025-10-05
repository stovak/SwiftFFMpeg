# SwiftFFmpeg

![Tests](https://github.com/stovak/SwiftFFMpeg/actions/workflows/tests.yml/badge.svg)

A Swift wrapper for the FFmpeg API.

> Note: SwiftFFmpeg is still in development, and the API is not guaranteed to be stable. It's subject to change without warning.

## Installation

### Swift Package Manager

SwiftFFmpeg uses [SwiftPM](https://swift.org/package-manager/) as its build tool. To depend on SwiftFFmpeg in your own project, add a `dependencies` clause to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/sunlubo/SwiftFFmpeg.git", from: "1.0.0")
]
```

### Building XCFrameworks

This package includes pre-built XCFramework binaries for FFmpeg 7.1. When you first clone or use this package, you need to set up the frameworks:

#### Option 1: Using Pre-built Binaries (Recommended)

If the package includes `.zip` files in the `xcframework/` directory:

```bash
swift package plugin build-frameworks
```

This will automatically unzip the pre-built XCFrameworks for your architecture.

#### Option 2: Building from Source

If you need to build from source or update to a different FFmpeg version:

```bash
# Build all frameworks from source
./Scripts/build.sh

# Or use the plugin (which will trigger the build script if needed)
swift package plugin build-frameworks --force
```

The build script will:
- Download FFmpeg 7.1 source
- Compile for your architecture (arm64 or x86_64)
- Create XCFrameworks with proper structure
- Generate zip files for distribution

#### Architecture Support

The build system automatically detects your architecture:
- **arm64**: macOS Apple Silicon (M1/M2/M3)
- **x86_64**: macOS Intel

Each XCFramework contains:
- Framework structure (`LibName.framework`)
- Headers for C API access
- Static library binary
- Info.plist with architecture metadata

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
