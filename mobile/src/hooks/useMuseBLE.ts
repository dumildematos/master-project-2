/**
 * useMuseBLE  (Ionic / Capacitor)
 * --------------------------------
 * React hook that manages the full Muse 2 BLE lifecycle using
 * @capacitor-community/bluetooth-le:
 *   initialize → scan → connect → subscribe EEG chars → decode packets →
 *   buffer 256 samples per channel → compute band powers →
 *   POST /api/eeg/mobile-bands every ~250 ms
 */
import { useCallback, useRef, useState } from "react";
import { BleClient, ScanResult } from "@capacitor-community/bluetooth-le";
import { resolveApiBaseUrl } from "../lib/runtimeConfig";
import {
  MUSE_SERVICE_UUID,
  MUSE_CONTROL_UUID,
  EEG_CHAR_UUIDS,
  MUSE_DEVICE_NAME_PREFIX,
  EEG_BAND_WINDOW_SIZE,
  cmdStartEEG,
  cmdStopEEG,
} from "../lib/museble/constants";
import { decodeEEGPacket } from "../lib/museble/packets";
import { averageBandPowers, estimateSignalQuality, BandPowers } from "../lib/museble/bandPowers";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------
export type BLEState =
  | "idle"          // ready to scan
  | "scanning"      // scanning for devices
  | "connecting"    // connecting to a device
  | "connected"     // connected and streaming
  | "disconnected"  // was connected, now dropped
  | "error";

export interface MuseDevice {
  id:   string;
  name: string;
  rssi: number;
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------
const SCAN_TIMEOUT_MS  = 15_000;
const POST_INTERVAL_MS = 250;

// ---------------------------------------------------------------------------
// Hook
// ---------------------------------------------------------------------------
export function useMuseBLE() {
  const [bleState,        setBleState       ] = useState<BLEState>("idle");
  const [devices,         setDevices        ] = useState<MuseDevice[]>([]);
  const [connectedDevice, setConnectedDevice] = useState<MuseDevice | null>(null);
  const [bandPowers,      setBandPowers     ] = useState<BandPowers | null>(null);
  const [signalQuality,   setSignalQuality  ] = useState(0);
  const [error,           setError          ] = useState<string | null>(null);

  const connectedIdRef = useRef<string | null>(null);
  const buffers        = useRef<number[][]>([[], [], [], []]);
  const postTimerRef   = useRef<ReturnType<typeof setInterval> | null>(null);
  const scanTimerRef   = useRef<ReturnType<typeof setTimeout>  | null>(null);

  // ── cleanup ───────────────────────────────────────────────────────────────
  const cleanup = useCallback(() => {
    if (scanTimerRef.current) { clearTimeout(scanTimerRef.current);  scanTimerRef.current = null; }
    if (postTimerRef.current) { clearInterval(postTimerRef.current); postTimerRef.current = null; }
  }, []);

  // ── scan ──────────────────────────────────────────────────────────────────
  const scan = useCallback(async () => {
    cleanup();
    setDevices([]);
    setError(null);
    setBleState("scanning");

    const found = new Map<string, MuseDevice>();

    try {
      // initialize() requests BLE permissions on Android/iOS automatically
      await BleClient.initialize({ androidNeverForLocation: true });

      await BleClient.requestLEScan(
        { allowDuplicates: false },
        (result: ScanResult) => {
          const name = result.localName ?? result.device.name ?? "";
          if (!name.startsWith(MUSE_DEVICE_NAME_PREFIX)) return;
          const id = result.device.deviceId;
          if (!found.has(id)) {
            const d: MuseDevice = { id, name, rssi: result.rssi ?? -99 };
            found.set(id, d);
            setDevices(Array.from(found.values()));
          }
        },
      );

      scanTimerRef.current = setTimeout(async () => {
        try { await BleClient.stopLEScan(); } catch { /* ignore */ }
        if (found.size === 0) setBleState("idle");
      }, SCAN_TIMEOUT_MS);

    } catch (e: any) {
      setError(e?.message ?? "Scan failed");
      setBleState("error");
    }
  }, [cleanup]);

  // ── stopScan ──────────────────────────────────────────────────────────────
  const stopScan = useCallback(async () => {
    if (scanTimerRef.current) { clearTimeout(scanTimerRef.current); scanTimerRef.current = null; }
    try { await BleClient.stopLEScan(); } catch { /* ignore */ }
    setBleState("idle");
  }, []);

  // ── connect ───────────────────────────────────────────────────────────────
  const connect = useCallback(async (museDevice: MuseDevice) => {
    cleanup();
    try { await BleClient.stopLEScan(); } catch { /* ignore */ }
    setBleState("connecting");
    setError(null);

    try {
      // Connect with disconnect callback
      await BleClient.connect(museDevice.id, (_deviceId: string) => {
        cleanup();
        setBleState("disconnected");
        setConnectedDevice(null);
        setBandPowers(null);
        connectedIdRef.current = null;
      });

      connectedIdRef.current = museDevice.id;
      buffers.current = [[], [], [], []];

      // Subscribe to all 4 EEG characteristics
      for (let channelIdx = 0; channelIdx < EEG_CHAR_UUIDS.length; channelIdx++) {
        const uuid = EEG_CHAR_UUIDS[channelIdx];
        const idx  = channelIdx;
        await BleClient.startNotifications(
          museDevice.id,
          MUSE_SERVICE_UUID,
          uuid,
          (value: DataView) => {
            const packet = decodeEEGPacket(value);
            if (!packet) return;
            const buf = buffers.current[idx];
            buf.push(...packet.samples);
            if (buf.length > EEG_BAND_WINDOW_SIZE * 2) {
              buffers.current[idx] = buf.slice(-EEG_BAND_WINDOW_SIZE * 2);
            }
          },
        );
      }

      // Start EEG streaming (Write-Without-Response, non-fatal if it fails)
      try {
        await BleClient.writeWithoutResponse(
          museDevice.id, MUSE_SERVICE_UUID, MUSE_CONTROL_UUID, cmdStartEEG(),
        );
      } catch { /* non-fatal — EEG may arrive without explicit start */ }

      setConnectedDevice(museDevice);
      setBleState("connected");

      // ── periodic band-power computation + backend POST ─────────────────
      postTimerRef.current = setInterval(async () => {
        const readyChannels = buffers.current.filter(b => b.length >= EEG_BAND_WINDOW_SIZE);
        if (readyChannels.length < 2) return;

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
        } catch { /* ignore network errors */ }
      }, POST_INTERVAL_MS);

    } catch (e: any) {
      setError(e?.message ?? "Connection failed");
      setBleState("error");
    }
  }, [cleanup]);

  // ── disconnect ────────────────────────────────────────────────────────────
  const disconnect = useCallback(async () => {
    cleanup();
    const id = connectedIdRef.current;
    if (id) {
      // Best-effort stop EEG
      try {
        await BleClient.writeWithoutResponse(
          id, MUSE_SERVICE_UUID, MUSE_CONTROL_UUID, cmdStopEEG(),
        );
      } catch { /* ignore */ }
      // Stop all EEG notifications
      for (const uuid of EEG_CHAR_UUIDS) {
        try { await BleClient.stopNotifications(id, MUSE_SERVICE_UUID, uuid); } catch { /* ignore */ }
      }
      try { await BleClient.disconnect(id); } catch { /* ignore */ }
      connectedIdRef.current = null;
    }
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
