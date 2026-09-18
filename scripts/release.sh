#!/bin/bash
# Superclip release pipeline: archive → notarize → staple → DMG → appcast.
#
# Usage: scripts/release.sh [work-dir]
# Requires: Xcode logged into the Apple ID (for notarization upload), the
# "Developer ID Application: Omar Maroki" cert, and the Sparkle EdDSA private
# key in the login keychain (generate_keys).
#
# Output: website/public/releases/Superclip-<version>.dmg (Sparkle-served),
#         website/public/Superclip.dmg (stable download-button URL),
#         website/public/appcast.xml.
# Deploy afterwards with: git add -A && git commit && vercel deploy --prod
set -euo pipefail

cd "$(dirname "$0")/.."
WORK="${1:-$(mktemp -d /tmp/superclip-release.XXXXXX)}"
SPARKLE_BIN=$(find ~/Library/Developer/Xcode/DerivedData/Superclip-*/SourcePackages/artifacts/sparkle/Sparkle/bin -maxdepth 1 -name generate_appcast 2>/dev/null | head -1 | xargs dirname)
[ -n "$SPARKLE_BIN" ] || { echo "Sparkle tools not found — build once in Xcode first"; exit 1; }

VERSION=$(sed -n 's/.*MARKETING_VERSION = \([^;]*\);.*/\1/p' Superclip.xcodeproj/project.pbxproj | head -1)
echo "==> Releasing Superclip $VERSION (work dir: $WORK)"

echo "==> Archiving"
cat > "$WORK/ExportOptions.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key><string>developer-id</string>
	<key>destination</key><string>upload</string>
	<key>teamID</key><string>S34Q66469Q</string>
</dict>
</plist>
EOF
xcodebuild -project Superclip.xcodeproj -scheme Superclip -configuration Release archive \
  -archivePath "$WORK/Superclip.xcarchive" \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Developer ID Application" DEVELOPMENT_TEAM=S34Q66469Q \
  > "$WORK/archive.log" 2>&1 || { tail -20 "$WORK/archive.log"; exit 1; }

echo "==> Uploading for notarization (Xcode account)"
xcodebuild -exportArchive -archivePath "$WORK/Superclip.xcarchive" \
  -exportOptionsPlist "$WORK/ExportOptions.plist" -exportPath "$WORK/upload" \
  > "$WORK/upload.log" 2>&1 || { tail -20 "$WORK/upload.log"; echo "If 'Unable to log in': re-login in Xcode > Settings > Accounts"; exit 1; }

echo "==> Waiting for notarization"
APP=""
for i in $(seq 1 40); do
  rm -rf "$WORK/notarized"
  if xcodebuild -exportNotarizedApp -archivePath "$WORK/Superclip.xcarchive" \
      -exportPath "$WORK/notarized" > "$WORK/notarize.log" 2>&1; then
    APP="$WORK/notarized/Superclip.app"; break
  fi
  # Fallback (memory: IDEProvisioningErrorDomain 23): local export + direct staple
  if grep -q "No Accounts" "$WORK/notarize.log"; then
    sed 's/upload/export/' "$WORK/ExportOptions.plist" > "$WORK/ExportLocal.plist"
    xcodebuild -exportArchive -archivePath "$WORK/Superclip.xcarchive" \
      -exportOptionsPlist "$WORK/ExportLocal.plist" -exportPath "$WORK/local" > /dev/null 2>&1
    if xcrun stapler staple "$WORK/local/Superclip.app" > /dev/null 2>&1; then
      APP="$WORK/local/Superclip.app"; break
    fi
  fi
  echo "    still processing ($((i*30))s)"; sleep 30
done
[ -n "$APP" ] || { echo "Notarization did not complete"; tail -5 "$WORK/notarize.log"; exit 1; }
spctl -a -vv "$APP" > "$WORK/gatekeeper.log" 2>&1 || { cat "$WORK/gatekeeper.log"; echo "Gatekeeper check failed"; exit 1; }
grep -q "Notarized Developer ID" "$WORK/gatekeeper.log" || { cat "$WORK/gatekeeper.log"; echo "Gatekeeper did not confirm notarization"; exit 1; }
echo "    notarized + stapled"

echo "==> Building DMG"
STAGE="$WORK/dmg"; mkdir -p "$STAGE" website/public/releases
cp -R "$APP" "$STAGE/" && ln -s /Applications "$STAGE/Applications"
DMG="website/public/releases/Superclip-$VERSION.dmg"
rm -f "$DMG"
hdiutil create -volname "Superclip" -srcfolder "$STAGE" -ov -format UDZO "$DMG" > /dev/null
codesign --force --sign "Developer ID Application: Omar Maroki (S34Q66469Q)" "$DMG"
cp "$DMG" website/public/Superclip.dmg

echo "==> Generating appcast"
"$SPARKLE_BIN/generate_appcast" \
  --download-url-prefix "https://superclip-tan.vercel.app/releases/" \
  -o website/public/appcast.xml website/public/releases/

echo "==> Done: $DMG"
echo "    Next: git add -A && git commit -m 'chore: release $VERSION' && vercel deploy --prod"
