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

SwiftFFmpeg uses [SwiftPM](https://swift.org/package-manager/) as its build tool and links against the FFmpeg libraries provided by your system installation.

To depend on SwiftFFmpeg in your own project, add a `dependencies` clause to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/stovak/SwiftFFmpeg.git", from: "1.0.1")
]
```

SwiftPM will automatically discover the system libraries via `pkg-config`. Make sure your environment can locate FFmpeg's `.pc` files (Homebrew handles this automatically).

### Optional: Download prebuilt FFmpeg XCFrameworks

SwiftFFmpeg ships with a command plugin that can download the latest prebuilt XCFramework bundle published by [`stovak/ffmpeg-framework`](https://github.com/stovak/ffmpeg-framework). This is useful when you need to embed FFmpeg directly into an application bundle instead of relying on a system installation.

1. Create a GitHub personal access token with the `actions:read` scope and expose it as either `FFMPEG_FRAMEWORK_TOKEN` (preferred) or `GITHUB_TOKEN` in your environment.
2. Run the plugin to fetch and extract the frameworks into the repository's `xcframework/` directory:

   ```bash
   swift package --allow-writing-to-package-directory plugin \
     --command download-ffmpeg-xcframeworks
   ```

The helper script replaces any existing contents inside `xcframework/` with the freshly downloaded frameworks. They are not required for the standard system-library build, but the artifacts are available for projects that need to redistribute FFmpeg.
Pass `--force` to the command if you need to refresh an already downloaded
set of frameworks.

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
