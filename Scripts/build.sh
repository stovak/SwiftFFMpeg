#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

FFMPEG_VERSION=${FFMPEG_VERSION:-8.0}
FFMPEG_ARCHIVE=${FFMPEG_ARCHIVE:-"FFmpeg-n$FFMPEG_VERSION.tar.gz"}
FFMPEG_SOURCE_URL=${FFMPEG_SOURCE_URL:-"https://github.com/FFmpeg/FFmpeg/archive/refs/tags/n$FFMPEG_VERSION.tar.gz"}
FFMPEG_LIBS="libavcodec libavdevice libavfilter libavformat libavutil libpostproc libswresample libswscale"

HOST_ARCH=$(uname -m)
ARCHS_ENV=${ARCHS:-${ARCH:-$HOST_ARCH}}
IFS=' ' read -r -a REQUESTED_ARCHS <<<"$ARCHS_ENV"

if [ ${#REQUESTED_ARCHS[@]} -eq 0 ]; then
  echo "No architectures requested for build"
  exit 1
fi

CACHE_DIR="${FFMPEG_CACHE_DIR:-$ROOT_DIR/.ffmpeg-cache}"
SOURCE_ARCHIVE_PATH="$CACHE_DIR/$FFMPEG_ARCHIVE"

mkdir -p "$CACHE_DIR"

if [ ! -f "$SOURCE_ARCHIVE_PATH" ]; then
  echo "Downloading FFmpeg $FFMPEG_VERSION source from $FFMPEG_SOURCE_URL"
  curl -L "$FFMPEG_SOURCE_URL" -o "$SOURCE_ARCHIVE_PATH"
else
  echo "Using cached FFmpeg archive at $SOURCE_ARCHIVE_PATH"
fi

OUTPUT_DIR="${FFMPEG_OUTPUT_DIR:-$ROOT_DIR/output}"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

for ARCH in "${REQUESTED_ARCHS[@]}"; do
  if [ "$ARCH" != "$HOST_ARCH" ]; then
    echo "Building FFmpeg for $ARCH on $HOST_ARCH host"
    echo "Ensure you are running on hardware that matches the requested architecture or configure cross-compilation manually."
  fi

  BUILD_ROOT_BASE="${FFMPEG_BUILD_ROOT_BASE:-$ROOT_DIR/.build/ffmpeg}"
  BUILD_ROOT="$BUILD_ROOT_BASE-$ARCH"
  INSTALL_PREFIX="$OUTPUT_DIR/$ARCH/install"

  echo "Preparing build workspace for $ARCH at $BUILD_ROOT"
  rm -rf "$BUILD_ROOT"
  mkdir -p "$BUILD_ROOT"
  tar -xf "$SOURCE_ARCHIVE_PATH" -C "$BUILD_ROOT" --strip-components=1

  pushd "$BUILD_ROOT" >/dev/null

  echo "Configuring FFmpeg $FFMPEG_VERSION for $ARCH"
  ./configure \
    --prefix="$INSTALL_PREFIX" \
    --enable-gpl \
    --enable-version3 \
    --disable-programs \
    --disable-doc \
    --arch="$ARCH" \
    --target-os=darwin \
    --cc=clang \
    --extra-cflags="-arch $ARCH -fno-stack-check" \
    --extra-ldflags="-arch $ARCH" \
    --disable-debug

  make clean
  make -j$(sysctl -n hw.ncpu 2>/dev/null || nproc) install

  popd >/dev/null

  echo "Creating XCFramework slices for $ARCH"
  for LIB in $FFMPEG_LIBS; do
    "$SCRIPT_DIR/build_framework.sh" "$INSTALL_PREFIX" "$LIB" "$FFMPEG_VERSION" "$ARCH" "$OUTPUT_DIR"
  done
done

echo "FFmpeg compilation completed successfully!"
echo "Framework slices are available in: $OUTPUT_DIR/xcframework"
