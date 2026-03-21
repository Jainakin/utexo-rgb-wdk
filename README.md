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

- macOS with Xcode (iOS SDK)
- Node.js 20+
- `gh` CLI (for binary downloads)
- iOS device or simulator
- WDK Indexer API key

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
