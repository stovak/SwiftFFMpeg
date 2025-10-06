# XCFramework Setup Guide

This document explains how SwiftFFmpeg uses XCFrameworks to bundle FFmpeg libraries.

## Architecture

SwiftFFmpeg uses a **self-contained XCFramework** approach:

```
SwiftFFmpeg Package
├── Binary Targets (XCFrameworks in xcframework/)
│   ├── libavcodec.xcframework
│   ├── libavdevice.xcframework
│   ├── libavfilter.xcframework
│   ├── libavformat.xcframework
│   ├── libavutil.xcframework
│   ├── libpostproc.xcframework
│   ├── libswresample.xcframework
│   └── libswscale.xcframework
│
├── CFFmpeg (C wrapper target)
│   ├── Depends on all binary targets
│   ├── Provides shim headers for Swift compatibility
│   └── Exposes FFmpeg C API to Swift
│
└── SwiftFFmpeg (Swift wrapper target)
    ├── Depends on CFFmpeg
    └── Provides Swift-friendly API
```

## Benefits of XCFramework Approach

1. **Self-contained**: No external dependencies on Homebrew or pkg-config
2. **Portable**: Works on any macOS system without pre-installed FFmpeg
3. **Reproducible**: Same build works identically on different machines
4. **Distributable**: Can package and distribute via GitHub Releases or other hosting
5. **Version-locked**: Guaranteed to use the exact FFmpeg version you built against

## Local Development Setup

### First Time Setup

1. Clone the repository
2. Build the XCFrameworks:
   ```bash
   SWIFT_FFMPEG_SKIP_BINARIES=1 swift package plugin build-ffmpeg
   ```
   The environment variable allows the plugin to run before any XCFrameworks exist by skipping SwiftPM's binary target validation. The plugin downloads the official FFmpeg 7.1 release archive, compiles the required libraries for your host architecture, and copies the resulting slices to `xcframework/`.
3. The frameworks will be placed in `xcframework/` directory
4. Build your project:
   ```bash
   swift build
   ```

### Subsequent Builds

Once XCFrameworks are built, they're cached in `xcframework/`. You only need to rebuild if:
- You want to update FFmpeg version
- You need to support additional architectures
- The build failed or is corrupted

To force a rebuild:
```bash
SWIFT_FFMPEG_SKIP_BINARIES=1 swift package plugin build-ffmpeg --force
```

Specify a target architecture explicitly when coordinating automation (for example, GitHub Actions matrix builds):

```bash
SWIFT_FFMPEG_SKIP_BINARIES=1 swift package plugin build-ffmpeg --force --arch arm64
```

## Distribution Setup (Advanced)

For distributing your package to others without requiring them to build FFmpeg:

### Option 1: Include XCFrameworks in Git (Not Recommended)

You can commit the `xcframework/` directory to git, but this adds significant repository size (~200-400 MB).

Remove this line from `.gitignore`:
```
xcframework/
```

### Option 2: Use Remote Binary Targets (Recommended)

1. Build XCFrameworks locally or download them from the GitHub Actions `ffmpeg-universal` artifact
2. Package them with checksums:
   ```bash
   ./Scripts/package_xcframeworks.sh
   ```
   Set `ARTIFACT_SUFFIX` (for example, `-arm64`) when packaging single-architecture slices during CI runs.
3. Upload the generated `.zip` files to GitHub Releases or another binary registry. The `Build FFmpeg XCFrameworks` workflow will do this automatically when a GitHub Release is published.
4. Update `Package.swift` to use remote URLs:
   ```swift
   .binaryTarget(
     name: "libavcodec",
     url: "https://github.com/YOUR_ORG/SwiftFFMpeg/releases/download/v1.0.0/libavcodec.xcframework.zip",
     checksum: "CHECKSUM_FROM_SCRIPT"
   ),
   ```

## Architecture Support

The build scripts emit **single-architecture** slices (`macos-arm64` and `macos-x86_64`). The CI workflow automatically merges both slices into universal XCFrameworks and regenerates `Info.plist` metadata using `Scripts/update_xcframework_info.sh`. When running manually you can combine slices by copying the per-architecture directories into a single `.xcframework` directory and re-running the script to refresh the manifest.

## Troubleshooting

### Package Build Fails with "Missing XCFramework"

The XCFrameworks haven't been built yet. Run:
```bash
SWIFT_FFMPEG_SKIP_BINARIES=1 swift package plugin build-ffmpeg
```

### Import Errors in Swift Code

Make sure your Swift files import the correct module:
```swift
import SwiftFFmpeg  // ✅ Correct
import CFFmpeg      // ❌ Usually not needed directly
```

### Linker Errors

If you see linker errors about missing FFmpeg symbols:
1. Clean build folder: `swift package clean`
2. Rebuild XCFrameworks: `swift package plugin build-ffmpeg --force`
3. Rebuild package: `swift build`

## FFmpeg Configuration

The build uses this FFmpeg configuration (see `Scripts/build.sh`):
- **GPL enabled** (includes copyleft codecs)
- **Version 3 enabled** (includes LGPL v3 components)
- **Programs disabled** (only libraries, no ffmpeg/ffplay executables)
- **Documentation disabled** (reduces build time)
- **Debug disabled** (optimized builds)

To customize, edit `Scripts/build.sh` and modify the `./configure` flags.

## File Structure

```
SwiftFFMpeg/
├── Package.swift                      # SPM manifest with binaryTarget declarations
├── xcframework/                       # Built XCFrameworks (gitignored)
│   ├── libavcodec.xcframework/
│   ├── libavdevice.xcframework/
│   └── ...
├── Sources/
│   ├── CFFmpeg/                       # C shim headers
│   │   ├── module.modulemap          # (Kept for Swift compatibility helpers)
│   │   ├── avutil_shim.h
│   │   └── ...
│   └── SwiftFFmpeg/                   # Swift wrapper code
├── Scripts/
│   ├── build.sh                       # Main FFmpeg build script
│   ├── build_framework.sh             # Individual framework builder
│   └── package_xcframeworks.sh        # Creates zips with checksums
└── Plugins/
    └── BuildFFmpegPlugin/             # Swift package plugin
```

## Contributing

When contributing code that depends on new FFmpeg APIs:
1. Document the minimum FFmpeg version required
2. Update the build scripts if newer FFmpeg is needed
3. Test on both arm64 and x86_64 if possible
4. Ensure CFFmpeg shim headers expose any new C types/functions needed
