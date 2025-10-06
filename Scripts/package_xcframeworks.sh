#!/bin/bash

set -e

XCFRAMEWORK_DIR="xcframework"
PACKAGE_DIR="${1:-$XCFRAMEWORK_DIR}"

FFMPEG_LIBS="libavcodec libavdevice libavfilter libavformat libavutil libpostproc libswresample libswscale"

echo "Packaging XCFrameworks for distribution..."
echo ""

# Create output directory
mkdir -p "$PACKAGE_DIR"

for LIB in $FFMPEG_LIBS; do
  XCFRAMEWORK="$XCFRAMEWORK_DIR/$LIB.xcframework"
  ZIP_FILE="$PACKAGE_DIR/$LIB.xcframework.zip"
  CHECKSUM_FILE="$PACKAGE_DIR/$LIB.xcframework.zip.checksum"

  if [ ! -d "$XCFRAMEWORK" ]; then
    echo "Warning: $XCFRAMEWORK not found, skipping..."
    continue
  fi

  echo "Packaging $LIB..."

  # Create zip file
  cd "$XCFRAMEWORK_DIR"
  zip -r -q "../$ZIP_FILE" "$LIB.xcframework"
  cd ..

  # Calculate checksum
  CHECKSUM=$(swift package compute-checksum "$ZIP_FILE")
  echo "$CHECKSUM" > "$CHECKSUM_FILE"

  echo "  - Created: $ZIP_FILE"
  echo "  - Checksum: $CHECKSUM"
  echo ""
done

echo "Packaging complete!"
echo ""
echo "To use these in Package.swift with remote URLs, use:"
echo ""
for LIB in $FFMPEG_LIBS; do
  CHECKSUM_FILE="$PACKAGE_DIR/$LIB.xcframework.zip.checksum"
  if [ -f "$CHECKSUM_FILE" ]; then
    CHECKSUM=$(cat "$CHECKSUM_FILE")
    echo ".binaryTarget("
    echo "  name: \"$LIB\","
    echo "  url: \"https://github.com/YOUR_USERNAME/SwiftFFMpeg/releases/download/VERSION/$LIB.xcframework.zip\","
    echo "  checksum: \"$CHECKSUM\""
    echo "),"
  fi
done
