/// EEG processing: packet decoding, Cooley-Tukey FFT, band-power estimation.
/// Ported from lib/museble/{packets,bandPowers}.ts.
import 'dart:math';
import '../models/band_powers.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const int    kSamplesPerPacket = 12;
const int    kRawMidpoint      = 2048;
const double kMicroVoltScale   = 0.48828125;
const int    kBandWindowSize   = 256;   // samples per FFT window (1 s @ 256 Hz)
const int    kSamplingRate     = 256;   // Hz

// ── Packet decode ─────────────────────────────────────────────────────────────

/// Decode a raw Muse 2 BLE EEG notification (20 bytes) into 12 µV samples.
/// Returns null if [bytes] is too short or malformed.
({int index, List<double> samples})? decodeEEGPacket(List<int> bytes) {
  if (bytes.length < 20) return null;
  try {
    final index = (bytes[0] << 8) | bytes[1];
    final samples = List<double>.filled(kSamplesPerPacket, 0);
    for (int i = 0; i < kSamplesPerPacket; i++) {
      final startBit  = 16 + i * 12;
      final byteIdx   = startBit >> 3;
      final bitInByte = startBit & 7;
      final combined  = (bytes[byteIdx] << 8) | bytes[byteIdx + 1];
      final shift     = 4 - bitInByte;
      final raw       = (combined >> shift) & 0xFFF;
      samples[i]      = (raw - kRawMidpoint) * kMicroVoltScale;
    }
    return (index: index, samples: samples);
  } catch (_) {
    return null;
  }
}

// ── Complex number ────────────────────────────────────────────────────────────
class _Complex {
  final double re, im;
  const _Complex(this.re, this.im);
  _Complex operator +(_Complex o) => _Complex(re + o.re, im + o.im);
  _Complex operator -(_Complex o) => _Complex(re - o.re, im - o.im);
  _Complex operator *(_Complex o) =>
      _Complex(re * o.re - im * o.im, re * o.im + im * o.re);
  double get magnitude => sqrt(re * re + im * im);
}

// ── Cooley-Tukey radix-2 FFT (in-place, power-of-2 only) ─────────────────────
List<_Complex> _fft(List<_Complex> x) {
  final n = x.length;
  if (n <= 1) return x;
  final even = _fft([for (int i = 0; i < n; i += 2) x[i]]);
  final odd  = _fft([for (int i = 1; i < n; i += 2) x[i]]);
  final out  = List<_Complex>.filled(n, const _Complex(0, 0));
  for (int k = 0; k < n ~/ 2; k++) {
    final angle = -2.0 * pi * k / n;
    final t = _Complex(cos(angle), sin(angle)) * odd[k];
    out[k]         = even[k] + t;
    out[k + n ~/ 2] = even[k] - t;
  }
  return out;
}

// ── Band-power computation ────────────────────────────────────────────────────

Map<String, List<int>> _bandBins(int n, int fs) => {
  'delta': [1,  4],
  'theta': [4,  8],
  'alpha': [8,  13],
  'beta':  [13, 30],
  'gamma': [30, 45],
}.map((k, v) => MapEntry(k, [
  ((v[0] * n) ~/ fs).clamp(1, n ~/ 2 - 1),
  ((v[1] * n) ~/ fs).clamp(1, n ~/ 2 - 1),
]));

BandPowers computeBandPowers(List<double> samples) {
  final n = samples.length;

  // Apply Hann window
  final windowed = List<_Complex>.generate(n, (i) {
    final w = 0.5 * (1 - cos(2 * pi * i / (n - 1)));
    return _Complex(samples[i] * w, 0);
  });

  final spectrum = _fft(windowed);
  final power    = [for (final c in spectrum) c.magnitude * c.magnitude];

  double bandAvg(List<int> range) {
    final values = power.sublist(range[0], range[1] + 1);
    return values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;
  }

  final bins = _bandBins(n, kSamplingRate);
  final raw  = {
    'delta': bandAvg(bins['delta']!),
    'theta': bandAvg(bins['theta']!),
    'alpha': bandAvg(bins['alpha']!),
    'beta':  bandAvg(bins['beta']!),
    'gamma': bandAvg(bins['gamma']!),
  };
  final total = raw.values.fold(0.0, (s, v) => s + v);
  final norm  = total > 0
      ? raw.map((k, v) => MapEntry(k, v / total))
      : raw.map((k, _) => MapEntry(k, 0.2));  // fallback equal split

  return BandPowers(
    alpha: norm['alpha']!,
    beta:  norm['beta']!,
    theta: norm['theta']!,
    gamma: norm['gamma']!,
    delta: norm['delta']!,
  );
}

/// Average band powers across multiple EEG channels.
BandPowers averageBandPowers(List<List<double>> channels) {
  if (channels.isEmpty) {
    return const BandPowers(alpha: 0, beta: 0, theta: 0, gamma: 0, delta: 0);
  }
  final list = channels.map(computeBandPowers).toList();
  double avg(double Function(BandPowers) f) =>
      list.map(f).reduce((a, b) => a + b) / list.length;
  return BandPowers(
    alpha: avg((b) => b.alpha),
    beta:  avg((b) => b.beta),
    theta: avg((b) => b.theta),
    gamma: avg((b) => b.gamma),
    delta: avg((b) => b.delta),
  );
}

/// Signal quality estimate (0–100), mirrors the backend formula.
double estimateSignalQuality(BandPowers b) =>
    ((b.alpha + b.theta + b.beta) * 133).clamp(0, 100);
