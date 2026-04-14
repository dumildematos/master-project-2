# Sentio Emotional Canvas

## Description

Sentio Emotional Canvas is a frontend application for running an emotion-aware brain sensing session and translating live EEG activity into a visual fabric-pattern concept. The app guides a user through session setup, device calibration, live monitoring, and a generated pattern preview designed around the emotional state detected from the incoming brain data stream.

## What The App Does

1. Collects session details such as age, gender, pattern type, and signal sensitivity.
2. Starts a session against the backend API.
3. Runs a calibration step for the connected Muse 2 device.
4. Displays live monitoring for emotion, confidence, signal quality, and EEG or band-wave activity.
5. Generates a canvas-based textile pattern preview for the session.

## Stack

- React 18
- TypeScript
- Vite
- Tailwind CSS
- shadcn/ui and Radix UI
- Framer Motion
- TanStack Query
- Vitest

## Run Locally

```bash
npm install
npm run dev
```

The app runs through Vite and is usually available at `http://localhost:5173`.

## scrcpy

If you need to mirror and control an Android device during demos, testing, or sensor setup, `scrcpy` is a practical companion tool. This project does not invoke `scrcpy` directly, but it is useful when you want the mobile device visible from the same workstation that is running the Sentio frontend.

### Install on Windows

```powershell
winget install Genymobile.scrcpy
```

### Basic Usage

1. Enable Developer Options and USB debugging on the Android device.
2. Connect the device over USB.
3. Verify that `adb` can see the device.
4. Start `scrcpy`.

```bash
adb devices
scrcpy
```

### Wireless Usage

```bash
adb tcpip 5555
adb connect <device-ip>:5555
scrcpy --tcpip=<device-ip>:5555
```

If `adb` is not already installed on your machine, install Android platform-tools first.

## Available Commands

| Command | Purpose |
| --- | --- |
| `npm run dev` | Start the development server |
| `npm run build` | Build the app for production |
| `npm run build:dev` | Build in development mode |
| `npm run preview` | Preview the production build locally |
| `npm run lint` | Run ESLint |
| `npm run test` | Run tests once |
| `npm run test:watch` | Run tests in watch mode |

## Backend Endpoints

The current frontend is wired to these services:

- `POST http://10.208.193.106:8000/api/session/start`
- `GET http://10.208.193.106:8000/api/calibration/run`
- `WS ws://10.208.193.106/ws/brain-stream`

If the stream is unavailable after calibration, the UI falls back to generated sample brain data so the monitoring screen remains usable during frontend development.

## Project Structure

```text
src/
  components/
    sentio/                  Session screens
    ui/                      Shared UI primitives
  context/
    BrainContext.tsx         Calibration and brain-stream state
  pages/
    Index.tsx                Main flow controller
    NotFound.tsx             Fallback route
  test/
    setup.ts                 Vitest setup
```

## Current Limitations

- Backend URLs are hardcoded instead of using environment variables.
- The pattern preview is frontend-generated and not yet fully driven by backend pattern parameters.
- The Save Pattern and Export Design buttons are present in the UI but do not yet perform file export.

## Next Improvements

1. Move service URLs into Vite environment variables.
2. Connect the pattern output directly to emotion and pattern seed data from the stream.
3. Implement image export for the generated canvas.
4. Add focused tests around session startup, calibration, and stream parsing.
