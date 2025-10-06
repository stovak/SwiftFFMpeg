#!/bin/bash

set -e

FFMPEG_VERSION=7.1
FFMPEG_GIT_URL="https://git.ffmpeg.org/ffmpeg.git"
FFMPEG_BRANCH="release/$FFMPEG_VERSION"
FFMPEG_SOURCE_DIR="FFmpeg-release-$FFMPEG_VERSION"
FFMPEG_LIBS="libavcodec libavdevice libavfilter libavformat libavutil libpostproc libswresample libswscale"
PREFIX=`pwd`/output

# Detect architecture if not specified
if [ -z "$ARCH" ]; then
    ARCH=$(uname -m)
fi

echo "Building FFmpeg $FFMPEG_VERSION for architecture: $ARCH"

# Clone FFmpeg if not already cloned
if [ ! -d "$FFMPEG_SOURCE_DIR" ]; then
  echo "Cloning FFmpeg from git (branch: $FFMPEG_BRANCH)..."
  git clone --branch "$FFMPEG_BRANCH" --depth 1 "$FFMPEG_GIT_URL" "$FFMPEG_SOURCE_DIR" || exit 1
else
  echo "FFmpeg source already exists at $FFMPEG_SOURCE_DIR"
  echo "To force re-clone, delete the directory and run again"
fi

echo "Start compiling FFmpeg..."

rm -rf $PREFIX
cd $FFMPEG_SOURCE_DIR

./configure \
  --prefix=$PREFIX \
  --enable-gpl \
  --enable-version3 \
  --disable-programs \
  --disable-doc \
  --arch=$ARCH \
  --extra-cflags="-arch $ARCH -march=native -fno-stack-check" \
  --disable-debug || exit 1

make clean
make -j8 install || exit 1

cd ..

# Build frameworks for each library
for LIB in $FFMPEG_LIBS; do
  echo "Building framework for $LIB..."
  ./Scripts/build_framework.sh $PREFIX $LIB $FFMPEG_VERSION || exit 1
done

echo "FFmpeg compilation completed successfully!"
echo "Frameworks built in: $PREFIX/xcframework/"
echo ""
echo "To use these frameworks, ensure they are available at: xcframework/"
echo "You can copy them with: mkdir -p xcframework && cp -R $PREFIX/xcframework/* xcframework/"
