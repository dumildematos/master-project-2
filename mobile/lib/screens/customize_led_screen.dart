// =============================================================================
//  CustomizeLedScreen  —  Pattern picker with live animated previews.
//
//  Architecture:
//  • ONE AnimationController lives in _CustomizeLedState.
//  • Only the selected pattern card receives a live animValue (0..1).
//  • All other cards receive animValue = 0.0  →  static thumbnail.
//  • Speed slider updates the controller duration immediately.
//  • Pattern tap: reset + repeat the shared controller.
// =============================================================================
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'customize_led_colors_screen.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kBg1    = Color(0xFF02080D);
const _kBg2    = Color(0xFF07131B);
const _kCard   = Color(0xFF0C1B26);
const _kBorder = Color(0xFF182535);
const _kCyan   = Color(0xFF00D9FF);
const _kMuted  = Color(0xFF9AA6B2);

const _kPatterns = [
  'Breathing', 'Pulse',  'Wave',
  'Circle',    'Flow',   'Spectrum',
  'Fireworks', 'Rain',   'Spiral',
];

const _kColorModes = ['Single Color', 'Multi Color', 'Rainbow'];

TextStyle _pp({
  double size = 14,
  FontWeight weight = FontWeight.normal,
  Color color = Colors.white,
}) =>
    GoogleFonts.poppins(fontSize: size, fontWeight: weight, color: color);

Duration _speedToDuration(double speed) =>
    Duration(milliseconds: ((1 - speed) * 3500 + 500).round());

// =============================================================================
//  Animated dot colour  —  pattern × (r, c, t) → Color?
//  t = 0..1 repeating animation phase.
// =============================================================================
Color? _dotColor(String pattern, int r, int c, double t) {
  final cx = c - 3.5, cy = r - 3.5;
  final d  = math.sqrt(cx * cx + cy * cy);

  switch (pattern) {
    // ── Breathing: radial glow that pulses ────────────────────────────────
    case 'Breathing':
      final pulse   = (math.sin(t * math.pi * 2) * 0.5 + 0.5);
      final radial  = (1 - d / 5.0).clamp(0.0, 1.0);
      if (radial < 0.05) return null;
      return Color.lerp(
        const Color(0xFF002299),
        const Color(0xFFAAEEFF),
        radial * radial,
      )!.withOpacity(((0.2 + pulse * 0.8) * radial).clamp(0, 1));

    // ── Pulse: three expanding rings ──────────────────────────────────────
    case 'Pulse':
      for (int i = 0; i < 3; i++) {
        final ringPos = ((t + i / 3.0) % 1.0) * 4.5;
        if ((d - ringPos).abs() < 0.65) {
          return Color.lerp(
            const Color(0xFFFF2D95),
            const Color(0xFF8B20FF),
            i / 2.0,
          );
        }
      }
      return null;

    // ── Wave: sine wave shifts horizontally ───────────────────────────────
    case 'Wave':
      final wave = math.sin(c / 7.0 * math.pi * 2 + t * math.pi * 2) * 2.5 + 3.5;
      final dd = (r - wave).abs();
      return dd < 0.85 ? _kCyan.withOpacity((1 - dd / 0.85).clamp(0, 1)) : null;

    // ── Circle: ring rotates with shifting hue ────────────────────────────
    case 'Circle':
      if ((d - 3.2).abs() < 0.65) {
        final angle = math.atan2(cy, cx);
        final hueT  = ((angle + math.pi) / (2 * math.pi) + t) % 1.0;
        return Color.lerp(
            const Color(0xFF8B20FF), const Color(0xFFFF2D95), hueT);
      }
      return null;

    // ── Flow: border flows clockwise + pulsing centre ─────────────────────
    case 'Flow':
      if (r == 0 || r == 7 || c == 0 || c == 7) {
        double pos;
        if (r == 0) pos = c / 28.0;
        else if (c == 7) pos = (7 + r) / 28.0;
        else if (r == 7) pos = (7 + 7 + (7 - c)) / 28.0;
        else pos = (7 + 7 + 7 + (7 - r)) / 28.0;
        final bright = ((math.sin((pos - t) * math.pi * 6) + 1) / 2).clamp(0.0, 1.0);
        return bright < 0.1
            ? null
            : Color.lerp(const Color(0xFF0044FF), const Color(0xFF7B10EE), pos)!
                .withOpacity(bright);
      }
      if ((r == 2 || r == 5) && c >= 2 && c <= 5) return const Color(0xFF2244CC);
      if ((c == 2 || c == 5) && r >= 2 && r <= 5) return const Color(0xFF2244CC);
      if ((r == 3 || r == 4) && (c == 3 || c == 4)) {
        final pulse = (math.sin(t * math.pi * 4) * 0.5 + 0.5);
        return const Color(0xFF00BBFF).withOpacity(0.3 + pulse * 0.7);
      }
      return null;

    // ── Spectrum: hues rotate ─────────────────────────────────────────────
    case 'Spectrum':
      final hue = ((r * 8 + c) / 64.0 * 300 + t * 360) % 360;
      return HSVColor.fromAHSV(1, hue, 1, .9).toColor();

    // ── Fireworks: dots twinkle with offset phases ────────────────────────
    case 'Fireworks':
      const dots = [
        (0, 2, Color(0xFFFF4400)), (0, 5, Color(0xFFFFAA00)),
        (1, 0, Color(0xFFFF2200)), (1, 7, Color(0xFF00DDFF)),
        (2, 3, Color(0xFFFFDD00)), (2, 6, Color(0xFFFF4400)),
        (3, 1, Color(0xFF00FF88)), (3, 5, Color(0xFFFF8800)),
        (4, 3, Color(0xFFFF2200)), (4, 6, Color(0xFFFFAA00)),
        (5, 0, Color(0xFF00DDFF)), (5, 4, Color(0xFF00FF88)),
        (6, 2, Color(0xFFFF4400)), (6, 7, Color(0xFFFFDD00)),
        (7, 1, Color(0xFFFF8800)), (7, 5, Color(0xFF00FF88)),
      ];
      for (final (pr, pc, col) in dots) {
        if (pr == r && pc == c) {
          final phase = ((pr * 8 + pc) % 16) / 16.0 * math.pi * 2;
          final a = ((math.sin(t * math.pi * 2 + phase) + 1) / 2).clamp(0.0, 1.0);
          return a < 0.1 ? null : col.withOpacity(a);
        }
      }
      return null;

    // ── Rain: drops fall per column ───────────────────────────────────────
    case 'Rain':
      const offsets = [0.0, 0.3, 0.6, 0.1, 0.8, 0.4, 0.7, 0.2];
      final dropPos = ((t + offsets[c]) % 1.0) * 11 - 2;
      final dd = (r - dropPos).abs();
      if (dd > 2.5) return null;
      final a = (1 - dd / 2.5).clamp(0.0, 1.0);
      return Color.lerp(const Color(0xFF88CCFF), const Color(0xFF0033AA), dd / 2.5)!
          .withOpacity(a);

    // ── Spiral: rotates ───────────────────────────────────────────────────
    case 'Spiral':
      if (d < 0.3 || d > 3.8) return null;
      final angle   = (math.atan2(cy, cx) + math.pi * 2) % (math.pi * 2);
      final rotated = (angle - t * math.pi * 2 + math.pi * 100) % (math.pi * 2);
      var delta     = (rotated - (d / 0.55) % (math.pi * 2)).abs();
      if (delta > math.pi) delta = math.pi * 2 - delta;
      return delta < 0.75
          ? Color.lerp(const Color(0xFF00FFAA), const Color(0xFF00AAFF), d / 3.8)
          : null;

    default:
      return null;
  }
}

// =============================================================================
//  Screen
// =============================================================================
class CustomizeLedScreen extends StatefulWidget {
  const CustomizeLedScreen({super.key});

  @override
  State<CustomizeLedScreen> createState() => _CustomizeLedState();
}

class _CustomizeLedState extends State<CustomizeLedScreen>
    with SingleTickerProviderStateMixin {
  String _selectedPattern = 'Breathing';
  String _colorMode       = 'Single Color';
  double _speed           = 0.65;
  double _brightness      = 0.80;
  int    _tab             = 0;
  int    _navIndex        = 0;

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync:    this,
      duration: _speedToDuration(_speed),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPatternTap(String pattern) {
    if (pattern == _selectedPattern) return;
    setState(() => _selectedPattern = pattern);
    _controller.duration = _speedToDuration(_speed);
    _controller.reset();
    _controller.repeat();
  }

  void _onSpeedChanged(double v) {
    setState(() => _speed = v);
    final wasRunning = _controller.isAnimating;
    _controller.stop();
    _controller.duration = _speedToDuration(v);
    if (wasRunning) _controller.repeat();
  }

  Future<void> _onPreview() async {
    // TODO: push selected pattern + settings to API
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: _kBg1,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end:   Alignment.bottomCenter,
            colors: [_kBg1, _kBg2],
          ),
        ),
        child: SafeArea(
          child: Column(children: [
            _TopBar(onBack: () => Navigator.maybePop(context)),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SegmentedSelector(
                      labels:   const ['Patterns', 'Colors'],
                      selected: _tab,
                      onTap:    (i) {
                        if (i == 1) {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) =>
                                const CustomizeLedColorsScreen()));
                        } else {
                          setState(() => _tab = i);
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    // ── Animated pattern grid ─────────────────────────
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (_, __) => GridView.builder(
                        shrinkWrap: true,
                        physics:    const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount:   3,
                          crossAxisSpacing: 14,
                          mainAxisSpacing:  14,
                          childAspectRatio: 0.84,
                        ),
                        itemCount: _kPatterns.length,
                        itemBuilder: (_, i) {
                          final name       = _kPatterns[i];
                          final isSelected = name == _selectedPattern;
                          return PatternCard(
                            name:       name,
                            isSelected: isSelected,
                            animValue:  isSelected ? _controller.value : 0.0,
                            brightness: _brightness,
                            onTap:      () => _onPatternTap(name),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 28),
                    Divider(color: _kBorder.withOpacity(.6), height: 1),
                    const SizedBox(height: 24),

                    _SliderRow(
                      label:     'Animation Speed',
                      value:     _speed,
                      minIcon:   PhosphorIcons.timer(),
                      maxIcon:   PhosphorIcons.rabbit(),
                      minSize:   17,
                      maxSize:   22,
                      onChanged: _onSpeedChanged,
                    ),
                    const SizedBox(height: 22),

                    _SliderRow(
                      label:     'Brightness',
                      value:     _brightness,
                      minIcon:   PhosphorIcons.sun(),
                      maxIcon:   PhosphorIcons.sun(),
                      minSize:   16,
                      maxSize:   22,
                      onChanged: (v) => setState(() => _brightness = v),
                    ),
                    const SizedBox(height: 28),

                    Text('Color Mode',
                        style: _pp(size: 15, weight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    SegmentedSelector(
                      labels:   _kColorModes,
                      selected: _kColorModes.indexOf(_colorMode),
                      onTap:    (i) =>
                          setState(() => _colorMode = _kColorModes[i]),
                    ),
                    const SizedBox(height: 28),

                    GradientButton(label: 'Preview', onTap: _onPreview),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            SentioBottomNav(
              index: _navIndex,
              onTap: (i) => setState(() => _navIndex = i),
            ),
          ]),
        ),
      ),
    );
  }
}

// =============================================================================
//  Top bar
// =============================================================================
class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kBorder),
              ),
              child: Icon(PhosphorIcons.caretLeft(),
                  color: Colors.white, size: 18),
            ),
          ),
          Expanded(
            child: Text('Customize LED',
              textAlign: TextAlign.center,
              style: _pp(size: 18, weight: FontWeight.bold)),
          ),
          const SizedBox(width: 40),
        ]),
      );
}

// =============================================================================
//  PatternCard — receives animValue; only the selected card gets a live value
// =============================================================================
class PatternCard extends StatelessWidget {
  final String       name;
  final bool         isSelected;
  final double       animValue;  // 0..1 — live for selected, 0.0 for others
  final double       brightness;
  final VoidCallback onTap;

  const PatternCard({
    super.key,
    required this.name,
    required this.isSelected,
    required this.animValue,
    required this.brightness,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? _kCyan : _kBorder,
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: isSelected
                ? [BoxShadow(
                    color: _kCyan.withOpacity(.2),
                    blurRadius: 12, spreadRadius: 1)]
                : null,
          ),
          child: Column(children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                child: LedMatrixPreview(
                  pattern:    name,
                  brightness: brightness,
                  t:          animValue,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(name,
                style: _pp(
                  size: 11,
                  weight: FontWeight.w500,
                  color: isSelected ? _kCyan : Colors.white,
                )),
            ),
          ]),
        ),
      );
}

// =============================================================================
//  LedMatrixPreview — 8×8 grid drawn by CustomPainter using animated t
// =============================================================================
class LedMatrixPreview extends StatelessWidget {
  final String pattern;
  final double brightness;
  final double t;            // animation phase 0..1

  const LedMatrixPreview({
    super.key,
    required this.pattern,
    this.brightness = .85,
    this.t          = 0.0,
  });

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ColoredBox(
            color: const Color(0xFF050E18),
            child: CustomPaint(
              painter: _LedMatrixPainter(
                  pattern: pattern, brightness: brightness, t: t),
            ),
          ),
        ),
      );
}

class _LedMatrixPainter extends CustomPainter {
  final String pattern;
  final double brightness;
  final double t;
  const _LedMatrixPainter(
      {required this.pattern, required this.brightness, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final cw   = size.width  / 8;
    final ch   = size.height / 8;
    final dotR = math.min(cw, ch) * .27;
    final dim  = Paint()..color = const Color(0xFF0A1525);

    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final cx  = (c + .5) * cw;
        final cy  = (r + .5) * ch;
        final off = Offset(cx, cy);

        canvas.drawCircle(off, dotR, dim);

        final color = _dotColor(pattern, r, c, t);
        if (color != null) {
          canvas.drawCircle(off, dotR * 2.2,
              Paint()..color = color.withOpacity(.18 * brightness));
          canvas.drawCircle(off, dotR * 1.45,
              Paint()..color = color.withOpacity(.28 * brightness));
          canvas.drawCircle(off, dotR,
              Paint()..color = color.withOpacity(brightness));
        }
      }
    }
  }

  @override
  bool shouldRepaint(_LedMatrixPainter old) =>
      old.pattern != pattern || old.brightness != brightness || old.t != t;
}

// =============================================================================
//  GlassPanel
// =============================================================================
class GlassPanel extends StatelessWidget {
  final Widget             child;
  final EdgeInsetsGeometry padding;
  final double             radius;
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius  = 20,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: _kBorder),
        ),
        child: child,
      );
}

// =============================================================================
//  SegmentedSelector
// =============================================================================
class SegmentedSelector extends StatelessWidget {
  final List<String>      labels;
  final int               selected;
  final ValueChanged<int> onTap;
  const SegmentedSelector({
    super.key,
    required this.labels,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Container(
        height: 46,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: List.generate(labels.length, (i) {
            final active = i == selected;
            return Expanded(
              child: GestureDetector(
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFF0E2030) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: active
                        ? Border.all(color: _kCyan.withOpacity(.35), width: 1)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(labels[i],
                    style: _pp(
                      size: 13,
                      weight: FontWeight.w600,
                      color: active ? Colors.white : _kMuted,
                    )),
                ),
              ),
            );
          }),
        ),
      );
}

// =============================================================================
//  _SliderRow
// =============================================================================
class _SliderRow extends StatelessWidget {
  final String             label;
  final double             value;
  final PhosphorIconData   minIcon, maxIcon;
  final double             minSize, maxSize;
  final ValueChanged<double> onChanged;
  const _SliderRow({
    required this.label,
    required this.value,
    required this.minIcon,
    required this.maxIcon,
    required this.minSize,
    required this.maxSize,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _pp(size: 15, weight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(children: [
            Icon(minIcon, color: _kMuted, size: minSize),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor:   _kCyan,
                  inactiveTrackColor: _kBorder,
                  thumbColor:         _kCyan,
                  thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 9),
                  overlayColor: _kCyan.withOpacity(.12),
                  trackHeight: 3.5,
                ),
                child: Slider(value: value, onChanged: onChanged),
              ),
            ),
            Icon(maxIcon, color: Colors.white70, size: maxSize),
          ]),
        ],
      );
}

// =============================================================================
//  GradientButton
// =============================================================================
class GradientButton extends StatelessWidget {
  final String       label;
  final VoidCallback onTap;
  const GradientButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3D4BFF), Color(0xFFB820D9)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6633FF).withOpacity(.35),
                blurRadius: 16, offset: const Offset(0, 6)),
            ],
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: _pp(size: 16, weight: FontWeight.bold)),
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
          color: _kCard,
          border: Border(top: BorderSide(color: _kBorder)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(icon: PhosphorIcons.house(), label: 'Home',
                    active: index == 0, onTap: () => onTap(0)),
                _NavItem(icon: PhosphorIcons.chartBar(), label: 'History',
                    active: index == 1, onTap: () => onTap(1)),
                _NavItem(icon: PhosphorIcons.user(), label: 'Profile',
                    active: index == 2, onTap: () => onTap(2)),
              ],
            ),
          ),
        ),
      );
}

class _NavItem extends StatelessWidget {
  final PhosphorIconData icon;
  final String           label;
  final bool             active;
  final VoidCallback     onTap;
  const _NavItem({
    required this.icon, required this.label,
    required this.active, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? _kCyan : _kMuted;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label, style: _pp(size: 10, color: color)),
          ],
        ),
      ),
    );
  }
}
