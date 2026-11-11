#!/bin/sh
# Rebuilds Web.saver as a universal (Apple silicon + Intel) screensaver.
# Needs the Xcode command line tools. Usage: ./build.sh
set -eu

cd "$(dirname "$0")"

BUNDLE="Web.saver"
BINARY="$BUNDLE/Contents/MacOS/Web"

mkdir -p "$BUNDLE/Contents/MacOS"
cp src/Info.plist "$BUNDLE/Contents/Info.plist"

xcrun clang \
    -bundle \
    -fobjc-arc \
    -O2 \
    -arch arm64 -arch x86_64 \
    -mmacosx-version-min=11.0 \
    -framework Cocoa -framework ScreenSaver -framework CoreText \
    -o "$BINARY" \
    src/MatrixSaverView.m

# Ad-hoc signature: Apple silicon refuses to load unsigned code.
codesign --force --sign - "$BUNDLE"

echo "Built $BUNDLE ($(lipo -archs "$BINARY"))"
