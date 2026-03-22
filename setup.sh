#!/bin/bash
set -euo pipefail

# ============================================================================
# Utexo RGB-WDK Setup
# One-command setup: clone → install → prebuild → ready to run
# ============================================================================

REPO="Jainakin/wdk-starter-react-native"
BRANCH="rgb-wdk-integration"
APP_DIR="app"

echo ""
echo "  ╔══════════════════════════════════════╗"
echo "  ║      Utexo RGB-WDK Setup             ║"
echo "  ╚══════════════════════════════════════╝"
echo ""

# ── Step 1: Clone the React Native app ──────────────────────────────────────
if [ ! -d "$APP_DIR" ]; then
  echo "📦 Cloning $REPO ($BRANCH)..."
  git clone -b "$BRANCH" "https://github.com/$REPO.git" "$APP_DIR"
else
  echo "📦 App directory exists, pulling latest..."
  cd "$APP_DIR" && git pull origin "$BRANCH" 2>/dev/null || true && cd ..
fi

# ── Step 2: Environment file ────────────────────────────────────────────────
if [ ! -f "$APP_DIR/.env" ]; then
  if [ -f ".env" ]; then
    cp .env "$APP_DIR/.env"
    echo "🔑 Copied .env → app/.env"
  elif [ -f ".env.example" ]; then
    cp .env.example "$APP_DIR/.env"
    echo ""
    echo "  ⚠️  Edit app/.env with your WDK Indexer API key"
    echo "     (see .env.example for the format)"
    echo ""
  fi
else
  echo "🔑 app/.env exists, skipping"
fi

# ── Step 3: Install JS dependencies ─────────────────────────────────────────
echo ""
echo "📥 Installing dependencies (this downloads ~600MB of native binaries)..."
cd "$APP_DIR"
npm install

# ── Step 4: Rebuild worklet bundles ───────────────────────────────────────
# Both bundles ship pre-built with hardcoded addon version refs. Rebuilding
# them from the app's node_modules ensures linked addon refs match exactly
# what bare-link creates as xcframeworks. Without this, version mismatches
# cause ADDON_NOT_FOUND errors at runtime.
echo ""
WDK_DIR="node_modules/@tetherto/pear-wrk-wdk"
PROVIDER_DIR="node_modules/@tetherto/wdk-react-native-provider"

echo "🔄 Rebuilding WDK worklet bundle..."
npx bare-pack \
  --host ios-arm64 \
  --linked \
  --imports "$WDK_DIR/pack.imports.json" \
  --out "$WDK_DIR/bundle/wdk-worklet.mobile.bundle.js" \
  "$WDK_DIR/src/wdk-worklet.js"
# Deploy to provider locations
cp "$WDK_DIR/bundle/wdk-worklet.mobile.bundle.js" \
   "$PROVIDER_DIR/lib/module/services/wdk-service/wdk-worklet.mobile.bundle.js" 2>/dev/null || true
cp "$WDK_DIR/bundle/wdk-worklet.mobile.bundle.js" \
   "$PROVIDER_DIR/src/services/wdk-service/wdk-worklet.mobile.bundle.js" 2>/dev/null || true
echo "  ✓ WDK bundle rebuilt and deployed"

echo "🔄 Rebuilding secret manager bundle..."
npx bare-pack \
  --host ios-arm64 \
  --linked \
  --out "$PROVIDER_DIR/lib/module/services/wdk-service/wdk-secret-manager-worklet.bundle.js" \
  "$PROVIDER_DIR/src/worklet/wdk-secret-manager-worklet.js"
echo "  ✓ Secret manager bundle rebuilt"

# ── Step 5: Verify critical files ───────────────────────────────────────────
echo ""
echo "🔍 Verifying installation..."

ERRORS=0

check_file() {
  if [ -f "$1" ]; then
    echo "  ✓ $2"
  else
    echo "  ✗ MISSING: $2 ($1)"
    ERRORS=$((ERRORS + 1))
  fi
}

check_file "node_modules/@utexo/rgb-lib-bare/lib/ios-arm64/librgblibcffi.a" "RGB static lib (iOS arm64)"
check_file "node_modules/@utexo/rgb-lib-bare/prebuilds/ios-arm64/utexo__rgb-lib-bare.bare" "Bare addon prebuild (iOS arm64)"
check_file "node_modules/@tetherto/pear-wrk-wdk/bundle/wdk-worklet.mobile.bundle.js" "Worklet bundle"
check_file "node_modules/@tetherto/wdk-react-native-provider/lib/module/services/wdk-service/wdk-worklet.mobile.bundle.js" "Bundle deployed to provider"
check_file "node_modules/@tetherto/pear-wrk-wdk/spec/hrpc/index.js" "HRPC spec"

if [ $ERRORS -gt 0 ]; then
  echo ""
  echo "  ❌ $ERRORS files missing. Try: rm -rf node_modules && npm install"
  exit 1
fi

# ── Step 6: iOS prebuild ────────────────────────────────────────────────────
echo ""
echo "🍎 Running Expo prebuild for iOS..."
npx expo prebuild --platform ios 2>&1 | tail -5

# ── Step 7: Link native addons ────────────────────────────────────────────
# bare-link creates xcframeworks from prebuild binaries for all native
# bare addons. This must run before pod install so CocoaPods vendors them.
echo ""
echo "🔗 Linking native addons (creating xcframeworks)..."
node node_modules/react-native-bare-kit/ios/link.js
echo "  ✓ $(ls node_modules/react-native-bare-kit/ios/addons/*.xcframework 2>/dev/null | wc -l | tr -d ' ') xcframeworks created"

echo ""
echo "📲 Installing CocoaPods..."
cd ios && LANG=en_US.UTF-8 pod install 2>&1 | tail -5 && cd ..

# ── Done ────────────────────────────────────────────────────────────────────
echo ""
echo "  ╔══════════════════════════════════════╗"
echo "  ║      ✅ Setup Complete!               ║"
echo "  ╚══════════════════════════════════════╝"
echo ""
echo "  Next steps:"
echo "    cd app"
echo "    npx expo run:ios          # Build and run on iOS simulator"
echo "    npx expo run:ios --device # Build and run on physical device"
echo ""
echo "  In the app:"
echo "    1. Create or import a wallet"
echo "    2. Navigate to RGB test screen"
echo "    3. Tap Init → Balance → List Assets"
echo ""
