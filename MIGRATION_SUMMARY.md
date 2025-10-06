# Migration to XCFramework Binary Targets - Summary

## What Changed

This project has been updated from using **systemLibrary** targets (requiring Homebrew FFmpeg) to using **binaryTarget** with XCFrameworks for a self-contained distribution.

## Key Changes

### 1. Package.swift
- **Removed**: `.systemLibrary` target with `pkgConfig: "libavformat"`
- **Added**: 8 `.binaryTarget` declarations for each FFmpeg library:
  - libavcodec.xcframework
  - libavdevice.xcframework
  - libavfilter.xcframework
  - libavformat.xcframework
  - libavutil.xcframework
  - libpostproc.xcframework
  - libswresample.xcframework
  - libswscale.xcframework
- **Modified**: `CFFmpeg` target now depends on binary targets instead of system libraries
- **Added**: Platform specification `platforms: [.macOS(.v10_15)]`

### 2. Build Scripts
- **Modified**: `Scripts/build_framework.sh` - removed individual zip creation
- **Added**: `Scripts/package_xcframeworks.sh` - centralized packaging with checksums

### 3. Documentation
- **Updated**: README.md with new installation instructions
- **Added**: XCFRAMEWORK_SETUP.md - comprehensive guide for developers
- **Added**: This MIGRATION_SUMMARY.md

### 4. Source Code
- **No changes needed**: Swift code continues to `import CFFmpeg` and `import SwiftFFmpeg` as before
- CFFmpeg shim headers remain in place for Swift compatibility

## Migration Path for Users

### Before (Old Method)
```bash
# Install FFmpeg via Homebrew
brew install ffmpeg

# Add dependency
.package(url: "https://github.com/stovak/SwiftFFmpeg.git", from: "1.0.1")

# Build
swift build
```

### After (New Method)
```bash
# Add dependency
.package(url: "https://github.com/stovak/SwiftFFmpeg.git", from: "1.0.1")

# Build XCFrameworks (one-time, or when updating FFmpeg)
SWIFT_FFMPEG_SKIP_BINARIES=1 swift package plugin build-ffmpeg

# Build
swift build
```

## Benefits of This Change

1. **No Homebrew Dependency**: Users don't need to install FFmpeg separately
2. **Version Control**: Exact FFmpeg version is locked to what you built
3. **Portability**: Package works on any macOS system
4. **Distribution**: Can distribute pre-built frameworks via GitHub Releases
5. **Reproducibility**: Same build on all machines

## Backwards Compatibility

⚠️ **Breaking Change**: This is a breaking change for existing users.

Users must:
1. Build XCFrameworks before building the package
2. Cannot use system-installed FFmpeg anymore (package is now self-contained)

## Next Steps

### For Development
1. Build XCFrameworks: `SWIFT_FFMPEG_SKIP_BINARIES=1 swift package plugin build-ffmpeg`
2. Develop normally: `swift build`, `swift test`

### For Distribution (Optional)
1. Package frameworks: `./Scripts/package_xcframeworks.sh`
2. Upload to GitHub Releases
3. Update Package.swift with remote URLs and checksums
4. Users can then use package without building FFmpeg

## Testing Checklist

- [ ] Run `SWIFT_FFMPEG_SKIP_BINARIES=1 swift package plugin build-ffmpeg` on arm64 Mac
- [ ] Run `SWIFT_FFMPEG_SKIP_BINARIES=1 swift package plugin build-ffmpeg` on x86_64 Mac (if available)
- [ ] Verify `swift build` succeeds after XCFrameworks are built
- [ ] Verify `swift test` passes
- [ ] Test Examples target builds and runs
- [ ] Verify package_xcframeworks.sh creates valid zips and checksums
- [ ] Test clean checkout → plugin build → swift build workflow

## File Changes

### Modified Files
- `Package.swift` - Updated target structure
- `README.md` - Updated installation instructions
- `Scripts/build_framework.sh` - Removed individual zip creation

### New Files
- `Scripts/package_xcframeworks.sh` - Packaging script
- `XCFRAMEWORK_SETUP.md` - Developer guide
- `MIGRATION_SUMMARY.md` - This file

### Unchanged Files
- All Swift source code in `Sources/SwiftFFmpeg/`
- CFFmpeg shim headers in `Sources/CFFmpeg/`
- `Scripts/build.sh` - Main build script
- `Plugins/BuildFFmpegPlugin/plugin.swift`

## Rollback Plan

If needed to rollback to system library approach:

1. Revert Package.swift changes:
```swift
.systemLibrary(
  name: "CFFmpeg",
  pkgConfig: "libavformat"
),
.target(
  name: "SwiftFFmpeg",
  dependencies: ["CFFmpeg"]
),
```

2. Remove binaryTarget declarations
3. Users must install via Homebrew again: `brew install ffmpeg`
