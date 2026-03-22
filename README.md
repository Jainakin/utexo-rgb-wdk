# Utexo RGB-WDK

RGB protocol integration for the Wallet Development Kit (WDK) — a React Native app with native RGB wallet operations via bare worklets.

## Quick Start

```bash
git clone https://github.com/Jainakin/utexo-rgb-wdk.git
cd utexo-rgb-wdk
cp .env.example .env   # Edit with your WDK Indexer API key
./setup.sh
cd app
npx expo run:ios
```

## What This Does

Makes RGB a plug-and-play chain in WDK's bare worklet system, callable from React Native via HRPC (Hypercore RPC). The architecture:

```
React Native UI  ←→  HRPC (binary IPC)  ←→  Bare Worklet  ←→  rgb-lib (Rust C FFI)
     (JS)              (bare-ipc)           (JavaScriptCore)      (native .a)
```

### 39 RGB HRPC Methods

| Category | Methods |
|----------|---------|
| **Wallet** | init, balance, getAddress, sync, goOnline |
| **Assets** | listAssets, issueAssetNIA/CFA/UDA, listTransfers, listTransactions |
| **Send/Receive** | blindReceive, witnessReceive, send, sendBegin/End |
| **UTXOs** | createUtxos, createUtxosBegin/End, listUnspents |
| **Invoices** | invoiceNew, invoiceData, invoiceString, decodeInvoice |
| **PSBT** | signPsbt, finalizePsbt, sendBtcBegin/End |
| **Maintenance** | refresh, inflate, backup, restore, failTransfers, deleteTransfers |

## Repository Structure

This umbrella repo provides setup scripts. The actual code lives in these forks:

| Repo | What | Changes |
|------|------|---------|
| [rgb-lib-bare](https://github.com/Jainakin/rgb-lib-bare) | Bare native addon (C++ → Rust FFI) | **New repo** |
| [pear-wrk-wdk](https://github.com/Jainakin/pear-wrk-wdk) | HRPC spec + worklet handlers | +3,500 lines on `rgb-wdk-integration` |
| [wdk-wallet-rgb](https://github.com/Jainakin/wdk-wallet-rgb) | RGB wallet account logic | Modified on `rgb-wdk-integration` |
| [rgb-sdk](https://github.com/Jainakin/rgb-sdk) | RGB SDK (TypeScript) | Bare compat fixes on `rgb-wdk-integration` |
| [wdk-starter-react-native](https://github.com/Jainakin/wdk-starter-react-native) | React Native app | RGB test screen on `rgb-wdk-integration` |

## Scripts

| Script | Purpose |
|--------|---------|
| `setup.sh` | One-command setup (clone → install → prebuild) |
| `rebuild-bundle.sh` | Rebuild worklet bundle after source changes |
| `build-libs.sh` | Compile Rust C-FFI from source (advanced) |

## Prerequisites

- **macOS** with Xcode 15+ and iOS SDK (for iOS builds)
- **Node.js 20+** and npm
- **CocoaPods** (`brew install cocoapods`)
- **`gh` CLI** (`brew install gh`) — authenticated, for binary downloads from GitHub Releases
- iOS Simulator or physical device
- WDK Indexer API key (get from WDK/Tether team)

## Environment Variables

Copy `.env.example` to `.env` and fill in your API key:

```bash
cp .env.example .env
```

| Variable | Required | Description |
|----------|----------|-------------|
| `WDK_INDEXER_API_KEY` | Yes | API key for the WDK indexer service |

The app also reads RGB-specific config from the embedded `.env` in the app repo (network, indexer URL, transport endpoint). These are pre-configured for mainnet.

## How It Works

### setup.sh

1. Clones `wdk-starter-react-native` into `app/`
2. Copies `.env` into the app
3. Runs `npm install` (downloads ~600MB of pre-built native binaries from GitHub Releases)
4. Rebuilds both JS worklet bundles (WDK + secret manager) so native addon version refs match the installed packages
5. Runs `expo prebuild` for iOS
6. Runs `bare-link` to create xcframeworks from native addon prebuilds
7. Runs `pod install`

### Making Changes

After modifying source code in any of the dependency repos:

```bash
# Rebuild worklet bundles (picks up changes to pear-wrk-wdk, wdk-wallet-rgb, rgb-sdk)
./rebuild-bundle.sh

# Then rebuild the app
cd app && npx expo run:ios
```

### Building Native Libraries from Source

Only needed if modifying `rgb-lib-bare` C++ bindings or the Rust FFI layer. Requires Rust toolchain.

```bash
./build-libs.sh ios        # Cross-compile for iOS
./build-libs.sh prebuilds  # Build .bare prebuilds
./build-libs.sh release    # Upload to GitHub Release
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `pod install` UTF-8 error | `export LANG=en_US.UTF-8` before running |
| ADDON_NOT_FOUND at runtime | Run `./rebuild-bundle.sh` to realign bundle addon refs |
| `gh` auth error during npm install | Run `gh auth login` first |
| Xcode build fails on signing | Open `app/ios/*.xcworkspace` in Xcode, set your team |

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  React Native App (wdk-starter-react-native)        │
│  ┌───────────────────────────────────────────────┐  │
│  │  WDKProvider (wdk-react-native-provider)      │  │
│  │  ┌─────────────────────────────────────────┐  │  │
│  │  │  Bare Worklet (pear-wrk-wdk)            │  │  │
│  │  │  ┌───────────────────────────────────┐  │  │  │
│  │  │  │  WdkManager → RGB handlers       │  │  │  │
│  │  │  │  ┌─────────────────────────────┐  │  │  │  │
│  │  │  │  │  wdk-wallet-rgb             │  │  │  │  │
│  │  │  │  │  ┌───────────────────────┐  │  │  │  │  │
│  │  │  │  │  │  rgb-lib-bare (C FFI) │  │  │  │  │  │
│  │  │  │  │  │  → librgblibcffi.a    │  │  │  │  │  │
│  │  │  │  │  └───────────────────────┘  │  │  │  │  │
│  │  │  │  └─────────────────────────────┘  │  │  │  │
│  │  │  └───────────────────────────────────┘  │  │  │
│  │  └─────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```
