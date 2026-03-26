# RGB-WDK Setup & Changes Reference

## Setup Steps

### Prerequisites
- macOS with Xcode installed
- Node.js 18+
- CocoaPods (`brew install cocoapods`)
- For Android: Android SDK + NDK 29

### iOS Setup

```bash
# 1. Clone
git clone https://github.com/Jainakin/utexo-rgb-wdk.git
cd utexo-rgb-wdk

# 2. Create .env with your WDK Indexer API key
echo "WDK_INDEXER_API_KEY=your_key_here" > .env

# 3. Run setup (clones app, installs deps, rebuilds bundles, runs pod install)
./setup.sh

# 4. Build and run
cd app
export LANG=en_US.UTF-8
npx expo run:ios
```

### Android Setup

```bash
# 1-3. Same as iOS above

# 4. Build and run
cd app
npx expo run:android
```

### What `setup.sh` does
1. Clones `Jainakin/wdk-starter-react-native` into `app/`
2. Copies `.env` into the app
3. Runs `npm install` (downloads ~600MB of native binaries from GitHub Release)
4. Rebuilds the secret manager worklet bundle (fixes addon version mismatch)
5. Verifies all critical files are present
6. Runs `npx expo prebuild --platform ios`
7. Runs `bare-link` to create xcframeworks from native addon prebuilds
8. Runs `pod install`

---

## Changes to Tether's Repos

### 1. `tetherto/pear-wrk-wdk` → `Jainakin/pear-wrk-wdk`

**Branch:** `rgb-wdk-integration` (20 commits ahead of upstream)

This is the core worklet orchestrator — the bare JavaScript runtime that handles all wallet operations via HRPC (Hypercore RPC).

| What we added | Files | Details |
|---|---|---|
| 39 RGB HRPC handlers | `spec/hrpc/hrpc.json` | Added method IDs 19-53 for all RGB operations |
| | `spec/hrpc/messages.js` (+1,674 lines) | Binary request/response encodings for each method |
| | `spec/hrpc/index.js` (+474 lines) | HRPC handler logic — receives RPC calls, delegates to wdk-manager |
| RGB methods in wdk-manager.js | `src/wdk-core/wdk-manager.js` (+364 lines) | 39 delegation methods (`rgbInit`, `rgbGetBalance`, `rgbSend`, etc.) that route calls to `wdk-wallet-rgb` via `account.methodName()` — same pattern as EVM/TON/BTC |
| Schema definitions | `src/schema/schema.js` (+99 lines) | RGB method signatures for the WDK schema system |
| Pre-built worklet bundle | `bundle/wdk-worklet.mobile.bundle.js` | ~19MB bundle with all RGB code baked in. Built with `bare-pack` using `--defer` flags for non-bare modules (axios, http2, fs, etc.) |
| UTEXO bridge stubs | `src/wdk-core/wdk-manager.js` | 5 Lightning/bridge methods route to `wdk-wallet-rgb`'s bridge API (signature-based auth, no API keys needed) |

**Key architectural decisions:**
- RGB is added as `Rgb: 'rgb'` in the blockchain enum, loaded via `await import('@utexo/wdk-wallet-rgb')`
- All 39 methods follow the existing pattern: `wdk-manager.js` gets an account via `this.getAccount('rgb', accountIndex)` then calls `account.methodName()`
- The worklet bundle is pre-built and shipped in the repo (not rebuilt on `npm install`) — npm overrides in the app's `package.json` ensure bare addon versions match the bundle's linked refs

### 2. `tetherto/wdk-starter-react-native` → `Jainakin/wdk-starter-react-native`

**Branch:** `rgb-wdk-integration` (20 commits ahead of upstream)

This is the React Native demo app that showcases all WDK functionality.

| What we added | Files | Details |
|---|---|---|
| RGB test screen | `src/app/rgb-test.tsx` (1,332 lines) | Interactive UI with cards for each RGB operation: Init, Balance, Assets, Transfers, Invoices, Send, PSBT signing. Results display inline within each card. |
| npm overrides | `package.json` | 18 bare addon version pins to match the pre-built worklet bundle (e.g., `bare-abort: 2.0.13`, `sodium-native: 5.1.0`) |
| Dependencies | `package.json` | Added `@tetherto/wdk-secret-manager` (peer dep needed for bundle rebuild), `@utexo/rgb-lib-bare` (native addon) |
| Git URL deps | `package.json` | All RGB packages reference `Jainakin/` GitHub forks via commit hash pins |
| Config updates | `src/config/assets.ts`, `src/config/get-chains-config.ts` | RGB chain configuration for the WDK provider |
| Postinstall | `package.json` | Copies worklet bundle from `pear-wrk-wdk` to `wdk-react-native-provider` locations |
| Balance/tx guard | `src/app/wallet.tsx` | Guards balance/transaction fetches behind wallet unlock state to prevent launch errors |

**Key architectural decisions:**
- The app installs all dependencies from GitHub git URLs (not npm registry) for reproducibility
- npm overrides force specific bare addon versions so xcframeworks match the pre-built bundle
- The secret manager bundle is rebuilt during `setup.sh` because it ships with old addon versions in the npm package
