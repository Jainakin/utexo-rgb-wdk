#!/bin/bash
set -euo pipefail

# ============================================================================
# Rebuild the worklet bundle after source changes
#
# Run this after modifying any of:
#   - pear-wrk-wdk/src/wdk-worklet.js
#   - pear-wrk-wdk/src/wdk-core/wdk-manager.js
#   - pear-wrk-wdk/spec/hrpc/*
# ============================================================================

APP_DIR="${1:-app}"

if [ ! -d "$APP_DIR/node_modules/@tetherto/pear-wrk-wdk" ]; then
  echo "ERROR: $APP_DIR/node_modules/@tetherto/pear-wrk-wdk not found"
  echo "  Run ./setup.sh first"
  exit 1
fi

WDK_DIR="$APP_DIR/node_modules/@tetherto/pear-wrk-wdk"

echo "📦 Rebuilding worklet bundle..."
cd "$WDK_DIR"
npx bare-pack --host ios-arm64 --linked --imports ./pack.imports.json \
  --out bundle/wdk-worklet.mobile.bundle.js src/wdk-worklet.js

SIZE=$(ls -lh bundle/wdk-worklet.mobile.bundle.js | awk '{print $5}')
echo "  ✓ Bundle rebuilt ($SIZE)"

# Deploy to provider
PROVIDER_DIR="$APP_DIR/node_modules/@tetherto/wdk-react-native-provider"
cp bundle/wdk-worklet.mobile.bundle.js "$PROVIDER_DIR/lib/module/services/wdk-service/wdk-worklet.mobile.bundle.js" 2>/dev/null || true
cp bundle/wdk-worklet.mobile.bundle.js "$PROVIDER_DIR/src/services/wdk-service/wdk-worklet.mobile.bundle.js" 2>/dev/null || true

echo "  ✓ Bundle deployed to provider"
echo ""
echo "  Now rebuild the app: cd $APP_DIR && npx expo run:ios"
