# AVConcat Usage Guide

The `AVConcat` struct provides utilities for concatenating multiple audio or video files using FFmpeg.

## Features

- Concatenate multiple media files without re-encoding (when formats match)
- Support for both audio and video files
- Two methods: demuxer-based (recommended) and protocol-based

## Usage

### Method 1: Using the Concat Demuxer (Recommended)

This method works with any file format and provides the best compatibility:

```swift
import SwiftFFmpeg

// Concatenate multiple files
let inputFiles = ["video1.mp4", "video2.mp4", "video3.mp4"]
let outputFile = "output.mp4"

try AVConcat.concat(inputFiles: inputFiles, outputFile: outputFile)
```

With options:

```swift
let options = ["movflags": "faststart"]
try AVConcat.concat(
    inputFiles: inputFiles,
    outputFile: outputFile,
    options: options
)
```

### Method 2: Using the Concat Protocol

This method works best with MPEG transport streams:

```swift
try AVConcat.concatProtocol(inputFiles: inputFiles, outputFile: outputFile)
```

## Command Line Example

Run the concat example from the command line:

```bash
# Build the project
swift build

# Run the concat example
.build/debug/Examples concat output.mp4 video1.mp4 video2.mp4 video3.mp4
```

## Requirements

- All input files should have the same codec parameters and format for best results
- If files have different parameters, FFmpeg will attempt to copy them as-is, which may result in playback issues

## Important Notes

1. **Identical Streams**: For seamless concatenation, all input files should have:
   - Same codecs
   - Same resolution (for video)
   - Same sample rate (for audio)
   - Same number of streams

2. **File Paths**: Both absolute and relative file paths are supported

3. **Performance**: The concat demuxer method doesn't re-encode, making it very fast

## Error Handling

```swift
do {
    try AVConcat.concat(inputFiles: inputFiles, outputFile: outputFile)
    print("Concatenation successful!")
} catch let error as AVError {
    print("FFmpeg error: \(error)")
} catch {
    print("Unexpected error: \(error)")
}
```

## See Also

- [FFmpeg Concat Documentation](https://ffmpeg.org/ffmpeg-formats.html#concat)
- `Sources/Examples/concat.swift` for a complete example
