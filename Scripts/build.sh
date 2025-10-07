#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

FFMPEG_VERSION=${FFMPEG_VERSION:-8.0}
FFMPEG_ARCHIVE=${FFMPEG_ARCHIVE:-"FFmpeg-n$FFMPEG_VERSION.tar.gz"}
FFMPEG_SOURCE_URL=${FFMPEG_SOURCE_URL:-"https://github.com/FFmpeg/FFmpeg/archive/refs/tags/n$FFMPEG_VERSION.tar.gz"}
SOURCE_DIR_OVERRIDE="${FFMPEG_SOURCE_DIR:-}"
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

download_ffmpeg_source() {
  local url="$1"
  local destination="$2"

  echo "Attempting download from $url"

  local temp_file
  temp_file="${destination}.partial"
  rm -f "$temp_file"

  local -a curl_args
  curl_args=(-fSL --retry 5 --retry-delay 2 --retry-connrefused --retry-all-errors)
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    curl_args+=(-H "Authorization: Bearer $GITHUB_TOKEN" -H "X-GitHub-Api-Version: 2022-11-28")
  fi

  if curl "${curl_args[@]}" "$url" -o "$temp_file"; then
    mv "$temp_file" "$destination"
    return 0
  fi

  echo "Download failed from $url" >&2
  rm -f "$temp_file"
  return 1
}

if [ -n "$SOURCE_DIR_OVERRIDE" ]; then
  if [ ! -d "$SOURCE_DIR_OVERRIDE" ]; then
    echo "FFMPEG_SOURCE_DIR is set to '$SOURCE_DIR_OVERRIDE', but that directory does not exist" >&2
    exit 1
  fi

  echo "Using local FFmpeg sources from $SOURCE_DIR_OVERRIDE"
else
  if [ ! -f "$SOURCE_ARCHIVE_PATH" ]; then
    echo "Downloading FFmpeg $FFMPEG_VERSION source"

    FALLBACK_URL="https://codeload.github.com/FFmpeg/FFmpeg/tar.gz/refs/tags/n$FFMPEG_VERSION"
    API_URL="https://api.github.com/repos/FFmpeg/FFmpeg/tarball/n$FFMPEG_VERSION"
    CANDIDATE_URLS=("$FFMPEG_SOURCE_URL")

    if [[ "$FALLBACK_URL" != "$FFMPEG_SOURCE_URL" ]]; then
      CANDIDATE_URLS+=("$FALLBACK_URL")
    fi

    if [[ "$API_URL" != "$FFMPEG_SOURCE_URL" && "$API_URL" != "$FALLBACK_URL" ]]; then
      CANDIDATE_URLS+=("$API_URL")
    fi

    DOWNLOAD_SUCCEEDED=false
    for URL in "${CANDIDATE_URLS[@]}"; do
      if download_ffmpeg_source "$URL" "$SOURCE_ARCHIVE_PATH"; then
        DOWNLOAD_SUCCEEDED=true
        break
      fi
    done

    if [ "$DOWNLOAD_SUCCEEDED" != true ]; then
      echo "Unable to download FFmpeg sources. If you are running in a restricted network environment, set FFMPEG_SOURCE_URL to a reachable mirror." >&2
      exit 1
    fi
  else
    echo "Using cached FFmpeg archive at $SOURCE_ARCHIVE_PATH"
  fi
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

  if [ -n "$SOURCE_DIR_OVERRIDE" ]; then
    echo "Copying FFmpeg sources from $SOURCE_DIR_OVERRIDE"
    rsync -a --delete --exclude='.git' "$SOURCE_DIR_OVERRIDE"/ "$BUILD_ROOT"/
  else
    tar -xf "$SOURCE_ARCHIVE_PATH" -C "$BUILD_ROOT" --strip-components=1
  fi

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
