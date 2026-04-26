/**
 * museble/constants.ts
 * --------------------
 * Muse 2 GATT service + characteristic UUIDs, BLE command bytes,
 * and sampling constants.
 *
 * UUIDs verified against muse-lsl open-source reference implementation.
 */

// ── Service ──────────────────────────────────────────────────────────────────
export const MUSE_SERVICE_UUID = "0000fe8d-0000-1000-8000-00805f9b34fb";

// ── Control characteristic (Write-Without-Response) ──────────────────────────
export const MUSE_CONTROL_UUID = "273e0001-4c4d-454d-96be-f03bac821358";

// ── EEG channel characteristics (notify) ─────────────────────────────────────
export const MUSE_EEG_TP9_UUID  = "273e0003-4c4d-454d-96be-f03bac821358";
export const MUSE_EEG_AF7_UUID  = "273e0004-4c4d-454d-96be-f03bac821358";
export const MUSE_EEG_AF8_UUID  = "273e0005-4c4d-454d-96be-f03bac821358";
export const MUSE_EEG_TP10_UUID = "273e0006-4c4d-454d-96be-f03bac821358";

export const EEG_CHAR_UUIDS = [
  MUSE_EEG_TP9_UUID,
  MUSE_EEG_AF7_UUID,
  MUSE_EEG_AF8_UUID,
  MUSE_EEG_TP10_UUID,
] as const;

export const EEG_CHANNEL_NAMES = ["TP9", "AF7", "AF8", "TP10"] as const;

// ── Control commands (DataView, for Capacitor BLE) ────────────────────────────
// Format: [0x02, <cmd_byte>, 0x0a]  — same as muse-lsl _write_cmd_str()
/** Start EEG streaming: cmd 'd' (0x64) */
export function cmdStartEEG(): DataView {
  return new DataView(new Uint8Array([0x02, 0x64, 0x0a]).buffer);
}
/** Stop EEG streaming: cmd 'h' (0x68) */
export function cmdStopEEG(): DataView {
  return new DataView(new Uint8Array([0x02, 0x68, 0x0a]).buffer);
}

// ── Sampling ─────────────────────────────────────────────────────────────────
export const MUSE_SAMPLING_RATE      = 256;  // Hz
export const EEG_SAMPLES_PER_PACKET  = 12;   // samples per BLE notification
export const EEG_BAND_WINDOW_SIZE    = 256;  // samples per FFT window (1 s)
export const EEG_MICROVOLT_SCALE     = 0.48828125;
export const EEG_RAW_MIDPOINT        = 2048;

// ── Device name ──────────────────────────────────────────────────────────────
export const MUSE_DEVICE_NAME_PREFIX = "Muse";
