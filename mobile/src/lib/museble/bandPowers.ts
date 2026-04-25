/**
 * museble/bandPowers.ts
 * ----------------------
 * FFT-based EEG band power computation.
 *
 * Given N=256 samples at 256 Hz the frequency resolution is exactly 1 Hz/bin.
 * Band definitions (Hz):
 *   delta  0.5 – 4
 *   theta  4   – 8
 *   alpha  8   – 13
 *   beta   13  – 30
 *   gamma  30  – 50
 *
 * Steps:
 *   1. Apply a Hann window to reduce spectral leakage.
 *   2. Compute in-place radix-2 FFT.
 *   3. Average power (|X[k]|²) within each band.
 *   4. Normalise so all five bands sum to 1.
 *   5. Average across all EEG channels supplied.
 */
import { MUSE_SAMPLING_RATE, EEG_BAND_WINDOW_SIZE } from "./constants";

export interface BandPowers {
  alpha: number;
  beta:  number;
  theta: number;
  gamma: number;
  delta: number;
}

// ── FFT (Cooley-Tukey, in-place, power-of-2 length) ──────────────────────────

function fftInPlace(re: Float64Array, im: Float64Array): void {
  const n = re.length;

  // Bit-reversal permutation
  let j = 0;
  for (let i = 1; i < n; i++) {
    let bit = n >> 1;
    while (j & bit) { j ^= bit; bit >>= 1; }
    j ^= bit;
    if (i < j) {
      let t = re[i]; re[i] = re[j]; re[j] = t;
          t = im[i]; im[i] = im[j]; im[j] = t;
    }
  }

  // Butterfly passes
  for (let len = 2; len <= n; len <<= 1) {
    const halfLen  = len >> 1;
    const ang      = -2 * Math.PI / len;
    const wBaseRe  = Math.cos(ang);
    const wBaseIm  = Math.sin(ang);
    for (let i = 0; i < n; i += len) {
      let wRe = 1, wIm = 0;
      for (let k = 0; k < halfLen; k++) {
        const uRe = re[i + k];
        const uIm = im[i + k];
        const vRe = re[i + k + halfLen] * wRe - im[i + k + halfLen] * wIm;
        const vIm = re[i + k + halfLen] * wIm + im[i + k + halfLen] * wRe;
        re[i + k]           = uRe + vRe;
        im[i + k]           = uIm + vIm;
        re[i + k + halfLen] = uRe - vRe;
        im[i + k + halfLen] = uIm - vIm;
        const nwRe = wRe * wBaseRe - wIm * wBaseIm;
        wIm        = wRe * wBaseIm + wIm * wBaseRe;
        wRe        = nwRe;
      }
    }
  }
}

// ── Band helpers ──────────────────────────────────────────────────────────────

/** Average power in bins [loHz, hiHz]. freqRes = fs / N (= 1 Hz when N=256, fs=256). */
function avgBandPower(power: Float64Array, loHz: number, hiHz: number, freqRes: number): number {
  const lo   = Math.max(1, Math.round(loHz / freqRes));
  const hi   = Math.min(power.length - 1, Math.round(hiHz / freqRes));
  if (lo > hi) return 0;
  let sum = 0;
  for (let i = lo; i <= hi; i++) sum += power[i];
  return sum / (hi - lo + 1);
}

/** Hann window coefficient for sample i of N. */
const hann = (i: number, n: number) => 0.5 - 0.5 * Math.cos((2 * Math.PI * i) / (n - 1));

// ── Public API ────────────────────────────────────────────────────────────────

/**
 * Compute normalised band powers from one channel of EEG samples.
 * @param samples  Array of exactly EEG_BAND_WINDOW_SIZE (256) µV values.
 * @param fs       Sampling rate in Hz (default 256).
 */
export function computeBandPowers(
  samples:  number[],
  fs:       number = MUSE_SAMPLING_RATE,
): BandPowers {
  const n       = EEG_BAND_WINDOW_SIZE;
  const freqRes = fs / n;

  // Apply Hann window
  const re = new Float64Array(n);
  const im = new Float64Array(n);
  for (let i = 0; i < n; i++) {
    re[i] = (samples[i] ?? 0) * hann(i, n);
  }

  fftInPlace(re, im);

  // One-sided power spectrum
  const power = new Float64Array(n >> 1);
  for (let i = 0; i < power.length; i++) {
    power[i] = re[i] * re[i] + im[i] * im[i];
  }

  const raw = {
    delta: avgBandPower(power, 0.5,  4,  freqRes),
    theta: avgBandPower(power, 4,    8,  freqRes),
    alpha: avgBandPower(power, 8,    13, freqRes),
    beta:  avgBandPower(power, 13,   30, freqRes),
    gamma: avgBandPower(power, 30,   50, freqRes),
  };

  const total = raw.delta + raw.theta + raw.alpha + raw.beta + raw.gamma;
  if (total <= 0) {
    return { delta: 0.2, theta: 0.2, alpha: 0.2, beta: 0.2, gamma: 0.2 };
  }

  return {
    delta: raw.delta / total,
    theta: raw.theta / total,
    alpha: raw.alpha / total,
    beta:  raw.beta  / total,
    gamma: raw.gamma / total,
  };
}

/**
 * Average band powers across multiple EEG channels.
 * Each channel must provide exactly EEG_BAND_WINDOW_SIZE samples.
 */
export function averageBandPowers(channels: number[][]): BandPowers {
  if (channels.length === 0) {
    return { delta: 0.2, theta: 0.2, alpha: 0.2, beta: 0.2, gamma: 0.2 };
  }

  const perChannel = channels.map(ch => computeBandPowers(ch));
  const n          = perChannel.length;

  return {
    alpha: perChannel.reduce((s, b) => s + b.alpha, 0) / n,
    beta:  perChannel.reduce((s, b) => s + b.beta,  0) / n,
    theta: perChannel.reduce((s, b) => s + b.theta, 0) / n,
    gamma: perChannel.reduce((s, b) => s + b.gamma, 0) / n,
    delta: perChannel.reduce((s, b) => s + b.delta, 0) / n,
  };
}

/**
 * Rough signal-quality estimate (0–100) mirroring the backend formula.
 * Good EEG has strong alpha + theta + beta relative to total.
 */
export function estimateSignalQuality(bands: BandPowers): number {
  const dominant = bands.alpha + bands.theta + bands.beta;
  return Math.min(100, Math.round(dominant * 133));
}
