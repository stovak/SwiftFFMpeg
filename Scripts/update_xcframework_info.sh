#!/bin/bash

set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <xcframework-dir> <library-name>"
  exit 1
fi

XCFRAMEWORK_DIR=$1
LIB_NAME=$2

if [ ! -d "$XCFRAMEWORK_DIR" ]; then
  echo "Error: $XCFRAMEWORK_DIR is not a directory"
  exit 1
fi

AVAILABLE_LIBRARIES=""
while IFS= read -r variant_dir; do
  base=$(basename "$variant_dir")
  arch_segment=${base#macos-}
  if [ "$arch_segment" = "$base" ]; then
    continue
  fi

  ARCH_ELEMENTS=""
  for arch in $arch_segment; do
    ARCH_ELEMENTS+="                        <string>$arch</string>"$'\n'
  done

  AVAILABLE_LIBRARIES+="                <dict>"$'\n'
  AVAILABLE_LIBRARIES+="                        <key>LibraryIdentifier</key>"$'\n'
  AVAILABLE_LIBRARIES+="                        <string>$base</string>"$'\n'
  AVAILABLE_LIBRARIES+="                        <key>LibraryPath</key>"$'\n'
  AVAILABLE_LIBRARIES+="                        <string>$LIB_NAME.framework</string>"$'\n'
  AVAILABLE_LIBRARIES+="                        <key>SupportedArchitectures</key>"$'\n'
  AVAILABLE_LIBRARIES+="                        <array>"$'\n'
  AVAILABLE_LIBRARIES+="$ARCH_ELEMENTS"
  AVAILABLE_LIBRARIES+="                        </array>"$'\n'
  AVAILABLE_LIBRARIES+="                        <key>SupportedPlatform</key>"$'\n'
  AVAILABLE_LIBRARIES+="                        <string>macos</string>"$'\n'
  AVAILABLE_LIBRARIES+="                </dict>"$'\n'

done < <(find "$XCFRAMEWORK_DIR" -mindepth 1 -maxdepth 1 -type d -not -name "__MACOSX" | sort)

cat > "$XCFRAMEWORK_DIR/Info.plist" <<EOF_PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
        <key>AvailableLibraries</key>
        <array>
$(printf "%b" "$AVAILABLE_LIBRARIES")        </array>
        <key>CFBundlePackageType</key>
        <string>XFWK</string>
        <key>XCFrameworkFormatVersion</key>
        <string>1.0</string>
</dict>
</plist>
EOF_PLIST
