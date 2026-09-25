#!/bin/zsh
# Build Chess Duo (Release) and install it on one or more iPhones over the local network.
# Usage: scripts/install.sh [mike|liana|all]   (default: all)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEAM="N7LRRN2YGY"
BUNDLE="com.mikeshobes.chesscoachduo"
# Built outside the project tree: iCloud Drive adds extended attributes that make codesign reject fresh bundles.
DD="${CHESSDUO_DERIVED_DATA:-/tmp/chessduo-dd}"
APP="${DD}/Build/Products/Release-iphoneos/ChessDuo.app"

typeset -A DEVICES
DEVICES[mike]="613E0636-1C1C-559C-80D5-D49470A531B2"
DEVICES[liana]="57A8CC3A-EDEA-577D-BC51-6A58A495F1D8"
MIKE_UDID="00008150-00180DA63644401C"

TARGETS="${1:-all}"
cd "$ROOT"

echo "== clearing iCloud conflict copies"
find . -name "* [0-9].swift" -not -path "./.git/*" -delete 2>/dev/null || true
rm -rf ./*\ [0-9].xcodeproj 2>/dev/null || true

echo "== generating project"
xcodegen generate >/dev/null

# Sign with the App Store Connect API key when it's set, so no Xcode account login is needed.
AUTH=()
if [[ -n "${APPLE_API_KEY:-}" && -n "${APPLE_API_KEY_ID:-}" && -n "${APPLE_API_ISSUER:-}" ]]; then
  AUTH=(-authenticationKeyPath "$APPLE_API_KEY" -authenticationKeyID "$APPLE_API_KEY_ID" -authenticationKeyIssuerID "$APPLE_API_ISSUER")
fi

echo "== building Release for device"
xcodebuild -project ChessDuo.xcodeproj -scheme ChessDuo "${AUTH[@]}" \
  -destination "generic/platform=iOS" \
  -derivedDataPath "$DD" \
  -configuration Release \
  DEVELOPMENT_TEAM="$TEAM" \
  -allowProvisioningUpdates \
  build | grep -E "error|warning: unre|BUILD" | tail -5

echo "== clearing extended attributes"
xattr -cr "$APP" || true

install_to() {
  local name="$1" id="${DEVICES[$1]}"
  echo "== installing on $name ($id)"
  if xcrun devicectl device install app --device "$id" "$APP"; then
    xcrun devicectl device process launch --device "$id" "$BUNDLE" || true
    echo "   ✓ $name done"
  else
    echo "   ✗ $name failed (is the phone unlocked and on the same Wi‑Fi?)"
    return 1
  fi
}

rc=0
case "$TARGETS" in
  mike) install_to mike || rc=1 ;;
  liana) install_to liana || rc=1 ;;
  all) install_to mike || rc=1; install_to liana || rc=1 ;;
  *) echo "unknown target $TARGETS"; exit 2 ;;
esac
exit $rc
