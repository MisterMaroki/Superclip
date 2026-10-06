#!/bin/bash
# Build the app, then compile and run the logic and detector tests.
#
# The app target has no XCTest bundle, so these are small executables that
# compile the app's sources directly. They run against a private pasteboard
# and a scratch home directory under build/, never your real clipboard or data.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/build/tests"
DD="$OUT/DerivedData"
PRODUCTS="$DD/Build/Products/Debug"
SCRATCH_HOME="$OUT/home"
mkdir -p "$OUT" "$SCRATCH_HOME"

echo "Building Superclip (Debug, unsigned)..."
xcodebuild -project "$ROOT/Superclip.xcodeproj" -scheme Superclip -configuration Debug \
  -derivedDataPath "$DD" CODE_SIGNING_ALLOWED=NO build 2>&1 \
  | grep -E "error:|BUILD (SUCCEEDED|FAILED)" || true
[ -f "$PRODUCTS/HotKey.o" ] || { echo "Build did not produce the expected products"; exit 1; }

# Every app source except the @main entry point
SOURCES=$(find "$ROOT/Superclip" -name "*.swift" | grep -v SuperclipApp.swift)

echo "Detector tests:"
swiftc -O -o "$OUT/detector-tests" "$ROOT/scripts/tests/detector/main.swift" \
  "$ROOT/Superclip/ContentDetector.swift"
"$OUT/detector-tests"

echo "Logic tests:"
# Same default isolation as the app target, so main-actor code compiles the same way
if ! LOG=$(swiftc -Onone -default-isolation MainActor -o "$OUT/logic-tests" \
  "$ROOT/scripts/tests/logic/main.swift" $SOURCES \
  -target arm64-apple-macos14.0 -I "$PRODUCTS" -F "$PRODUCTS" "$PRODUCTS/HotKey.o" \
  -framework Sparkle -Xlinker -rpath -Xlinker "$PRODUCTS" 2>&1); then
  echo "$LOG" | grep -E "error" | head -20
  echo "Logic tests did not compile"
  exit 1
fi
CFFIXED_USER_HOME="$SCRATCH_HOME" SUPERCLIP_SCRATCH_HOME="$SCRATCH_HOME" "$OUT/logic-tests" 2>&1 \
  | grep -E "^(ok|FAIL|info|ALL PASSED|[0-9]+ FAILED)"
