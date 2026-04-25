/**
 * museble/packets.ts
 * ------------------
 * Decode raw Muse 2 EEG BLE notification packets.
 *
 * Each notification is 20 bytes:
 *   bytes  0–1   uint16 big-endian  = packet sequence number
 *   bytes  2–19  12 × 12-bit values packed MSB-first
 *
 * The 12-bit values alternate between bit-offsets 0 and 4 within each
 * two-byte window, so a simple two-byte read always captures the full
 * 12-bit field without needing a three-byte window.
 *
 * Conversion to microvolts: (raw_12bit - 2048) × 0.48828125
 */
import { EEG_MICROVOLT_SCALE, EEG_RAW_MIDPOINT, EEG_SAMPLES_PER_PACKET } from "./constants";

/** Decode a base64 BLE notification into a Uint8Array. */
export function base64ToBytes(b64: string): Uint8Array {
  const binary = atob(b64);
  const bytes  = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

/**
 * Extract the packet sequence number from the first two bytes (big-endian).
 */
export function readPacketIndex(data: Uint8Array): number {
  return (data[0] << 8) | data[1];
}

/**
 * Unpack the 12 × 12-bit EEG samples from bytes 2–19 of a notification.
 * Returns an array of 12 values in microvolts.
 *
 * Bit layout (MSB-first, starting at bit 16):
 *   sample 0 → bits 16–27  (byte 2, bit-offset 0)
 *   sample 1 → bits 28–39  (byte 3, bit-offset 4)
 *   sample 2 → bits 40–51  (byte 5, bit-offset 0)
 *   …alternates between offset 0 and 4 every sample
 */
export function unpackEEGSamples(data: Uint8Array): number[] {
  const samples: number[] = new Array(EEG_SAMPLES_PER_PACKET);
  for (let i = 0; i < EEG_SAMPLES_PER_PACKET; i++) {
    const startBit  = 16 + i * 12;
    const byteIdx   = startBit >> 3;           // Math.floor(startBit / 8)
    const bitInByte = startBit & 7;            // startBit % 8  → always 0 or 4
    const hi        = data[byteIdx];
    const lo        = data[byteIdx + 1];
    const combined  = (hi << 8) | lo;
    const shift     = 4 - bitInByte;           // always 4 or 0
    const raw       = (combined >> shift) & 0xFFF;
    samples[i]      = (raw - EEG_RAW_MIDPOINT) * EEG_MICROVOLT_SCALE;
  }
  return samples;
}

/**
 * Full packet decode: base64 → sequence index + 12 µV samples.
 */
export function decodeEEGPacket(b64: string): { index: number; samples: number[] } | null {
  try {
    const data    = base64ToBytes(b64);
    if (data.length < 20) return null;
    const index   = readPacketIndex(data);
    const samples = unpackEEGSamples(data);
    return { index, samples };
  } catch {
    return null;
  }
}
