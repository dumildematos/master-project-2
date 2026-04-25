/**
 * useMuseBLE  (mobile)
 * --------------------
 * React hook that manages the full Muse 2 BLE lifecycle:
 *   scan → connect → subscribe EEG chars → decode packets →
 *   buffer 256 samples per channel → compute band powers →
 *   POST /api/eeg/mobile-bands every ~250 ms
 *
 * Requires react-native-ble-plx + a custom Expo dev build.
 * Gracefully returns a "not supported" state on web.
 */
import { useCallback, useEffect, useRef, useState } from "react";
import { Platform, PermissionsAndroid } from "react-native";
import { resolveApiBaseUrl } from "../lib/runtimeConfig";
import {
  MUSE_SERVICE_UUID,
  MUSE_CONTROL_UUID,
  EEG_CHAR_UUIDS,
  CMD_START_EEG_B64,
  CMD_STOP_EEG_B64,
  MUSE_DEVICE_NAME_PREFIX,
  EEG_BAND_WINDOW_SIZE,
} from "../lib/museble/constants";
import { decodeEEGPacket } from "../lib/museble/packets";
import { averageBandPowers, estimateSignalQuality, BandPowers } from "../lib/museble/bandPowers";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------
export type BLEState =
  | "unavailable"    // web / BLE not supported
  | "idle"           // ready to scan
  | "requesting"     // requesting OS permissions
  | "scanning"       // scanning for devices
  | "connecting"     // connecting to a device
  | "connected"      // connected and streaming
  | "disconnected"   // was connected, now dropped
  | "error";

export interface MuseDevice {
  id:   string;      // BLE device identifier
  name: string;
  rssi: number;
}

// ---------------------------------------------------------------------------
// BLE manager — lazy-loaded to avoid crashing on web
// ---------------------------------------------------------------------------
let BleManager: any = null;

function getBleManager() {
  if (Platform.OS === "web") return null;
  if (!BleManager) {
    try {
      // Dynamic require so the module is not evaluated on web
      BleManager = require("react-native-ble-plx").BleManager;
    } catch {
      return null;
    }
  }
  return BleManager;
}

// ---------------------------------------------------------------------------
// Android permission helper
// ---------------------------------------------------------------------------
async function requestBLEPermissions(): Promise<boolean> {
  if (Platform.OS !== "android") return true;  // iOS: handled by Info.plist
  if ((Platform.Version as number) >= 31) {
    const granted = await PermissionsAndroid.requestMultiple([
      PermissionsAndroid.PERMISSIONS.BLUETOOTH_SCAN,
      PermissionsAndroid.PERMISSIONS.BLUETOOTH_CONNECT,
    ]);
    return (
      granted["android.permission.BLUETOOTH_SCAN"]    === PermissionsAndroid.RESULTS.GRANTED &&
      granted["android.permission.BLUETOOTH_CONNECT"] === PermissionsAndroid.RESULTS.GRANTED
    );
  }
  // API < 31 — needs fine location for BLE scan
  const result = await PermissionsAndroid.request(
    PermissionsAndroid.PERMISSIONS.ACCESS_FINE_LOCATION,
  );
  return result === PermissionsAndroid.RESULTS.GRANTED;
}

// ---------------------------------------------------------------------------
// Hook
// ---------------------------------------------------------------------------
const SCAN_TIMEOUT_MS    = 15_000;
const POST_INTERVAL_MS   = 250;   // send band data to backend every 250 ms

export function useMuseBLE() {
  const [bleState,         setBleState        ] = useState<BLEState>(
    Platform.OS === "web" ? "unavailable" : "idle",
  );
  const [devices,          setDevices         ] = useState<MuseDevice[]>([]);
  const [connectedDevice,  setConnectedDevice ] = useState<MuseDevice | null>(null);
  const [bandPowers,       setBandPowers      ] = useState<BandPowers | null>(null);
  const [signalQuality,    setSignalQuality   ] = useState(0);
  const [error,            setError           ] = useState<string | null>(null);

  // Internal refs
  const managerRef    = useRef<any>(null);
  const deviceRef     = useRef<any>(null);
  const buffers       = useRef<number[][]>([[], [], [], []]);   // per channel
  const postTimerRef  = useRef<ReturnType<typeof setInterval> | null>(null);
  const scanTimerRef  = useRef<ReturnType<typeof setTimeout>  | null>(null);
  const subscriptions = useRef<any[]>([]);

  // ── initialise BleManager once ────────────────────────────────────────────
  useEffect(() => {
    if (Platform.OS === "web") return;
    const Cls = getBleManager();
    if (!Cls) { setBleState("unavailable"); return; }
    managerRef.current = new Cls();
    return () => {
      managerRef.current?.destroy();
    };
  }, []);

  // ── cleanup helper ────────────────────────────────────────────────────────
  const cleanup = useCallback(() => {
    if (scanTimerRef.current) { clearTimeout(scanTimerRef.current); scanTimerRef.current = null; }
    if (postTimerRef.current) { clearInterval(postTimerRef.current); postTimerRef.current = null; }
    subscriptions.current.forEach(s => { try { s?.remove(); } catch {} });
    subscriptions.current = [];
  }, []);

  // ── scan ──────────────────────────────────────────────────────────────────
  const scan = useCallback(async () => {
    if (!managerRef.current) { setError("BLE not available"); return; }

    setBleState("requesting");
    setDevices([]);
    setError(null);

    const ok = await requestBLEPermissions();
    if (!ok) {
      setError("Bluetooth permission denied");
      setBleState("error");
      return;
    }

    setBleState("scanning");
    const found = new Map<string, MuseDevice>();

    managerRef.current.startDeviceScan(
      null,   // all service UUIDs — filter by name below for reliability
      { allowDuplicates: false },
      (err: any, device: any) => {
        if (err) {
          setError(err.message ?? "Scan error");
          setBleState("error");
          return;
        }
        if (!device) return;
        const name: string = device.localName ?? device.name ?? "";
        if (!name.startsWith(MUSE_DEVICE_NAME_PREFIX)) return;

        if (!found.has(device.id)) {
          const d: MuseDevice = { id: device.id, name, rssi: device.rssi ?? -99 };
          found.set(device.id, d);
          setDevices(Array.from(found.values()));
        }
      },
    );

    // Auto-stop scan after SCAN_TIMEOUT_MS
    scanTimerRef.current = setTimeout(() => {
      managerRef.current?.stopDeviceScan();
      if (found.size === 0) {
        setBleState("idle");
      }
    }, SCAN_TIMEOUT_MS);
  }, []);

  const stopScan = useCallback(() => {
    managerRef.current?.stopDeviceScan();
    if (scanTimerRef.current) { clearTimeout(scanTimerRef.current); scanTimerRef.current = null; }
    setBleState("idle");
  }, []);

  // ── connect ───────────────────────────────────────────────────────────────
  const connect = useCallback(async (museDevice: MuseDevice) => {
    if (!managerRef.current) return;

    cleanup();
    managerRef.current.stopDeviceScan();
    setBleState("connecting");
    setError(null);

    try {
      const rawDevice = await managerRef.current.connectToDevice(museDevice.id, {
        requestMTU: 512,
      });
      // discoverAllServicesAndCharacteristics returns the same device with
      // services populated; use that reference for all subsequent operations.
      const device = await rawDevice.discoverAllServicesAndCharacteristics();
      deviceRef.current = device;

      // Subscribe to all 4 EEG characteristics
      buffers.current = [[], [], [], []];

      EEG_CHAR_UUIDS.forEach((uuid, channelIdx) => {
        const sub = device.monitorCharacteristicForService(
          MUSE_SERVICE_UUID,
          uuid,
          (err: any, char: any) => {
            if (err || !char?.value) return;
            const packet = decodeEEGPacket(char.value);
            if (!packet) return;
            const buf = buffers.current[channelIdx];
            buf.push(...packet.samples);
            // Trim buffer to avoid unbounded growth
            if (buf.length > EEG_BAND_WINDOW_SIZE * 2) {
              buffers.current[channelIdx] = buf.slice(-EEG_BAND_WINDOW_SIZE * 2);
            }
          },
        );
        subscriptions.current.push(sub);
      });

      // Start EEG streaming
      await device.writeCharacteristicWithResponseForService(
        MUSE_SERVICE_UUID,
        MUSE_CONTROL_UUID,
        CMD_START_EEG_B64,
      );

      // Handle unexpected disconnects
      const discSub = device.onDisconnected(() => {
        cleanup();
        setBleState("disconnected");
        setConnectedDevice(null);
        setBandPowers(null);
      });
      subscriptions.current.push(discSub);

      setConnectedDevice(museDevice);
      setBleState("connected");

      // ── periodic band-power computation + backend POST ─────────────────
      postTimerRef.current = setInterval(async () => {
        // Check all channels have at least EEG_BAND_WINDOW_SIZE samples
        const readyChannels = buffers.current.filter(b => b.length >= EEG_BAND_WINDOW_SIZE);
        if (readyChannels.length < 2) return;   // need at least 2 good channels

        const windows = readyChannels.map(b => b.slice(-EEG_BAND_WINDOW_SIZE));
        const bands   = averageBandPowers(windows);
        const sq      = estimateSignalQuality(bands);

        setBandPowers(bands);
        setSignalQuality(sq);

        try {
          const base = await resolveApiBaseUrl();
          await fetch(`${base}/api/eeg/mobile-bands`, {
            method:  "POST",
            headers: { "Content-Type": "application/json" },
            body:    JSON.stringify({ ...bands, signal_quality: sq }),
          });
        } catch {
          // Ignore network errors — data continues to buffer locally
        }
      }, POST_INTERVAL_MS);

    } catch (e: any) {
      setError(e?.message ?? "Connection failed");
      setBleState("error");
    }
  }, [cleanup]);

  // ── disconnect ────────────────────────────────────────────────────────────
  const disconnect = useCallback(async () => {
    cleanup();
    try {
      if (deviceRef.current) {
        await deviceRef.current.writeCharacteristicWithResponseForService(
          MUSE_SERVICE_UUID,
          MUSE_CONTROL_UUID,
          CMD_STOP_EEG_B64,
        ).catch(() => {});   // best-effort stop command
        await deviceRef.current.cancelConnection().catch(() => {});
      }
    } catch {}
    deviceRef.current = null;
    setConnectedDevice(null);
    setBleState("idle");
    setBandPowers(null);
    setSignalQuality(0);
  }, [cleanup]);

  return {
    bleState,
    devices,
    connectedDevice,
    bandPowers,
    signalQuality,
    error,
    scan,
    stopScan,
    connect,
    disconnect,
  };
}
