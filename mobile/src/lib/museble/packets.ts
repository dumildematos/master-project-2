/**
 * museble/packets.ts
 * ------------------
 * Decode raw Muse 2 EEG BLE notification packets received as DataView
 * (Capacitor BLE format).
 *
 * Each notification is 20 bytes:
 *   bytes  0–1   uint16 big-endian  = packet sequence number
 *   bytes  2–19  12 × 12-bit values packed MSB-first
 *
 * Conversion to microvolts: (raw_12bit - 2048) × 0.48828125
 */
import { EEG_MICROVOLT_SCALE, EEG_RAW_MIDPOINT, EEG_SAMPLES_PER_PACKET } from "./constants";

/**
 * Extract the packet sequence number from the first two bytes (big-endian).
 */
export function readPacketIndex(data: Uint8Array): number {
  return (data[0] << 8) | data[1];
}

/**
 * Unpack the 12 × 12-bit EEG samples from bytes 2–19 of a notification.
 * Returns an array of 12 values in microvolts.
 */
export function unpackEEGSamples(data: Uint8Array): number[] {
  const samples: number[] = new Array(EEG_SAMPLES_PER_PACKET);
  for (let i = 0; i < EEG_SAMPLES_PER_PACKET; i++) {
    const startBit  = 16 + i * 12;
    const byteIdx   = startBit >> 3;
    const bitInByte = startBit & 7;
    const hi        = data[byteIdx];
    const lo        = data[byteIdx + 1];
    const combined  = (hi << 8) | lo;
    const shift     = 4 - bitInByte;
    const raw       = (combined >> shift) & 0xFFF;
    samples[i]      = (raw - EEG_RAW_MIDPOINT) * EEG_MICROVOLT_SCALE;
  }
  return samples;
}

/**
 * Full packet decode: DataView → sequence index + 12 µV samples.
 * Accepts the DataView that Capacitor BLE delivers in notifications.
 */
export function decodeEEGPacket(value: DataView): { index: number; samples: number[] } | null {
  try {
    const data = new Uint8Array(value.buffer, value.byteOffset, value.byteLength);
    if (data.length < 20) return null;
    const index   = readPacketIndex(data);
    const samples = unpackEEGSamples(data);
    return { index, samples };
  } catch {
    return null;
  }
}
