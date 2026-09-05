#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE="$ROOT/AListCore"
OUT="$ROOT/build"
GO_VERSION="1.25.0"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This build must run on macOS with Xcode and iOS SDK." >&2
  exit 2
fi
command -v go >/dev/null || { echo "Go is required" >&2; exit 2; }
command -v xcrun >/dev/null || { echo "Xcode is required" >&2; exit 2; }

mkdir -p "$OUT"
cd "$CORE"

gofmt -w iosbridge/bridge.go iosbridge_export/main.go
# Build a c-archive with every iOS-compatible AList driver. Platform-specific
# packages must provide ios_unsupported/ios_remote adapters before this step.
# The export wrapper is a main package and owns the C ABI entry points.
export GOOS=ios
export GOARCH=arm64
export CGO_ENABLED=1
export SDKROOT="$(xcrun --sdk iphoneos --show-sdk-path)"
export CC="$(xcrun --sdk iphoneos --find clang)"
export CXX="$(xcrun --sdk iphoneos --find clang++)"

rm -rf "$OUT/AListCore-device" "$OUT/AListCore.xcframework"
mkdir -p "$OUT/AListCore-device"
go build -trimpath -buildmode=c-archive -tags=jsoniter \
  -ldflags='-s -w' \
  -o "$OUT/AListCore-device/AListCore.a" ./iosbridge_export

xcrun xcodebuild -create-xcframework \
  -library "$OUT/AListCore-device/AListCore.a" \
  -headers "$OUT/AListCore-device" \
  -output "$OUT/AListCore.xcframework"

echo "Created $OUT/AListCore.xcframework"
