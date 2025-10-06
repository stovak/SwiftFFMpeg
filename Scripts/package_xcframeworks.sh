#!/bin/bash

set -euo pipefail

XCFRAMEWORK_DIR="xcframework"
PACKAGE_DIR="${1:-$XCFRAMEWORK_DIR}"
ARTIFACT_SUFFIX=${ARTIFACT_SUFFIX:-}

FFMPEG_LIBS="libavcodec libavdevice libavfilter libavformat libavutil libpostproc libswresample libswscale"

echo "Packaging XCFrameworks for distribution..."
echo ""

mkdir -p "$PACKAGE_DIR"

for LIB in $FFMPEG_LIBS; do
  XCFRAMEWORK="$XCFRAMEWORK_DIR/$LIB.xcframework"
  ZIP_FILE="$PACKAGE_DIR/$LIB.xcframework$ARTIFACT_SUFFIX.zip"
  CHECKSUM_FILE="$ZIP_FILE.checksum"

  if [ ! -d "$XCFRAMEWORK" ]; then
    echo "Warning: $XCFRAMEWORK not found, skipping..."
    continue
  fi

  echo "Packaging $LIB..."

  pushd "$XCFRAMEWORK_DIR" >/dev/null
  rm -f "../$ZIP_FILE"
  zip -r -q "../$ZIP_FILE" "$LIB.xcframework"
  popd >/dev/null

  CHECKSUM=$(swift package compute-checksum "$ZIP_FILE")
  echo "$CHECKSUM" > "$CHECKSUM_FILE"

  echo "  - Created: $ZIP_FILE"
  echo "  - Checksum: $CHECKSUM"
  echo ""

done

echo "Packaging complete!"

echo ""
echo "Binary target declarations:"
for LIB in $FFMPEG_LIBS; do
  CHECKSUM_FILE="$PACKAGE_DIR/$LIB.xcframework$ARTIFACT_SUFFIX.zip.checksum"
  if [ -f "$CHECKSUM_FILE" ]; then
    CHECKSUM=$(cat "$CHECKSUM_FILE")
    echo ".binaryTarget("
    echo "  name: \"$LIB\"," 
    echo "  url: \"https://github.com/YOUR_ORG/SwiftFFMpeg/releases/download/VERSION/$LIB.xcframework$ARTIFACT_SUFFIX.zip\"," 
    echo "  checksum: \"$CHECKSUM\""
    echo "),"
  fi
done
