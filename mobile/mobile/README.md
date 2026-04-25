# Sentio Mobile

React Native (Expo) companion app for the Sentio EEG wearable system.
Connects to the same WebSocket stream as the web dashboard and displays
live brain-state data — emotion, EEG bands, AI guidance, and AI-generated
LED pattern details — on any Android, iOS, or web device.

---

## Features

| Screen | What it shows |
|--------|---------------|
| **Live** | Animated emotion ring, AI guidance sentence, EEG band bars, signal quality, vitals, AI pattern card |
| **History** | EEG band sparkline chart (last 60 frames) + emotion change timeline |
| **Settings** | Backend host/port (persisted), reconnect button, connection guide |

---

## Prerequisites

- [Node.js](https://nodejs.org/) 18 or later
- [Expo CLI](https://docs.expo.dev/get-started/installation/) — installed automatically via `npx`
- The **Sentio Python backend** running and reachable on the same network
- For physical device: **Expo Go** app ([Android](https://play.google.com/store/apps/details?id=host.exp.exponent) · [iOS](https://apps.apple.com/app/expo-go/id982107779))
- For Android emulator: [Android Studio](https://developer.android.com/studio) with an AVD configured
- For iOS simulator: [Xcode](https://developer.apple.com/xcode/) (macOS only)

---

## Installation

```bash
# from the repo root
cd mobile
npm install
```

---

## Running locally

### Start the Expo development server

```bash
cd mobile
npx expo start
```

This opens the **Expo Developer Tools** in your terminal. From there choose your target:

---

### Android

**Option A — Physical device (recommended, any OS)**

1. Install [Expo Go](https://play.google.com/store/apps/details?id=host.exp.exponent) on your Android phone.
2. Make sure your phone is on the **same WiFi network** as your development machine.
3. Run `npx expo start`, then scan the QR code shown in the terminal with the Expo Go app.

**Option B — Android emulator (Android Studio required)**

1. Open Android Studio → **Virtual Device Manager** → start an AVD.
2. With the emulator running, press **`a`** in the Expo terminal (or run `npx expo start --android`).

```bash
npx expo start --android
```

> **Backend tip for emulator:** the emulator maps `10.0.2.2` to your host machine's `localhost`. If your backend runs on `localhost:8000`, set the host in **Settings** to `10.0.2.2`.

---

### iOS

> iOS simulator requires **macOS + Xcode**. Physical device testing requires a paid Apple Developer account.

**Option A — Physical device (Expo Go)**

1. Install [Expo Go](https://apps.apple.com/app/expo-go/id982107779) from the App Store.
2. Run `npx expo start` and scan the QR code with the **iPhone Camera** app (it will open Expo Go automatically).

**Option B — iOS Simulator (macOS only)**

1. Install Xcode from the Mac App Store and open it once to accept the licence.
2. Press **`i`** in the Expo terminal (or run `npx expo start --ios`).

```bash
npx expo start --ios
```

---

### Web

No native tooling required — the app runs in a browser via React Native Web.

```bash
npx expo start --web
```

Open [http://localhost:8081](http://localhost:8081) in your browser. Most features work; native-only APIs (e.g. certain animations) fall back gracefully.

---

## Connecting to the Sentio backend

1. Start the Sentio Python backend:
   ```bash
   cd ../backend
   uvicorn main:app --host 0.0.0.0 --port 8000
   ```
2. Find your computer's local IP address:
   - **macOS / Linux:** `ifconfig | grep "inet "`
   - **Windows:** `ipconfig` → look for IPv4 Address
3. Open the **Settings** tab in the mobile app.
4. Enter the backend IP (e.g. `192.168.1.42`) and port (`8000`).
5. Tap **Save & Reconnect**.
6. The connection dot on the **Live** screen turns cyan when the WebSocket is live.

> The host and port are saved to device storage — you only need to set them once.

---

## Project structure

```
mobile/
├── App.tsx                          # Root: SentioProvider + bottom-tab navigator
├── app.json                         # Expo config (name, icons, splash)
├── src/
│   ├── hooks/
│   │   └── useSentioWebSocket.ts    # WebSocket hook — auto-reconnect, frame parsing
│   ├── lib/
│   │   ├── runtimeConfig.ts         # AsyncStorage: host/port persistence
│   │   └── SentioContext.tsx        # React context: single shared WS connection
│   ├── components/
│   │   ├── EmotionRing.tsx          # Animated pulsing colour ring
│   │   ├── BandBars.tsx             # EEG band progress bars
│   │   ├── StatRow.tsx              # Horizontal stat cards
│   │   └── ConnectionBanner.tsx     # Offline / waiting banner
│   ├── screens/
│   │   ├── DashboardScreen.tsx      # Live view (emotion ring, guidance, bands…)
│   │   ├── HistoryScreen.tsx        # Band sparklines + emotion timeline
│   │   └── SettingsScreen.tsx       # Backend IP/port config
│   └── theme/
│       └── index.ts                 # Design tokens (colours, spacing, radius)
├── assets/                          # App icons and splash
└── package.json
```

---

## Available scripts

| Command | Description |
|---------|-------------|
| `npx expo start` | Start dev server (scan QR with Expo Go) |
| `npx expo start --android` | Launch on Android emulator / device |
| `npx expo start --ios` | Launch on iOS simulator (macOS only) |
| `npx expo start --web` | Open in browser |

---

## Tech stack

| Layer | Technology |
|-------|------------|
| Framework | [Expo](https://expo.dev) SDK 54 |
| Runtime | React Native 0.81 |
| Language | TypeScript |
| Navigation | React Navigation 7 (bottom tabs) |
| Storage | AsyncStorage |
| WebSocket | Native `WebSocket` (built into React Native) |
| Theme | Custom dark design tokens matching the web frontend |

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| QR code won't scan | Make sure phone and computer are on the same WiFi; try `npx expo start --tunnel` for hotspot / VPN setups |
| App shows "Connecting to backend…" | Check backend is running; confirm IP/port in Settings; check firewall allows port 8000 |
| Emulator can't reach backend | Use `10.0.2.2` (Android) or `localhost` / host machine IP (iOS simulator) |
| Metro bundler error | Delete `node_modules/` and `npm install` again |
| Expo Go version mismatch | Update Expo Go on your device to the latest version |
