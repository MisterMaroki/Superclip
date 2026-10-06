#!/bin/bash
# Render the app's main screens (drawer, settings, onboarding, paste stack,
# previews) in light and dark appearance to build/screens/*.png.
#
#   scripts/render-screens/run.sh                 # all screens
#   scripts/render-screens/run.sh drawer,settings # just these
#
# Uses a private pasteboard and a scratch home directory under build/.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/build/screens"
DD="$ROOT/build/tests/DerivedData"
PRODUCTS="$DD/Build/Products/Debug"
SCRATCH_HOME="$ROOT/build/screens-home"
mkdir -p "$OUT" "$SCRATCH_HOME"

echo "Building Superclip (Debug, unsigned)..."
xcodebuild -project "$ROOT/Superclip.xcodeproj" -scheme Superclip -configuration Debug \
  -derivedDataPath "$DD" CODE_SIGNING_ALLOWED=NO build 2>&1 \
  | grep -E "error:|BUILD (SUCCEEDED|FAILED)" || true

SOURCES=$(find "$ROOT/Superclip" -name "*.swift" | grep -v SuperclipApp.swift)
if ! LOG=$(swiftc -Onone -default-isolation MainActor -o "$ROOT/build/render-screens" \
  "$ROOT/scripts/render-screens/main.swift" $SOURCES \
  -target arm64-apple-macos14.0 -I "$PRODUCTS" -F "$PRODUCTS" "$PRODUCTS/HotKey.o" \
  -framework Sparkle -Xlinker -rpath -Xlinker "$PRODUCTS" 2>&1); then
  echo "$LOG" | grep -E "error" | head -20
  echo "The screen renderer did not compile"
  exit 1
fi

CFFIXED_USER_HOME="$SCRATCH_HOME" SUPERCLIP_SCRATCH_HOME="$SCRATCH_HOME" \
  "$ROOT/build/render-screens" "$OUT" screen ${1:-} 2>&1 | grep "wrote" || true
echo "Screens are in $OUT"
