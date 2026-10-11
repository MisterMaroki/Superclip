#!/bin/bash
# Superclip release pipeline: archive → notarize → staple → DMG → appcast.
#
# Usage: scripts/release.sh [work-dir]
#        NOTARY_PROFILE=<profile> scripts/release.sh [work-dir]   (no Xcode account needed)
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
# No `| head -1` here: under pipefail a writer killed by the closed pipe fails the whole script
GENERATE_APPCAST=$(find ~/Library/Developer/Xcode/DerivedData/Superclip-*/SourcePackages/artifacts/sparkle/Sparkle/bin -maxdepth 1 -name generate_appcast -print -quit 2>/dev/null || true)
[ -n "$GENERATE_APPCAST" ] || { echo "Sparkle tools not found — build once in Xcode first"; exit 1; }
SPARKLE_BIN=$(dirname "$GENERATE_APPCAST")

VERSION=$(awk -F' = |;' '/MARKETING_VERSION/ { print $2; exit }' Superclip.xcodeproj/project.pbxproj)
[ -n "$VERSION" ] || { echo "Could not read MARKETING_VERSION"; exit 1; }
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

# Two ways to notarize:
#  - default: upload through the Apple ID signed in to Xcode
#  - NOTARY_PROFILE=<name>: use a notarytool keychain profile instead, for when
#    Xcode has no account for the team. Create the profile once with:
#      xcrun notarytool store-credentials <name> --apple-id <id> --team-id S34Q66469Q
if [ -n "${NOTARY_PROFILE:-}" ]; then
  echo "==> Exporting locally (Developer ID)"
  sed 's/upload/export/' "$WORK/ExportOptions.plist" > "$WORK/ExportLocal.plist"
  rm -rf "$WORK/local"
  xcodebuild -exportArchive -archivePath "$WORK/Superclip.xcarchive" \
    -exportOptionsPlist "$WORK/ExportLocal.plist" -exportPath "$WORK/local" \
    > "$WORK/export.log" 2>&1 || { tail -20 "$WORK/export.log"; exit 1; }
  APP="$WORK/local/Superclip.app"

  echo "==> Notarizing with notarytool (profile: $NOTARY_PROFILE)"
  ditto -c -k --keepParent "$APP" "$WORK/Superclip.zip"
  xcrun notarytool submit "$WORK/Superclip.zip" --keychain-profile "$NOTARY_PROFILE" --wait \
    > "$WORK/notarytool.log" 2>&1 || { tail -20 "$WORK/notarytool.log"; exit 1; }
  grep -q "status: Accepted" "$WORK/notarytool.log" || { tail -20 "$WORK/notarytool.log"; echo "Notarization was not accepted"; exit 1; }
  xcrun stapler staple "$APP" > "$WORK/staple.log" 2>&1 || { cat "$WORK/staple.log"; exit 1; }
else
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
fi
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
