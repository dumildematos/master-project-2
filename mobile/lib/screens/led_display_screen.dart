// =============================================================================
//  LedDisplayScreen — SENTIO LED hat control panel.
//
//  Effects tab : animated 8×8 LED preview + brightness / speed / mode controls.
//  Customize tab: tap-to-paint editable matrix + full HSV colour picker.
//
//  Packages: google_fonts, phosphor_flutter, provider
// =============================================================================
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/generated_led_pattern.dart';
import '../models/led_config.dart';
import '../services/sentio_api.dart' as api;

// ─── Brand tokens ──────────────────────────────────────────────────────────────
const _bg1     = Color(0xFF02080D);
const _bg2     = Color(0xFF07131B);
const _surface = Color(0xFF0C1826);
const _border  = Color(0xFF1A2840);
const _cyan    = Color(0xFF00D9FF);
const _purple  = Color(0xFF8A3FFC);
const _pink    = Color(0xFFC13BFF);
const _muted   = Color(0xFF9AA6B2);

// ─── Typography ────────────────────────────────────────────────────────────────
TextStyle _pp({
  double size = 14,
  FontWeight weight = FontWeight.normal,
  Color color = Colors.white,
}) =>
    GoogleFonts.poppins(fontSize: size, fontWeight: weight, color: color);

// ─── Mode list ─────────────────────────────────────────────────────────────────
const _modes = ['Breathing', 'Pulse', 'Wave', 'Spectrum', 'Fireworks', 'Spiral'];

// ─── Preset pattern  (1=cyan-white  2=purple  0=off) ──────────────────────────
const _pat = [
  [1, 1, 1, 1, 1, 1, 1, 1],
  [1, 2, 2, 2, 2, 2, 2, 1],
  [1, 2, 1, 2, 1, 2, 1, 1],
  [1, 2, 1, 0, 1, 2, 1, 1],
  [1, 2, 1, 2, 1, 2, 1, 1],
  [1, 2, 2, 2, 2, 2, 2, 1],
  [1, 1, 1, 1, 1, 1, 1, 1],
  [1, 1, 1, 1, 1, 1, 1, 1],
];

List<Color?> _defaultMatrix() => List.generate(64, (i) {
      final v = _pat[i ~/ 8][i % 8];
      return v == 1 ? _cyan : v == 2 ? _purple : null;
    });

// ─── Animation speed ───────────────────────────────────────────────────────────
Duration _dur(double speed) =>
    Duration(milliseconds: ((1 - speed) * 3500 + 500).round());

// ─── AI grid + mode animation ─────────────────────────────────────────────────
// Uses the AI grid for on/off (same 8×8 mask) and the selected mode for colour.
Color? _dotWithGrid(
  String mode,
  List<List<int>> grid,
  Color primary,
  Color secondary,
  int r,
  int c,
  double t,
) {
  if (r >= grid.length || c >= grid[r].length || grid[r][c] == 0) return null;

  final dx = c - 3.5, dy = r - 3.5;
  final d  = math.sqrt(dx * dx + dy * dy);

  switch (mode) {
    case 'Breathing':
      final pulse = math.sin(t * math.pi * 2) * .5 + .5;
      return Color.lerp(primary, secondary, pulse);

    case 'Pulse':
      for (int i = 0; i < 3; i++) {
        final rp = ((t + i / 3.0) % 1.0) * 4.5;
        if ((d - rp).abs() < .65) return Color.lerp(primary, secondary, i / 2.0);
      }
      return primary.withOpacity(.18);

    case 'Wave':
      final wave = math.sin(c / 7.0 * math.pi * 2 + t * math.pi * 2) * 2.5 + 3.5;
      final dd   = (r - wave).abs();
      if (dd >= .9) return primary.withOpacity(.18);
      return Color.lerp(primary, secondary, 1 - dd / .9)!
          .withOpacity((1 - dd / .9).clamp(0.0, 1.0));

    case 'Spectrum':
      return HSVColor.fromAHSV(
          1, ((r * 8 + c) / 64 * 300 + t * 360) % 360, 1, .95).toColor();

    case 'Fireworks':
      final a = ((math.sin(t * math.pi * 2 +
              ((r * 8 + c) % 16) / 16.0 * math.pi * 2) +
          1) / 2).clamp(0.0, 1.0);
      return a < .1 ? primary.withOpacity(.1) : Color.lerp(primary, secondary, a);

    case 'Spiral':
      final angle   = (math.atan2(dy, dx) + math.pi * 2) % (math.pi * 2);
      final rotated = (angle - t * math.pi * 2 + math.pi * 100) % (math.pi * 2);
      var   delta   = (rotated - (d / .55) % (math.pi * 2)).abs();
      if (delta > math.pi) delta = math.pi * 2 - delta;
      return delta < .75
          ? Color.lerp(primary, secondary, (d / 3.8).clamp(0.0, 1.0))
          : primary.withOpacity(.15);

    default:
      final pulse = math.sin(t * math.pi * 2 + (r * 8 + c) / 64.0 * math.pi) * .5 + .5;
      return Color.lerp(primary, secondary, pulse);
  }
}

// ─── Dot colour with animation phase t ∈ [0, 1) ──────────────────────────────
Color? _dot(String mode, int r, int c, double t) {
  final dx = c - 3.5, dy = r - 3.5;
  final d  = math.sqrt(dx * dx + dy * dy);
  switch (mode) {
    case 'Breathing':
      final v = _pat[r][c];
      if (v == 0) return null;
      final pulse = math.sin(t * math.pi * 2) * .5 + .5;
      if (v == 1) {
        return const Color(0xFFCCEEFF).withOpacity(.20 + pulse * .80);
      }
      final inv = (math.sin(t * math.pi * 2 + math.pi) * .25 + .75)
          .clamp(.4, 1.0);
      return const Color(0xFF9933FF).withOpacity(inv);

    case 'Pulse':
      for (int i = 0; i < 3; i++) {
        final rp = ((t + i / 3.0) % 1.0) * 4.5;
        if ((d - rp).abs() < .65) {
          return Color.lerp(
              const Color(0xFFFF2D95), const Color(0xFF8B20FF), i / 2.0);
        }
      }
      return null;

    case 'Wave':
      final wave = math.sin(c / 7.0 * math.pi * 2 + t * math.pi * 2) * 2.5 + 3.5;
      final dd = (r - wave).abs();
      return dd < .9 ? _cyan.withOpacity((1 - dd / .9).clamp(0, 1)) : null;

    case 'Spectrum':
      return HSVColor.fromAHSV(
          1, ((r * 8 + c) / 64 * 300 + t * 360) % 360, 1, .95).toColor();

    case 'Fireworks':
      const dots = [
        (0,2,Color(0xFFFF4400)),(0,5,Color(0xFFFFAA00)),(1,0,Color(0xFFFF2200)),
        (1,7,Color(0xFF00DDFF)),(2,3,Color(0xFFFFDD00)),(2,6,Color(0xFFFF4400)),
        (3,1,Color(0xFF00FF88)),(3,5,Color(0xFFFF8800)),(4,3,Color(0xFFFF2200)),
        (4,6,Color(0xFFFFAA00)),(5,0,Color(0xFF00DDFF)),(5,4,Color(0xFF00FF88)),
        (6,2,Color(0xFFFF4400)),(6,7,Color(0xFFFFDD00)),(7,1,Color(0xFFFF8800)),
        (7,5,Color(0xFF00FF88)),
      ];
      for (final (pr, pc, col) in dots) {
        if (pr == r && pc == c) {
          final a = ((math.sin(t * math.pi * 2 +
              ((pr * 8 + pc) % 16) / 16.0 * math.pi * 2) + 1) / 2)
              .clamp(0.0, 1.0);
          return a < .1 ? null : col.withOpacity(a);
        }
      }
      return null;

    case 'Spiral':
      if (d < .3 || d > 3.8) return null;
      final angle   = (math.atan2(dy, dx) + math.pi * 2) % (math.pi * 2);
      final rotated = (angle - t * math.pi * 2 + math.pi * 100) % (math.pi * 2);
      var delta     = (rotated - (d / .55) % (math.pi * 2)).abs();
      if (delta > math.pi) delta = math.pi * 2 - delta;
      return delta < .75
          ? Color.lerp(const Color(0xFF00FFAA), const Color(0xFF00AAFF), d / 3.8)
          : null;
    default: return null;
  }
}

// =============================================================================
//  LedDisplayScreen
// =============================================================================
class LedDisplayScreen extends StatefulWidget {
  const LedDisplayScreen({super.key});
  @override
  State<LedDisplayScreen> createState() => _State();
}

class _State extends State<LedDisplayScreen>
    with SingleTickerProviderStateMixin {
  int    _tab     = 0; // 0=Effects  1=Customize
  String _mode    = 'Breathing';
  double _bright  = .80;
  double _speed   = .60;
  int    _nav     = 0;
  bool   _sending = false;
  GeneratedLedPattern? _generatedPattern;
  late AnimationController _ctrl;

  // Customize tab
  late List<Color?> _matrix;
  Color _pen = _cyan;

  @override
  void initState() {
    super.initState();
    _matrix = _defaultMatrix();
    _ctrl   = AnimationController(vsync: this, duration: _dur(_speed))..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _setSpeed(double v) {
    setState(() => _speed = v);
    final was = _ctrl.isAnimating;
    _ctrl.stop();
    _ctrl.duration = _dur(v);
    if (was) _ctrl.repeat();
  }

  void _setMode(String m) {
    setState(() {
      _mode = m;
      _generatedPattern = null; // mode selection overrides any loaded AI pattern
    });
    _ctrl.reset(); _ctrl.repeat();
  }

  // Converts a Color to #RRGGBB hex string
  String _c2hex(Color c) {
    final v = c.toARGB32();
    final r = ((v >> 16) & 0xFF).toRadixString(16).padLeft(2, '0').toUpperCase();
    final g = ((v >>  8) & 0xFF).toRadixString(16).padLeft(2, '0').toUpperCase();
    final b = (v & 0xFF).toRadixString(16).padLeft(2, '0').toUpperCase();
    return '#$r$g$b';
  }

  // Builds the 8×8 rgb_grid matching exactly what the Flutter preview displays.
  List<List<String>> _buildRgbGrid() {
    final double t = _ctrl.value;
    return List.generate(8, (r) => List.generate(8, (c) {
      Color? color;
      if (_generatedPattern != null) {
        color = _dotWithGrid(
          _mode,
          _generatedPattern!.grid,
          _hexColor(_generatedPattern!.primaryColor),
          _hexColor(_generatedPattern!.secondaryColor),
          r, c, t,
        );
      } else if (_tab == 0) {
        color = _dot(_mode, r, c, t);
      } else {
        color = _matrix[r * 8 + c];
      }
      if (color == null || color.a < 0.05) return '#000000';
      return _c2hex(color);
    }));
  }

  Future<void> _preview() async {
    if (_sending) return;

    setState(() => _sending = true);
    try {
      final int bri = (_bright * 100).round().clamp(0, 100);
      final int spd = (_speed  * 100).round().clamp(0, 100);
      final List<List<String>> rgbGrid = _buildRgbGrid();

      final Map<String, dynamic> payload;
      if (_generatedPattern != null) {
        final p = _generatedPattern!;
        payload = {
          'mode':       p.mode,
          'brightness': bri,
          'speed':      spd,
          'colors':     [p.primaryColor, p.secondaryColor],
          'pattern':    p.grid,
          'rgb_grid':   rgbGrid,
        };
      } else if (_tab == 0) {
        final base = LedConfig.fromEffects(mode: _mode, brightness: _bright, speed: _speed);
        payload = {...base.toJson(), 'rgb_grid': rgbGrid};
      } else {
        // Customize tab: force static mode so the painted pattern shows as-is.
        // Strip pixel_colors — it's redundant with rgb_grid and bloats the
        // payload past the Arduino's ArduinoJson buffer capacity.
        final base = LedConfig.fromCustom(
          matrix: _matrix, brightness: _bright, speed: _speed, mode: 'static');
        final json = Map<String, dynamic>.from(base.toJson())..remove('pixel_colors');
        payload = {...json, 'rgb_grid': rgbGrid};
      }
      await api.sendPatternToDevice(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Sent to hat', style: _pp(size: 13)),
          backgroundColor: const Color(0xFF00C48C),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 1),
        ));
      }
    } catch (e) {
      debugPrint('[Preview] $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Failed: ${e.toString().replaceAll('Exception: ', '')}',
            style: _pp(size: 13),
          ),
          backgroundColor: const Color(0xFFFF4D4D),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Color _hexColor(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  String _mapAiMode(String aiMode) => switch (aiMode.toLowerCase()) {
    'pulse'                    => 'Pulse',
    'wave'                     => 'Wave',
    'burst' || 'fireworks'     => 'Fireworks',
    'spiral'                   => 'Spiral',
    _                          => 'Breathing',
  };

  void _applyAiPattern(GeneratedLedPattern pattern) {
    final primary = _hexColor(pattern.primaryColor);
    final newMatrix = List<Color?>.generate(64, (i) {
      final row = i ~/ 8;
      final col = i  % 8;
      if (row < pattern.grid.length && col < pattern.grid[row].length) {
        return pattern.grid[row][col] == 1 ? primary : null;
      }
      return null;
    });
    setState(() {
      _generatedPattern = pattern;
      _matrix           = newMatrix;
      _tab              = 0; // Effects tab — animated preview
      _mode             = _mapAiMode(pattern.mode);
      _bright           = (pattern.brightness / 100.0).clamp(0.0, 1.0);
      _speed            = (pattern.speed      / 100.0).clamp(0.0, 1.0);
    });
    _ctrl
      ..duration = _dur(_speed)
      ..reset()
      ..repeat();
  }

  void _openAiSheet() => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AiGenerateSheet(onGenerated: _applyAiPattern),
  );

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    return Scaffold(
      backgroundColor: _bg1,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bg1, _bg2],
          ),
        ),
        child: SafeArea(
          child: Column(children: [
            _TopBar(onBack: () => Navigator.maybePop(context)),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
              child: SegmentedTabs(
                selected: _tab,
                onTap: (i) => setState(() => _tab = i),
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
                child: _tab == 0 ? _effects() : _customize(),
              ),
            ),
            SentioBottomNav(
              index: _nav,
              onTap: (i) => setState(() => _nav = i),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Effects tab ─────────────────────────────────────────────────────────────
  Widget _effects() => AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LedMatrixPreview(
              mode:        _mode,
              t:           _ctrl.value,
              brightness:  _bright,
              aiGrid:      _generatedPattern?.grid,
              aiPrimary:   _generatedPattern != null
                               ? _hexColor(_generatedPattern!.primaryColor)
                               : null,
              aiSecondary: _generatedPattern != null
                               ? _hexColor(_generatedPattern!.secondaryColor)
                               : null,
            ),
            const SizedBox(height: 30),
            ControlSlider(
              label: 'Brightness', value: _bright,
              icon: PhosphorIcons.sun(),
              onChanged: (v) => setState(() => _bright = v),
            ),
            const SizedBox(height: 22),
            ControlSlider(
              label: 'Speed', value: _speed,
              icon: PhosphorIcons.sparkle(),
              onChanged: _setSpeed,
            ),
            const SizedBox(height: 22),
            ModeDropdown(mode: _mode, modes: _modes, onPick: _setMode),
            if (_generatedPattern != null) ...[
              const SizedBox(height: 16),
              _AiPatternInfoCard(pattern: _generatedPattern!),
            ],
            const SizedBox(height: 16),
            _AiGenerateButton(onTap: _openAiSheet),
            const SizedBox(height: 12),
            GradientButton(label: 'Preview', onTap: _preview, loading: _sending),
          ],
        ),
      );

  // ── Customize tab ────────────────────────────────────────────────────────────
  Widget _customize() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassCard(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('Custom Pattern',
                    style: _pp(size: 14, weight: FontWeight.w600)),
                const Spacer(),
                Text('Tap dots to paint',
                    style: _pp(size: 11, color: _muted)),
              ]),
              const SizedBox(height: 14),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _EditableGrid(
                  matrix: _matrix,
                  onTap: (i) => setState(() =>
                      _matrix = List<Color?>.from(_matrix)..[i] = _pen),
                )),
                const SizedBox(width: 14),
                _Sidebar(
                  pen: _pen,
                  onColor: (c) => setState(() => _pen = c),
                  onPreset: () => setState(() => _matrix = _defaultMatrix()),
                  onClear: () => setState(() => _matrix = List.filled(64, null)),
                  onPicker: () => _openPicker(),
                ),
              ]),
            ],
          )),
          const SizedBox(height: 22),
          ControlSlider(
            label: 'Brightness', value: _bright,
            icon: PhosphorIcons.sun(),
            onChanged: (v) => setState(() => _bright = v),
          ),
          const SizedBox(height: 22),
          ControlSlider(
            label: 'Speed', value: _speed,
            icon: PhosphorIcons.sparkle(),
            onChanged: _setSpeed,
          ),
          const SizedBox(height: 22),
          ModeDropdown(mode: _mode, modes: _modes, onPick: _setMode),
          if (_generatedPattern != null) ...[
            const SizedBox(height: 16),
            _AiPatternInfoCard(pattern: _generatedPattern!),
          ],
          const SizedBox(height: 16),
          _AiGenerateButton(onTap: _openAiSheet),
          const SizedBox(height: 12),
          GradientButton(label: 'Preview', onTap: _preview, loading: _sending),
        ],
      );

  void _openPicker() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _HsvSheet(
          initial: _pen,
          onPicked: (c) => setState(() => _pen = c),
        ),
      );
}

// =============================================================================
//  _TopBar
// =============================================================================
class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          _Btn(icon: PhosphorIcons.caretLeft(), onTap: onBack),
          Expanded(
            child: Text('LED Display',
              textAlign: TextAlign.center,
              style: _pp(size: 18, weight: FontWeight.bold)),
          ),
          _Btn(
            icon: PhosphorIcons.info(),
            color: _muted,
            onTap: () {},
          ),
        ]),
      );
}

class _Btn extends StatelessWidget {
  final PhosphorIconData icon;
  final Color            color;
  final VoidCallback     onTap;
  const _Btn({required this.icon, required this.onTap,
    this.color = Colors.white});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      );
}

// =============================================================================
//  SegmentedTabs
// =============================================================================
class SegmentedTabs extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onTap;
  const SegmentedTabs({super.key, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
        height: 48,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: ['Effects', 'Customize'].asMap().entries.map((e) {
            final active = e.key == selected;
            return Expanded(
              child: GestureDetector(
                onTap: () => onTap(e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFF0D2035)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: active
                        ? Border.all(color: _cyan.withOpacity(.45), width: 1)
                        : null,
                    boxShadow: active
                        ? [BoxShadow(
                            color: _cyan.withOpacity(.07),
                            blurRadius: 10)]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(e.value,
                    style: _pp(
                      size: 14,
                      weight: FontWeight.w600,
                      color: active ? Colors.white : _muted,
                    )),
                ),
              ),
            );
          }).toList(),
        ),
      );
}

// =============================================================================
//  LedMatrixPreview  — animated 8 × 8 grid drawn on Canvas
// =============================================================================
class LedMatrixPreview extends StatelessWidget {
  final String mode;
  final double t, brightness;
  final List<List<int>>? aiGrid;
  final Color? aiPrimary, aiSecondary;
  const LedMatrixPreview({
    super.key,
    required this.mode,
    required this.t,
    required this.brightness,
    this.aiGrid,
    this.aiPrimary,
    this.aiSecondary,
  });

  List<Color?> _previewMatrix() => List<Color?>.generate(64, (i) {
        final r = i ~/ 8;
        final c = i  % 8;
        final Color? color;
        if (aiGrid != null && aiPrimary != null) {
          color = _dotWithGrid(mode, aiGrid!, aiPrimary!, aiSecondary ?? aiPrimary!, r, c, t);
        } else {
          color = _dot(mode, r, c, t);
        }
        return color == null
            ? null
            : color.withOpacity((color.opacity * brightness).clamp(0.0, 1.0));
      });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final w = math.min((width - 88).clamp(0.0, 260.0), width);
    return Center(
      child: SizedBox(
        width: w,
        child: _EditableGrid(matrix: _previewMatrix(), onTap: (_) {}),
      ),
    );
  }
}

// =============================================================================
//  GlassCard
// =============================================================================
class GlassCard extends StatelessWidget {
  final Widget             child;
  final EdgeInsetsGeometry padding;
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
        ),
        child: child,
      );
}

// =============================================================================
//  ControlSlider
// =============================================================================
class ControlSlider extends StatelessWidget {
  final String           label;
  final double           value;
  final PhosphorIconData icon;
  final ValueChanged<double> onChanged;
  const ControlSlider({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(children: [
        Row(children: [
          Text(label,
              style: _pp(size: 15, weight: FontWeight.w600)),
          const Spacer(),
          Text('${(value * 100).round()}%',
              style: _pp(size: 14, color: _muted, weight: FontWeight.w500)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Icon(icon, color: _muted, size: 18),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor:   _cyan,
                inactiveTrackColor: const Color(0xFF1A2840),
                thumbColor:         _cyan,
                overlayColor:       _cyan.withOpacity(.12),
                thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 10),
                trackHeight: 4,
              ),
              child: Slider(value: value, onChanged: onChanged),
            ),
          ),
        ]),
      ]);
}

// =============================================================================
//  ModeDropdown
// =============================================================================
class ModeDropdown extends StatelessWidget {
  final String            mode;
  final List<String>      modes;
  final ValueChanged<String> onPick;
  const ModeDropdown({
    super.key,
    required this.mode,
    required this.modes,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
        Text('Mode', style: _pp(size: 15, weight: FontWeight.w600)),
        const Spacer(),
        GestureDetector(
          onTap: () async {
            final chosen = await showModalBottomSheet<String>(
              context: context,
              backgroundColor: _surface,
              shape: const RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24))),
              builder: (_) => _ModeSheet(modes: modes, current: mode),
            );
            if (chosen != null) onPick(chosen);
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 14, 12),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(mode,
                  style: _pp(size: 14, weight: FontWeight.w500)),
              const SizedBox(width: 10),
              Icon(PhosphorIcons.caretDown(), color: _muted, size: 14),
            ]),
          ),
        ),
      ]);
}

class _ModeSheet extends StatelessWidget {
  final List<String> modes;
  final String       current;
  const _ModeSheet({required this.modes, required this.current});

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: _muted.withOpacity(.4),
              borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 8),
          ...modes.map((m) => ListTile(
            title: Text(m,
                style: _pp(size: 15, weight: FontWeight.w500,
                    color: m == current ? _cyan : Colors.white)),
            trailing: m == current
                ? const Icon(Icons.check_rounded, color: _cyan)
                : null,
            onTap: () => Navigator.pop(context, m),
          )),
          const SizedBox(height: 8),
        ]),
      );
}

// =============================================================================
//  GradientButton  — blue → purple → pink
// =============================================================================
class GradientButton extends StatelessWidget {
  final String       label;
  final VoidCallback onTap;
  final bool         loading;
  const GradientButton({
    super.key,
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: loading ? null : onTap,
        child: Container(
          height: 58,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [
              Color(0xFF006BFF),
              Color(0xFF8A3FFC),
              Color(0xFFC13BFF),
            ]),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: _purple.withOpacity(loading ? .20 : .45),
                blurRadius: 22, offset: const Offset(0, 7)),
            ],
          ),
          alignment: Alignment.center,
          child: loading
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white))
              : Text(label, style: _pp(size: 17, weight: FontWeight.bold)),
        ),
      );
}

// =============================================================================
//  SentioBottomNav
// =============================================================================
class SentioBottomNav extends StatelessWidget {
  final int               index;
  final ValueChanged<int> onTap;
  const SentioBottomNav(
      {super.key, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: _surface,
          border: Border(top: BorderSide(color: _border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavBtn(
                  icon: PhosphorIcons.house(), label: 'Home',
                  active: index == 0, onTap: () => onTap(0)),
                _NavBtn(
                  icon: PhosphorIcons.chartBar(), label: 'History',
                  active: index == 1, onTap: () => onTap(1)),
                _NavBtn(
                  icon: PhosphorIcons.user(), label: 'Profile',
                  active: index == 2, onTap: () => onTap(2)),
              ],
            ),
          ),
        ),
      );
}

class _NavBtn extends StatelessWidget {
  final PhosphorIconData icon;
  final String           label;
  final bool             active;
  final VoidCallback     onTap;
  const _NavBtn({
    required this.icon, required this.label,
    required this.active, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = active ? _cyan : _muted;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 76,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: c, size: 22),
          const SizedBox(height: 4),
          Text(label, style: _pp(size: 10, color: c)),
        ]),
      ),
    );
  }
}

// =============================================================================
//  Customize tab — editable grid
// =============================================================================
class _EditableGrid extends StatelessWidget {
  final List<Color?>      matrix;
  final ValueChanged<int> onTap;
  const _EditableGrid({required this.matrix, required this.onTap});

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF050E18),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _cyan.withOpacity(.22)),
          ),
          child: LayoutBuilder(builder: (_, c) {
            final sz = c.maxWidth / 8;
            final dr = sz * .28;
            return GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.all(sz * .05),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 8),
              itemCount: 64,
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => onTap(i),
                child: Center(child: _LedDot(dr: dr, color: matrix[i])),
              ),
            );
          }),
        ),
      );
}

class _LedDot extends StatelessWidget {
  final double dr;
  final Color? color;
  const _LedDot({required this.dr, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: dr * 2, height: dr * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color ?? const Color(0xFF0A1525),
          boxShadow: color == null
              ? null
              : [
                  BoxShadow(color: color!.withOpacity(.7),
                      blurRadius: dr * .9, spreadRadius: dr * .1),
                  BoxShadow(color: color!.withOpacity(.3),
                      blurRadius: dr * 2.4, spreadRadius: dr * .4),
                ],
        ),
      );
}

// ── Colour sidebar ─────────────────────────────────────────────────────────────
const _quickColors = [
  Color(0xFF00D9FF), Color(0xFF8A3FFC), Color(0xFFFF4D4D),
  Color(0xFF43F26B), Color(0xFFFFD21E), Colors.white,
];

class _Sidebar extends StatelessWidget {
  final Color            pen;
  final ValueChanged<Color> onColor;
  final VoidCallback     onPreset, onClear, onPicker;
  const _Sidebar({
    required this.pen,  required this.onColor,
    required this.onPreset, required this.onClear, required this.onPicker,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 60,
        child: Column(children: [
          Text('Color', style: _pp(size: 11, color: _muted)),
          const SizedBox(height: 8),
          ..._quickColors.map((c) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _Swatch(color: c, active: pen == c,
                onTap: () => onColor(c)),
          )),
          GestureDetector(
            onTap: onPicker,
            child: Container(
              width: 36, height: 36,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const SweepGradient(colors: [
                  Color(0xFFFF0000), Color(0xFFFFFF00), Color(0xFF00FF00),
                  Color(0xFF00FFFF), Color(0xFF0000FF), Color(0xFFFF00FF),
                  Color(0xFFFF0000),
                ]),
                border: Border.all(
                    color: Colors.white.withOpacity(.25), width: 1.5),
              ),
              child: const Icon(Icons.add_rounded,
                  color: Colors.white, size: 14),
            ),
          ),
          Text('Preset', style: _pp(size: 11, color: _muted)),
          const SizedBox(height: 6),
          _Tool(icon: PhosphorIcons.gridFour(), color: _cyan, onTap: onPreset),
          const SizedBox(height: 6),
          _Tool(icon: PhosphorIcons.trash(), color: _muted, onTap: onClear),
        ]),
      );
}

class _Swatch extends StatelessWidget {
  final Color c; final bool active; final VoidCallback onTap;
  const _Swatch({required Color color, required this.active,
    required this.onTap}) : c = color;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle, color: c,
            border: Border.all(
              color: active ? Colors.white : c.withOpacity(.3),
              width: active ? 2.5 : 1),
            boxShadow: active
                ? [BoxShadow(color: c.withOpacity(.5),
                    blurRadius: 8, spreadRadius: 1)]
                : null,
          ),
        ),
      );
}

class _Tool extends StatelessWidget {
  final PhosphorIconData icon; final Color color; final VoidCallback onTap;
  const _Tool({required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF060E1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(.3)),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      );
}

// =============================================================================
//  HSV colour picker (bottom sheet)
// =============================================================================
class _HsvSheet extends StatefulWidget {
  final Color initial;
  final ValueChanged<Color> onPicked;
  const _HsvSheet({required this.initial, required this.onPicked});
  @override
  State<_HsvSheet> createState() => _HsvSheetState();
}

class _HsvSheetState extends State<_HsvSheet> {
  late HSVColor _hsv;
  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initial);
  }
  @override
  Widget build(BuildContext context) {
    final picked = _hsv.toColor();
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0C1826),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: _muted.withOpacity(.4),
            borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 16),
        Text('Choose Color', style: _pp(size: 16, weight: FontWeight.bold)),
        const SizedBox(height: 20),
        _SvBox(
          hue: _hsv.hue, sat: _hsv.saturation, val: _hsv.value,
          onChanged: (s, v) =>
              setState(() => _hsv = _hsv.withSaturation(s).withValue(v)),
        ),
        const SizedBox(height: 14),
        _HueBar(
          hue: _hsv.hue,
          onChanged: (h) => setState(() => _hsv = _hsv.withHue(h)),
        ),
        const SizedBox(height: 18),
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: picked, shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 1.5)),
          ),
          const SizedBox(width: 14),
          Text(
            '#${picked.value.toRadixString(16).substring(2).toUpperCase()}',
            style: _pp(size: 15, weight: FontWeight.w600)),
        ]),
        const SizedBox(height: 20),
        GradientButton(
          label: 'Apply',
          onTap: () {
            widget.onPicked(picked);
            Navigator.pop(context);
          },
        ),
      ]),
    );
  }
}

class _SvBox extends StatelessWidget {
  final double hue, sat, val;
  final void Function(double s, double v) onChanged;
  const _SvBox({required this.hue, required this.sat,
    required this.val, required this.onChanged});
  void _h(Offset o, Size sz) => onChanged(
      (o.dx / sz.width).clamp(0, 1),
      (1 - o.dy / sz.height).clamp(0, 1));
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (_, c) {
          final sz = Size(c.maxWidth, 180.0);
          return GestureDetector(
            onPanUpdate: (d) => _h(d.localPosition, sz),
            onTapDown:   (d) => _h(d.localPosition, sz),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CustomPaint(
                size: sz,
                painter: _SvPaint(hue: hue, sat: sat, val: val),
              ),
            ),
          );
        },
      );
}

class _SvPaint extends CustomPainter {
  final double hue, sat, val;
  const _SvPaint({required this.hue, required this.sat, required this.val});
  @override
  void paint(Canvas canvas, Size sz) {
    final rect = Offset.zero & sz;
    final hc = HSVColor.fromAHSV(1, hue, 1, 1).toColor();
    canvas.drawRect(rect, Paint()
      ..shader = LinearGradient(colors: [Colors.white, hc]).createShader(rect));
    canvas.drawRect(rect, Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.black]).createShader(rect));
    final cx = sat * sz.width;
    final cy = (1 - val) * sz.height;
    canvas.drawCircle(Offset(cx, cy), 10,
        Paint()..color = Colors.white..style = PaintingStyle.stroke
            ..strokeWidth = 2.5);
  }
  @override
  bool shouldRepaint(_SvPaint o) =>
      o.hue != hue || o.sat != sat || o.val != val;
}

class _HueBar extends StatelessWidget {
  final double hue;
  final ValueChanged<double> onChanged;
  const _HueBar({required this.hue, required this.onChanged});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (_, c) {
          final sz = Size(c.maxWidth, 26.0);
          return GestureDetector(
            onPanUpdate: (d) =>
                onChanged((d.localPosition.dx / sz.width * 360).clamp(0, 360)),
            onTapDown: (d) =>
                onChanged((d.localPosition.dx / sz.width * 360).clamp(0, 360)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CustomPaint(
                size: sz,
                painter: _HuePaint(hue: hue),
              ),
            ),
          );
        },
      );
}

class _HuePaint extends CustomPainter {
  final double hue;
  const _HuePaint({required this.hue});
  @override
  void paint(Canvas canvas, Size sz) {
    canvas.drawRect(Offset.zero & sz, Paint()
      ..shader = const LinearGradient(colors: [
        Color(0xFFFF0000), Color(0xFFFFFF00), Color(0xFF00FF00),
        Color(0xFF00FFFF), Color(0xFF0000FF), Color(0xFFFF00FF),
        Color(0xFFFF0000),
      ]).createShader(Offset.zero & sz));
    final x = hue / 360 * sz.width;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(x, sz.height / 2), width: 4, height: sz.height + 4),
        const Radius.circular(2)),
      Paint()..color = Colors.white);
  }
  @override
  bool shouldRepaint(_HuePaint o) => o.hue != hue;
}

// =============================================================================
//  _AiGenerateButton
// =============================================================================
class _AiGenerateButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AiGenerateButton({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 52,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _cyan.withOpacity(.45), width: 1.2),
      ),
      alignment: Alignment.center,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(PhosphorIcons.sparkle(), color: _cyan, size: 18),
        const SizedBox(width: 8),
        Text('Generate with AI',
            style: _pp(size: 15, weight: FontWeight.w600, color: _cyan)),
      ]),
    ),
  );
}

// =============================================================================
//  _AiPatternInfoCard
// =============================================================================
class _AiPatternInfoCard extends StatelessWidget {
  final GeneratedLedPattern pattern;
  const _AiPatternInfoCard({required this.pattern});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: _cyan.withOpacity(.06),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _cyan.withOpacity(.2)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(PhosphorIcons.sparkle(), color: _cyan, size: 16),
      const SizedBox(width: 10),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(pattern.name,
              style: _pp(size: 13, weight: FontWeight.w600, color: _cyan)),
          const SizedBox(height: 2),
          Text(pattern.description,
              style: _pp(size: 11, color: _muted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ],
      )),
    ]),
  );
}

// =============================================================================
//  _AiGenerateSheet
// =============================================================================
class _AiGenerateSheet extends StatefulWidget {
  final ValueChanged<GeneratedLedPattern> onGenerated;
  const _AiGenerateSheet({required this.onGenerated});
  @override
  State<_AiGenerateSheet> createState() => _AiGenerateSheetState();
}

class _AiGenerateSheetState extends State<_AiGenerateSheet> {
  final _ctrl = TextEditingController();
  bool    _loading = false;
  String? _error;

  static const _examples = [
    'calm ocean waves',
    'focused green target',
    'excited yellow explosion',
    'purple relaxing spiral',
    'red chaotic stress flicker',
  ];

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _generate() async {
    final prompt = _ctrl.text.trim();
    if (prompt.isEmpty || _loading) return;
    setState(() { _loading = true; _error = null; });
    try {
      final pattern = await api.generateLedPattern(
        prompt: prompt,
        brightness: 80,
        speed: 60,
      );
      if (!mounted) return;
      widget.onGenerated(pattern);
      Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Could not generate pattern.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0C1826),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // drag handle
          Container(width: 36, height: 4,
            decoration: BoxDecoration(
              color: _muted.withOpacity(.4),
              borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text('Generate LED Pattern',
              style: _pp(size: 17, weight: FontWeight.bold)),
          const SizedBox(height: 20),
          // text field
          Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: TextField(
              controller: _ctrl,
              maxLength: 300,
              maxLines: 3,
              minLines: 1,
              style: _pp(size: 14),
              decoration: InputDecoration(
                hintText: 'Describe the pattern you want…',
                hintStyle: _pp(size: 14, color: _muted),
                border: InputBorder.none,
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
            ),
          ),
          // examples
          const SizedBox(height: 14),
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _examples.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => setState(() => _ctrl.text = _examples[i]),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _cyan.withOpacity(.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _cyan.withOpacity(.25)),
                  ),
                  child: Text(_examples[i],
                      style: _pp(size: 11, color: _cyan)),
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
                style: _pp(size: 12, color: const Color(0xFFFF4D4D))),
          ],
          const SizedBox(height: 24),
          // buttons
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: _loading ? null : () => Navigator.pop(context),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: _border),
                  ),
                  alignment: Alignment.center,
                  child: Text('Cancel',
                      style: _pp(size: 15, color: _muted,
                          weight: FontWeight.w500)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: _generate,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [
                      Color(0xFF006BFF),
                      Color(0xFF8A3FFC),
                      Color(0xFFC13BFF),
                    ]),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [BoxShadow(
                      color: _purple.withOpacity(_loading ? .15 : .40),
                      blurRadius: 18, offset: const Offset(0, 6))],
                  ),
                  alignment: Alignment.center,
                  child: _loading
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                      : Text('Generate',
                          style: _pp(size: 15, weight: FontWeight.bold)),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
