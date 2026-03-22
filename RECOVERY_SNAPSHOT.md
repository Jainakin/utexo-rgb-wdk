# Recovery Snapshot — 2026-03-22

Last known working state. All repos verified: fresh clone → `./setup.sh` → `npx expo run:ios` → app launches, RGB init works.

## Repos & Commits

| Repo | Branch | Commit | URL |
|------|--------|--------|-----|
| **utexo-rgb-wdk** (umbrella) | `main` | `73ce54f` | https://github.com/Jainakin/utexo-rgb-wdk/tree/73ce54f |
| **wdk-starter-react-native** | `rgb-wdk-integration` | `f15b9d4` | https://github.com/Jainakin/wdk-starter-react-native/tree/f15b9d4 |
| **pear-wrk-wdk** | `rgb-wdk-integration` | `e0d6ec4` | https://github.com/Jainakin/pear-wrk-wdk/tree/e0d6ec4 |
| **wdk-wallet-rgb** | `rgb-wdk-integration` | `d90dbde` | https://github.com/Jainakin/wdk-wallet-rgb/tree/d90dbde |
| **rgb-sdk** | `rgb-wdk-integration` | `0b5eb19` | https://github.com/Jainakin/rgb-sdk/tree/0b5eb19 |
| **rgb-lib-bare** | `main` | `cfe0a85` | https://github.com/Jainakin/rgb-lib-bare/tree/cfe0a85 |

## GitHub Release (Binary Assets)

**Repo:** `Jainakin/rgb-lib-bare`
**Tag:** `v0.3.0-beta.13`
**URL:** https://github.com/Jainakin/rgb-lib-bare/releases/tag/v0.3.0-beta.13

| Asset | Platform | Type |
|-------|----------|------|
| `librgblibcffi-ios-arm64.a` | iOS device | Static lib (136MB) |
| `librgblibcffi-ios-arm64-simulator.a` | iOS simulator (ARM) | Static lib |
| `librgblibcffi-ios-x64-simulator.a` | iOS simulator (Intel) | Static lib |
| `librgblibcffi-android-arm64.a` | Android arm64 | Static lib |
| `librgblibcffi-darwin-arm64.a` | macOS (dev builds) | Static lib |
| `utexo__rgb-lib-bare-ios-arm64.bare` | iOS device | Bare addon prebuild |
| `utexo__rgb-lib-bare-ios-arm64-simulator.bare` | iOS simulator (ARM) | Bare addon prebuild |
| `utexo__rgb-lib-bare-ios-x64-simulator.bare` | iOS simulator (Intel) | Bare addon prebuild |
| `utexo__rgb-lib-bare-darwin-arm64.bare` | macOS | Bare addon prebuild |

## How to Restore

```bash
# 1. Clone umbrella at this exact commit
git clone https://github.com/Jainakin/utexo-rgb-wdk.git
cd utexo-rgb-wdk
git checkout 73ce54f

# 2. Add your .env
echo "WDK_INDEXER_API_KEY=<your-key>" > .env

# 3. Run setup (clones app at the pinned commit, installs deps, rebuilds bundles, runs pod install)
./setup.sh

# 4. Build & run
cd app
export LANG=en_US.UTF-8
npx expo run:ios
```

## Dependency Chain

```
utexo-rgb-wdk (umbrella)
  └── setup.sh clones → wdk-starter-react-native (the React Native app)
       └── package.json deps:
            ├── @tetherto/pear-wrk-wdk  → Jainakin/pear-wrk-wdk#e0d6ec4
            │    └── @utexo/wdk-wallet-rgb → Jainakin/wdk-wallet-rgb#d90dbde
            │         └── @utexo/rgb-sdk   → Jainakin/rgb-sdk#0b5eb19
            ├── @utexo/rgb-lib-bare     → Jainakin/rgb-lib-bare#cfe0a85
            │    └── postinstall: download-libs.sh fetches binaries from GitHub Release
            └── @tetherto/wdk-secret-manager → npm (^1.0.0-beta.3)
```

## Key Notes

- **npm overrides** in `wdk-starter-react-native/package.json` pin 18 bare addon versions to match the pre-built WDK worklet bundle
- **Secret manager bundle** is rebuilt during `setup.sh` via `bare-pack` to match current addon versions
- **WDK main bundle** is NOT rebuilt (uses pre-built from pear-wrk-wdk) — rebuilding fails because bare-pack traverses unrelated TON/EVM deps
- **Native binaries** (135MB static libs) are downloaded from GitHub Release, never built on developer machines
