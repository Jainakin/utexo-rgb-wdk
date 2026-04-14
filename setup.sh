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

# ── Step 4: Rebuild worklet bundles (multi-platform) ───────────────────────
# The WDK main bundle ships pre-built in pear-wrk-wdk with both iOS and
# Android addon refs — no rebuild needed.
# The secret manager bundle ships in wdk-react-native-provider with OLD
# addon versions, so it MUST be rebuilt for both platforms.
echo ""
PROVIDER_DIR="node_modules/@tetherto/wdk-react-native-provider"
SM_SRC="$PROVIDER_DIR/src/worklet/wdk-secret-manager-worklet.js"
SM_OUT="$PROVIDER_DIR/lib/module/services/wdk-service/wdk-secret-manager-worklet.bundle.js"

echo "🔄 Rebuilding secret manager bundle (iOS + Android)..."
npx bare-pack --host ios-arm64 --linked --out /tmp/_sm_ios.bundle "$SM_SRC"
npx bare-pack --host android-arm64 --linked --out /tmp/_sm_android.bundle "$SM_SRC"

# Merge iOS + Android bundles into one multi-platform bundle
node -e '
const fs = require("fs");
function parse(p) {
  const r = fs.readFileSync(p, "utf8");
  const n1 = r.indexOf("\n"), n2 = r.indexOf("\n", n1+1);
  return { meta: JSON.parse(r.substring(n1+1, n2)), code: r.substring(n2+1) };
}
const ios = parse("/tmp/_sm_ios.bundle"), android = parse("/tmp/_sm_android.bundle");
const m = JSON.parse(JSON.stringify(ios.meta));
m.addons = [...new Set([...ios.meta.addons, ...android.meta.addons])];
for (const k of Object.keys(ios.meta.resolutions)) {
  if (JSON.stringify(ios.meta.resolutions[k]) !== JSON.stringify(android.meta.resolutions[k])) {
    m.resolutions[k] = { ...ios.meta.resolutions[k] };
    m.resolutions[k]["."] = { ios: ios.meta.resolutions[k]["."], android: android.meta.resolutions[k]["."] };
  }
}
const j = JSON.stringify(m), len = 1 + Buffer.byteLength(j, "utf8") + 1;
const raw = len + "\n" + j + "\n" + ios.code;
const esc = raw.replace(/\\/g,"\\\\").replace(/"/g,"\\\x22").replace(/\r/g,"\\r").replace(/\n/g,"\\n");
fs.writeFileSync(process.argv[1], "module.exports = \"" + esc + "\"");
' "$SM_OUT"
rm -f /tmp/_sm_ios.bundle /tmp/_sm_android.bundle
echo "  ✓ Secret manager bundle rebuilt (multi-platform)"

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
check_file "node_modules/@utexo/rgb-lib-bare/prebuilds/android-arm64/utexo__rgb-lib-bare.bare" "Bare addon prebuild (Android arm64)"
check_file "node_modules/@tetherto/pear-wrk-wdk/bundle/wdk-worklet.mobile.bundle.js" "Worklet bundle"
check_file "node_modules/@tetherto/wdk-react-native-provider/lib/module/services/wdk-service/wdk-worklet.mobile.bundle.js" "Bundle deployed to provider"
check_file "node_modules/@tetherto/pear-wrk-wdk/spec/hrpc/index.js" "HRPC spec"

if [ $ERRORS -gt 0 ]; then
  echo ""
  echo "  ❌ $ERRORS files missing. Try: rm -rf node_modules && npm install"
  exit 1
fi

# ── Step 6: Expo prebuild ──────────────────────────────────────────────────
echo ""
echo "🍎 Running Expo prebuild for iOS..."
npx expo prebuild --platform ios 2>&1 | tail -5

echo ""
echo "🤖 Running Expo prebuild for Android..."
npx expo prebuild --platform android 2>&1 | tail -5

# ── Step 7: Link native addons (iOS) ────────────────────────────────────────
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
echo "    npx expo run:ios              # Build and run on iOS simulator"
echo "    npx expo run:android          # Build and run on Android emulator"
echo ""
echo "  In the app:"
echo "    1. Create or import a wallet"
echo "    2. Navigate to RGB test screen"
echo "    3. Tap Init → Balance → List Assets"
echo ""
