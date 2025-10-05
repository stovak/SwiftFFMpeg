# SwiftFFmpeg

![Tests](https://github.com/stovak/SwiftFFMpeg/actions/workflows/tests.yml/badge.svg)

A Swift wrapper for the FFmpeg API.

> Note: SwiftFFmpeg is still in development, and the API is not guaranteed to be stable. It's subject to change without warning.

## Installation

### Prerequisites

You need to install [FFmpeg](http://ffmpeg.org/) (Requires FFmpeg 7.1 or higher) before using this library. On macOS:

```bash
brew install ffmpeg
```

### Swift Package Manager

SwiftFFmpeg uses [SwiftPM](https://swift.org/package-manager/) as its build tool. To depend on SwiftFFmpeg in your own project, add a `dependencies` clause to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/sunlubo/SwiftFFmpeg.git", from: "1.0.0")
]
```

The package uses the system-installed FFmpeg via pkg-config.

### Building Custom FFmpeg Frameworks (Optional)

If you need to build custom FFmpeg frameworks from source:

```bash
# Build all frameworks from source
./Scripts/build.sh
```

The build script will:
- Download FFmpeg 7.1 source
- Compile for your architecture (arm64 or x86_64)
- Create XCFrameworks with proper structure
- Generate zip files for distribution

You can also use the plugin:

```bash
swift package plugin build-frameworks
```

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
