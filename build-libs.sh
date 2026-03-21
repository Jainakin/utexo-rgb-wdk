#!/bin/bash
set -euo pipefail

# ============================================================================
# Build RGB static libraries from Rust source
#
# This script compiles librgblibcffi.a for all target platforms and generates
# the .bare native addon prebuilds. Only needed if you're modifying the
# Rust C-FFI or binding.cc — most developers should use the pre-built
# binaries from GitHub Releases (downloaded automatically by npm install).
#
# Prerequisites:
#   - Rust toolchain: rustup target add aarch64-apple-ios aarch64-apple-ios-sim
#   - Xcode with iOS SDK
#   - CMake 3.25+
#   - rgb-lib-nodejs repo (cloned automatically if missing)
#
# Usage:
#   ./build-libs.sh           # Build everything
#   ./build-libs.sh ios       # iOS targets only
#   ./build-libs.sh prebuilds # .bare addons only (requires libs built first)
#   ./build-libs.sh release   # Build + upload to GitHub Release
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RGB_LIB_BARE="${SCRIPT_DIR}/app/node_modules/@utexo/rgb-lib-bare"
MODE="${1:-all}"

# Clone rgb-lib-nodejs if not present (needed for Rust source)
if [ ! -d "${SCRIPT_DIR}/rgb-lib-nodejs" ]; then
  echo "📥 Cloning rgb-lib-nodejs (Rust C-FFI source)..."
  git clone https://github.com/UTEXO-Protocol/rgb-lib-nodejs.git "${SCRIPT_DIR}/rgb-lib-nodejs"
fi

CFFI_DIR="${SCRIPT_DIR}/rgb-lib-nodejs/rgb-lib/bindings/c-ffi"

if [ "$MODE" = "all" ] || [ "$MODE" = "ios" ]; then
  echo ""
  echo "🔧 Building static libraries..."
  CFFI_DIR="$CFFI_DIR" bash "$RGB_LIB_BARE/scripts/build-ios.sh"
fi

if [ "$MODE" = "all" ] || [ "$MODE" = "prebuilds" ]; then
  echo ""
  echo "🔧 Building .bare prebuilds..."
  bash "$RGB_LIB_BARE/scripts/build-prebuilds.sh"
fi

if [ "$MODE" = "release" ]; then
  echo ""
  echo "📤 Uploading to GitHub Release..."
  VERSION=$(node -p "require('$RGB_LIB_BARE/package.json').version")
  REPO="Jainakin/rgb-lib-bare"

  gh release create "v$VERSION" --repo "$REPO" --title "v$VERSION" --notes "Pre-built binaries" 2>/dev/null || true

  for platform in ios-arm64 ios-arm64-simulator darwin-arm64; do
    if [ -f "$RGB_LIB_BARE/lib/$platform/librgblibcffi.a" ]; then
      cp "$RGB_LIB_BARE/lib/$platform/librgblibcffi.a" "/tmp/librgblibcffi-$platform.a"
      gh release upload "v$VERSION" "/tmp/librgblibcffi-$platform.a" --repo "$REPO" --clobber
      echo "  ✓ librgblibcffi-$platform.a"
    fi
    if [ -f "$RGB_LIB_BARE/prebuilds/$platform/utexo__rgb-lib-bare.bare" ]; then
      cp "$RGB_LIB_BARE/prebuilds/$platform/utexo__rgb-lib-bare.bare" "/tmp/utexo__rgb-lib-bare-$platform.bare"
      gh release upload "v$VERSION" "/tmp/utexo__rgb-lib-bare-$platform.bare" --repo "$REPO" --clobber
      echo "  ✓ utexo__rgb-lib-bare-$platform.bare"
    fi
  done

  echo "  ✅ Release v$VERSION updated"
fi

echo ""
echo "✅ Done!"
