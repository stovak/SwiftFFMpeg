# SwiftFFmpeg

![Tests](https://github.com/stovak/SwiftFFMpeg/actions/workflows/tests.yml/badge.svg)

A Swift wrapper for the FFmpeg API.

> Note: SwiftFFmpeg is still in development, and the API is not guaranteed to be stable. It's subject to change without warning.

## Installation

### Prerequisites

- macOS with Xcode 15 or newer
- Command Line Tools (`xcode-select --install`)
- Approximately 15 GB of free disk space when compiling FFmpeg locally

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

The plugin orchestrates `Scripts/build.sh` to:

- Download the official FFmpeg `ffmpeg-7.1.tar.xz` source archive from [ffmpeg.org](https://www.ffmpeg.org/download.html#get-sources)
- Compile every required library slice for your host architecture (either `arm64` or `x86_64`)
- Produce XCFramework slices for `libavcodec`, `libavdevice`, `libavfilter`, `libavformat`, `libavutil`, `libpostproc`, `libswresample`, and `libswscale`
- Copy the resulting frameworks into the repository’s `xcframework/` directory so SwiftPM can resolve the binary targets

Use `--force` to rebuild from scratch or pass `--arch` explicitly when driving the plugin from automation:

```bash
swift package plugin build-ffmpeg --force --arch arm64
```

> Building FFmpeg locally typically takes 15–30 minutes on GitHub Actions hardware and less on Apple Silicon desktops. The script caches the downloaded source archive to avoid repeated network fetches.

#### Option 2: Manual Build

Run the build script directly when you prefer not to invoke the plugin (for example, inside CI containers):

```bash
./Scripts/build.sh
```

Key behaviours of the script:

1. Downloads the FFmpeg 7.1 release tarball from `https://ffmpeg.org/releases/`
2. Configures and compiles FFmpeg for each architecture requested via the `ARCHS` environment variable (defaults to the host architecture)
3. Builds framework bundles for all FFmpeg libraries in `output/<arch>/framework`
4. Emits XCFramework slices under `output/xcframework/`

Copy the generated slices into the repository root if you want SwiftPM to consume them immediately:

```bash
mkdir -p xcframework
rsync -a output/xcframework/ xcframework/
```

### Packaging for Distribution (Advanced)

To create distributable zip files with checksums for remote hosting:

```bash
./Scripts/package_xcframeworks.sh
```

Set `ARTIFACT_SUFFIX` to distinguish per-architecture slices when archiving automation output:

```bash
ARTIFACT_SUFFIX="-arm64" ./Scripts/package_xcframeworks.sh build-artifacts
```

The script emits zipped XCFrameworks alongside SwiftPM checksums. Upload the zipped bundles to your preferred distribution channel and wire them into `Package.swift` using `.binaryTarget(url:checksum:)` once they are published.

### Continuous Integration and Releases

The repository includes a `Build FFmpeg XCFrameworks` GitHub Actions workflow that runs on pushes, pull requests, manual dispatches, and published releases. The workflow:

1. Builds FFmpeg slices on `macos-13` (Intel) and `macos-14` (Apple Silicon) runners via the package plugin
2. Packages architecture-specific artifacts and publishes them as workflow artifacts
3. Merges the slices into universal XCFrameworks with refreshed metadata
4. Uploads the universal zips and checksums for later consumption and automatically attaches them to GitHub Releases when triggered by a published release

These artifacts serve as the canonical source-of-truth binaries that downstream consumers can reference without rebuilding FFmpeg locally.

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
