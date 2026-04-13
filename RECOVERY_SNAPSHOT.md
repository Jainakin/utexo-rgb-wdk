# Recovery Snapshot — 2026-04-14

Last known working state. Fresh clone + `./setup.sh` + `npx expo run:ios` verified.

## Architecture

- No `@utexo/rgb-sdk` fork — replaced with `@utexo/rgb-sdk-core` (npm) + `BareRgbLibBinding`
- Lightning/bridge methods removed per team guidance
- `rgbSendBtcBegin/End` removed (C FFI functions removed in rgb-lib dev branch)
- 47 HRPC methods, 39 tests passing in wdk-wallet-rgb

## Repos & Commits

| Repo | Branch | Commit | URL |
|------|--------|--------|-----|
| **utexo-rgb-wdk** (umbrella) | `main` | `1f5fc52` | https://github.com/Jainakin/utexo-rgb-wdk |
| **wdk-starter-react-native** | `rgb-wdk-integration` | `7d987d6` | https://github.com/Jainakin/wdk-starter-react-native/tree/rgb-wdk-integration |
| **pear-wrk-wdk** | `rgb-wdk-integration` | `56e2bde` | https://github.com/Jainakin/pear-wrk-wdk/tree/rgb-wdk-integration |
| **wdk-wallet-rgb** | `rgb-wdk-integration` | `10907e7` | https://github.com/Jainakin/wdk-wallet-rgb/tree/rgb-wdk-integration |
| **rgb-lib-bare** | `main` | `36c83a1` | https://github.com/UTEXO-Protocol/rgb-lib-bare |

Note: `Jainakin/rgb-sdk` fork is **no longer used**. Dependency eliminated in favor of `@utexo/rgb-sdk-core` from npm.

## GitHub Release (Binary Assets)

**Repo:** `UTEXO-Protocol/rgb-lib-bare`
**Tag:** `v0.3.0-beta.15`
**URL:** https://github.com/UTEXO-Protocol/rgb-lib-bare/releases/tag/v0.3.0-beta.15

16 assets (8 static libs + 8 prebuilds):

| Platform | Static lib | Prebuild |
|----------|-----------|----------|
| iOS arm64 (device) | librgblibcffi-ios-arm64.a | utexo__rgb-lib-bare-ios-arm64.bare |
| iOS arm64 (sim) | librgblibcffi-ios-arm64-simulator.a | utexo__rgb-lib-bare-ios-arm64-simulator.bare |
| iOS x64 (sim) | librgblibcffi-ios-x64-simulator.a | utexo__rgb-lib-bare-ios-x64-simulator.bare |
| macOS arm64 | librgblibcffi-darwin-arm64.a | utexo__rgb-lib-bare-darwin-arm64.bare |
| Android arm64 | librgblibcffi-android-arm64.a | utexo__rgb-lib-bare-android-arm64.bare |
| Android arm | librgblibcffi-android-arm.a | utexo__rgb-lib-bare-android-arm.bare |
| Android x64 | librgblibcffi-android-x64.a | utexo__rgb-lib-bare-android-x64.bare |
| Android ia32 | librgblibcffi-android-ia32.a | utexo__rgb-lib-bare-android-ia32.bare |

## How to Restore

```bash
git clone https://github.com/Jainakin/utexo-rgb-wdk.git
cd utexo-rgb-wdk
echo "WDK_INDEXER_API_KEY=<your-key>" > .env
./setup.sh
cd app
export LANG=en_US.UTF-8
npx expo run:ios
```

## Dependency Chain

```
utexo-rgb-wdk (umbrella)
  └── setup.sh clones → wdk-starter-react-native (the React Native app)
       └── package.json deps:
            ├── @tetherto/pear-wrk-wdk  → Jainakin/pear-wrk-wdk
            │    └── @utexo/wdk-wallet-rgb → Jainakin/wdk-wallet-rgb
            │         ├── @utexo/rgb-sdk-core → npm (1.0.0-beta.3)
            │         └── @utexo/rgb-lib-bare → UTEXO-Protocol/rgb-lib-bare
            │              └── postinstall: download-libs.sh fetches from GitHub Release
            └── @tetherto/wdk-secret-manager → npm (^1.0.0-beta.3)
```

## Open PRs

| PR | Repo | Status |
|---|---|---|
| #7 | UTEXO-Protocol/rgb-sdk-core | Waiting approval (lint fixed) |
| #3 | UTEXO-Protocol/wdk-wallet-rgb | Waiting branch naming decision |
| #12 | UTEXO-Protocol/rgb-lib-nodejs | Waiting review |
