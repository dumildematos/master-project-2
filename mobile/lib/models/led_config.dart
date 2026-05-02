import 'package:flutter/painting.dart' show Color;

// Payload sent to the SENTIO Hat for LED preview.
// Matches the ESP32 JSON contract:
//   { mode, brightness (0-100), speed (0-100), colors, pattern (8x8 binary),
//     pixel_colors? (64 per-pixel hex strings, Customize tab only) }
class LedConfig {
  final String         mode;
  final int            brightness;   // 0-100
  final int            speed;        // 0-100
  final List<String>   colors;       // ["#RRGGBB", ...]
  final List<List<int>> pattern;     // 8×8 binary (1=on, 0=off)
  final List<String?>? pixelColors;  // 64 per-pixel hex or null (Customize only)

  const LedConfig({
    required this.mode,
    required this.brightness,
    required this.speed,
    required this.colors,
    required this.pattern,
    this.pixelColors,
  });

  // Palette used by the Effects tab (one entry per mode, lowercase key).
  static const _modeColors = <String, List<String>>{
    'breathing': ['#00D9FF', '#CCEEFF'],
    'pulse':     ['#FF2D95', '#8B20FF'],
    'wave':      ['#00D9FF'],
    'spectrum':  ['#FF0000', '#00FF00', '#0000FF'],
    'fireworks': ['#FF4400', '#FFAA00', '#00DDFF'],
    'spiral':    ['#00FFAA', '#00AAFF'],
  };

  // Default 8×8 pattern used by all Effects modes.
  static const _defaultPat = [
    [1, 1, 1, 1, 1, 1, 1, 1],
    [1, 2, 2, 2, 2, 2, 2, 1],
    [1, 2, 1, 2, 1, 2, 1, 1],
    [1, 2, 1, 0, 1, 2, 1, 1],
    [1, 2, 1, 2, 1, 2, 1, 1],
    [1, 2, 2, 2, 2, 2, 2, 1],
    [1, 1, 1, 1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1, 1, 1],
  ];

  factory LedConfig.fromEffects({
    required String mode,
    required double brightness,
    required double speed,
  }) {
    final key = mode.toLowerCase();
    return LedConfig(
      mode:       key,
      brightness: (brightness * 100).round().clamp(0, 100),
      speed:      (speed      * 100).round().clamp(0, 100),
      colors:     _modeColors[key] ?? ['#00D9FF'],
      pattern:    List.generate(8, (r) =>
                    List.generate(8, (c) => _defaultPat[r][c] > 0 ? 1 : 0)),
    );
  }

  factory LedConfig.fromCustom({
    required List<Color?> matrix,
    required double       brightness,
    required double       speed,
    required String       mode,
  }) {
    assert(matrix.length == 64, 'matrix must have exactly 64 entries');

    final pattern = List.generate(8, (r) =>
        List.generate(8, (c) => matrix[r * 8 + c] != null ? 1 : 0));

    final pixelColors = matrix
        .map((c) => c == null ? null : _hexOf(c))
        .toList();

    final unique = <String>{};
    for (final c in matrix) {
      if (c != null) unique.add(_hexOf(c));
    }

    return LedConfig(
      mode:        mode.toLowerCase(),
      brightness:  (brightness * 100).round().clamp(0, 100),
      speed:       (speed      * 100).round().clamp(0, 100),
      colors:      unique.isEmpty ? ['#00D9FF'] : unique.toList(),
      pattern:     pattern,
      pixelColors: pixelColors,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'mode':       mode,
      'brightness': brightness,
      'speed':      speed,
      'colors':     colors,
      'pattern':    pattern,
      if (pixelColors != null) 'pixel_colors': pixelColors,
    };
  }

  static String _hexOf(Color c) =>
      '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
}
