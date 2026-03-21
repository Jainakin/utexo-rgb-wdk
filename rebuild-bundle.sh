#!/bin/bash
set -euo pipefail

# ============================================================================
# Rebuild the worklet bundle from the app's dependency tree
#
# This ensures linked native addon versions in the bundle match exactly
# what bare-link creates as xcframeworks for iOS. Without this, version
# mismatches cause ADDON_NOT_FOUND errors at runtime.
#
# Run this after:
#   - npm install (dependency version changes)
#   - Modifying pear-wrk-wdk source files
# ============================================================================

APP_DIR="${1:-app}"

if [ ! -d "$APP_DIR/node_modules/@tetherto/pear-wrk-wdk" ]; then
  echo "ERROR: $APP_DIR/node_modules/@tetherto/pear-wrk-wdk not found"
  echo "  Run ./setup.sh first"
  exit 1
fi

WDK_DIR="$APP_DIR/node_modules/@tetherto/pear-wrk-wdk"
PROVIDER_DIR="$APP_DIR/node_modules/@tetherto/wdk-react-native-provider"

echo "📦 Rebuilding worklet bundle from app's dependency tree..."

# Build from app root so module resolution uses app's node_modules
cd "$APP_DIR"
npx bare-pack --host ios-arm64 --linked \
  --imports "$WDK_DIR/pack.imports.json" \
  --out "$WDK_DIR/bundle/wdk-worklet.mobile.bundle.js" \
  "$WDK_DIR/src/wdk-worklet.js"

SIZE=$(ls -lh "$WDK_DIR/bundle/wdk-worklet.mobile.bundle.js" | awk '{print $5}')
echo "  ✓ Bundle rebuilt ($SIZE)"

# Deploy to provider
cp "$WDK_DIR/bundle/wdk-worklet.mobile.bundle.js" \
   "$PROVIDER_DIR/lib/module/services/wdk-service/wdk-worklet.mobile.bundle.js" 2>/dev/null || true
cp "$WDK_DIR/bundle/wdk-worklet.mobile.bundle.js" \
   "$PROVIDER_DIR/src/services/wdk-service/wdk-worklet.mobile.bundle.js" 2>/dev/null || true

echo "  ✓ Bundle deployed to provider"

# ── Also rebuild the secret manager bundle ──────────────────────────────
# The secret manager bundle ships pre-built in wdk-react-native-provider
# with pinned addon versions. When npm overrides change addon versions,
# this bundle must be rebuilt to match.
echo ""
echo "📦 Rebuilding secret manager bundle..."

npx bare-pack \
  --host ios-arm64 \
  --linked \
  --out "$PROVIDER_DIR/lib/module/services/wdk-service/wdk-secret-manager-worklet.bundle.js" \
  "$PROVIDER_DIR/src/worklet/wdk-secret-manager-worklet.js"

SM_SIZE=$(ls -lh "$PROVIDER_DIR/lib/module/services/wdk-service/wdk-secret-manager-worklet.bundle.js" | awk '{print $5}')
echo "  ✓ Secret manager bundle rebuilt ($SM_SIZE)"

echo ""
echo "  Now rebuild the app: cd $APP_DIR && npx expo run:ios"
