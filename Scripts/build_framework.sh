#!/bin/bash

set -euo pipefail

if [ "$#" -lt 4 ]; then
  echo "Usage: $0 <install-prefix> <library-name> <version> <arch> [output-root]"
  exit 1
fi

PREFIX=$1
LIB_NAME=$2
LIB_VERSION=$3
ARCH_NAME=$4
OUTPUT_ROOT=${5:-$(dirname "$PREFIX")}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

PLATFORM_ID="macos-$ARCH_NAME"

LIB_FRAMEWORK_ROOT="$OUTPUT_ROOT/$ARCH_NAME/framework/$LIB_NAME.framework"
LIB_XCFRAMEWORK="$OUTPUT_ROOT/xcframework/$LIB_NAME.xcframework"

echo "Preparing framework for $LIB_NAME ($ARCH_NAME)"

rm -rf "$LIB_FRAMEWORK_ROOT"
mkdir -p "$LIB_FRAMEWORK_ROOT/Headers"

if [ ! -d "$PREFIX/include/$LIB_NAME" ]; then
  echo "Error: Header directory $PREFIX/include/$LIB_NAME not found"
  exit 1
fi

rsync -a "$PREFIX/include/$LIB_NAME/" "$LIB_FRAMEWORK_ROOT/Headers/"
cp "$PREFIX/lib/$LIB_NAME.a" "$LIB_FRAMEWORK_ROOT/$LIB_NAME"

cat > "$LIB_FRAMEWORK_ROOT/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
        <key>CFBundleDevelopmentRegion</key>
        <string>en</string>
        <key>CFBundleExecutable</key>
        <string>$LIB_NAME</string>
        <key>CFBundleIdentifier</key>
        <string>org.ffmpeg.$LIB_NAME</string>
        <key>CFBundleInfoDictionaryVersion</key>
        <string>6.0</string>
        <key>CFBundleName</key>
        <string>$LIB_NAME</string>
        <key>CFBundlePackageType</key>
        <string>FMWK</string>
        <key>CFBundleShortVersionString</key>
        <string>$LIB_VERSION</string>
        <key>CFBundleVersion</key>
        <string>$LIB_VERSION</string>
        <key>CFBundleSignature</key>
        <string>????</string>
        <key>NSPrincipalClass</key>
        <string></string>
</dict>
</plist>
EOF

mkdir -p "$LIB_XCFRAMEWORK/$PLATFORM_ID"
rsync -a "$LIB_FRAMEWORK_ROOT/" "$LIB_XCFRAMEWORK/$PLATFORM_ID/$LIB_NAME.framework/"

"$SCRIPT_DIR/update_xcframework_info.sh" "$LIB_XCFRAMEWORK" "$LIB_NAME"

echo "Built $LIB_NAME.xcframework slice for $ARCH_NAME"
