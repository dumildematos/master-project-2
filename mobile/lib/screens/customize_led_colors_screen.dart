// =============================================================================
//  CustomizeLedColorsScreen  —  Colors tab: single colour, palette, rainbow.
//
//  Reuses GradientButton, SentioBottomNav from customize_led_screen.dart.
//  All colour previews drawn with CustomPainter — no image assets.
// =============================================================================
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'customize_led_screen.dart' show GradientButton, SentioBottomNav;

// ── Palette ───────────────────────────────────────────────────────────────────
const _kBg1    = Color(0xFF02080D);
const _kBg2    = Color(0xFF07131B);
const _kCard   = Color(0xFF0C1B26);
const _kBorder = Color(0xFF182535);
const _kCyan   = Color(0xFF00D9FF);
const _kMuted  = Color(0xFF9AA6B2);

TextStyle _pp({
  double size = 14, FontWeight weight = FontWeight.normal,
  Color color = Colors.white,
}) =>
    GoogleFonts.poppins(fontSize: size, fontWeight: weight, color: color);

// ── 12 single-colour swatches ─────────────────────────────────────────────────
const _kSwatches = [
  Color(0xFF00D9FF), // cyan
  Color(0xFF8A2CFF), // purple
  Color(0xFFFF2D95), // magenta
  Color(0xFFFF3B30), // red
  Color(0xFFFF8C00), // orange
  Color(0xFFFFD21E), // yellow
  Color(0xFF43F26B), // green
  Color(0xFF007AFF), // blue
  Color(0xFF5AC8FA), // light blue
  Color(0xFF00C7BE), // teal
  Colors.white,
  Color(0xFF3A3A3C), // dark
];

// ── 10 multi-colour palettes ──────────────────────────────────────────────────
const _kPalettes = [
  'Sunset', 'Ocean',  'Forest', 'Candy', 'Party',
  'Aurora', 'Neon',   'Pastel', 'Retro', 'Galaxy',
];

// ── Rainbow directions ────────────────────────────────────────────────────────
const _kDirections = [
  'Left to Right', 'Right to Left', 'Top to Bottom', 'Bottom to Top',
];

// ── Colour generators ─────────────────────────────────────────────────────────
Color _paletteColor(String name, int r, int c) {
  final idx = r * 5 + c;
  switch (name) {
    case 'Sunset':
      return HSVColor.fromAHSV(1, idx / 25 * 50, 1,
          (0.85 + c * .03).clamp(0, 1)).toColor();
    case 'Ocean':
      return HSVColor.fromAHSV(1, 200 + c / 4 * 40,
          (0.5 + r * .1).clamp(0, 1), (0.7 + c * .07).clamp(0, 1)).toColor();
    case 'Forest':
      return HSVColor.fromAHSV(1, 90 + r / 4 * 50,
          (0.7 + c * .06).clamp(0, 1), (0.65 + c * .07).clamp(0, 1)).toColor();
    case 'Candy':
      return HSVColor.fromAHSV(1, (280 + c / 4 * 80) % 360,
          (0.7 + r * .06).clamp(0, 1), .9).toColor();
    case 'Party':
      return HSVColor.fromAHSV(1, idx / 25 * 360, 1, .9).toColor();
    case 'Aurora':
      return HSVColor.fromAHSV(1, 120 + idx / 25 * 180,
          .8, (0.5 + c * .1).clamp(0, 1)).toColor();
    case 'Neon':
      return HSVColor.fromAHSV(1, (290 + c / 4 * 70) % 360,
          .9, (0.85 + r * .03).clamp(0, 1)).toColor();
    case 'Pastel':
      return HSVColor.fromAHSV(1, idx / 25 * 300,
          (0.25 + r * .07).clamp(0, 1), .95).toColor();
    case 'Retro':
      const hues = [0.0, 30.0, 55.0, 210.0, 130.0];
      return HSVColor.fromAHSV(1, hues[c % 5], .9,
          (0.7 + r * .07).clamp(0, 1)).toColor();
    case 'Galaxy':
      if (idx % 7 == 3) return Colors.white;
      return HSVColor.fromAHSV(1, (240 + idx / 25 * 80) % 360,
          .8, (0.15 + idx % 5 * .1).clamp(0, 1)).toColor();
    default:
      return Colors.grey;
  }
}

Color _rainbowDirColor(String dir, int r, int c, int rows, int cols) {
  final progress = switch (dir) {
    'Left to Right' => c / (cols - 1),
    'Right to Left' => 1 - c / (cols - 1),
    'Top to Bottom' => r / (rows - 1),
    'Bottom to Top' => 1 - r / (rows - 1),
    _               => 0.0,
  };
  return HSVColor.fromAHSV(1, progress * 300, 1, 1).toColor();
}

// =============================================================================
//  Screen
// =============================================================================
class CustomizeLedColorsScreen extends StatefulWidget {
  const CustomizeLedColorsScreen({super.key});

  @override
  State<CustomizeLedColorsScreen> createState() =>
      _CustomizeLedColorsState();
}

class _CustomizeLedColorsState extends State<CustomizeLedColorsScreen> {
  // ── Single colour ──────────────────────────────────────────────────────────
  Color  _singleColor  = const Color(0xFF00D9FF);
  double _pickerHue    = 180.0;  // 0-360
  double _pickerValue  = 1.0;    // 0-1 (picker Y axis + slider)

  // ── Multi colour ───────────────────────────────────────────────────────────
  String? _palette;

  // ── Rainbow ────────────────────────────────────────────────────────────────
  String _direction = 'Left to Right';

  // ── Global ─────────────────────────────────────────────────────────────────
  double _brightness   = 0.8;
  String _colorMode    = 'Single Color';
  int    _navIndex     = 0;

  void _pickSwatch(Color c) {
    final hsv = HSVColor.fromColor(c);
    setState(() {
      _singleColor = c;
      _pickerHue   = hsv.hue;
      _pickerValue = hsv.value;
      _colorMode   = 'Single Color';
      _palette     = null;
    });
  }

  void _pickFromCanvas(double hue, double val) {
    setState(() {
      _pickerHue   = hue;
      _pickerValue = val;
      _singleColor = HSVColor.fromAHSV(1, hue, 1, val).toColor();
      _colorMode   = 'Single Color';
      _palette     = null;
    });
  }

  void _pickPalette(String name) => setState(() {
        _palette   = name;
        _colorMode = 'Multi Color';
      });

  void _pickDirection(String dir) => setState(() {
        _direction = dir;
        _colorMode = 'Rainbow';
      });

  Future<void> _preview() async {
    // TODO: send _colorMode + settings to API
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
            // ── Header ──────────────────────────────────────────────────
            _TopBar(onBack: () => Navigator.maybePop(context)),

            // ── Segmented tabs (Colors active) ───────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: _SegmentedTabs(
                onPatternsTab: () => Navigator.maybePop(context),
              ),
            ),
            const SizedBox(height: 16),

            // ── Scrollable content ───────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 1. Single Color + picker ───────────────────────
                    GlassCard(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Single Color',
                            style: _pp(size: 15, weight: FontWeight.w600)),
                        const SizedBox(height: 14),
                        _SwatchGrid(
                          colors:   _kSwatches,
                          selected: _colorMode == 'Single Color'
                              ? _singleColor
                              : null,
                          onTap:    _pickSwatch,
                        ),
                        const SizedBox(height: 16),
                        Divider(color: _kBorder.withOpacity(.6)),
                        const SizedBox(height: 14),
                        Text('Color Picker',
                            style: _pp(size: 13, weight: FontWeight.w600,
                                color: _kMuted)),
                        const SizedBox(height: 10),
                        GradientColorPickerBar(
                          hue:       _pickerHue,
                          value:     _pickerValue,
                          onChanged: _pickFromCanvas,
                        ),
                        const SizedBox(height: 14),
                        SentioSlider(
                          value:     _pickerValue,
                          minIcon:   PhosphorIcons.sun(),
                          maxIcon:   PhosphorIcons.sun(),
                          minSize:   16, maxSize: 22,
                          onChanged: (v) => _pickFromCanvas(_pickerHue, v),
                        ),
                      ],
                    )),
                    const SizedBox(height: 14),

                    // ── 2. Multi Color ─────────────────────────────────
                    GlassCard(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Multi Color',
                            style: _pp(size: 15, weight: FontWeight.w600)),
                        const SizedBox(height: 14),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount:   5,
                            crossAxisSpacing: 10,
                            mainAxisSpacing:  10,
                            childAspectRatio: 0.82,
                          ),
                          itemCount: _kPalettes.length,
                          itemBuilder: (_, i) {
                            final name = _kPalettes[i];
                            return PalettePreviewCard(
                              name:       name,
                              isSelected: _palette == name &&
                                  _colorMode == 'Multi Color',
                              onTap:      () => _pickPalette(name),
                            );
                          },
                        ),
                      ],
                    )),
                    const SizedBox(height: 14),

                    // ── 3. Rainbow Direction ───────────────────────────
                    GlassCard(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Rainbow Direction',
                            style: _pp(size: 15, weight: FontWeight.w600)),
                        const SizedBox(height: 14),
                        Row(
                          children: _kDirections.map((dir) => Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: dir == _kDirections.last ? 0 : 8),
                              child: RainbowDirectionCard(
                                direction:  dir,
                                isSelected: _direction == dir &&
                                    _colorMode == 'Rainbow',
                                onTap:      () => _pickDirection(dir),
                              ),
                            ),
                          )).toList(),
                        ),
                      ],
                    )),
                    const SizedBox(height: 14),

                    // ── 4. Brightness ──────────────────────────────────
                    GlassCard(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text('Brightness',
                              style: _pp(size: 15, weight: FontWeight.w600)),
                          const Spacer(),
                          Text('${(_brightness * 100).round()}%',
                              style: _pp(size: 14, color: _kMuted)),
                        ]),
                        const SizedBox(height: 10),
                        SentioSlider(
                          value:     _brightness,
                          minIcon:   PhosphorIcons.sun(),
                          maxIcon:   PhosphorIcons.sun(),
                          minSize:   16, maxSize: 22,
                          onChanged: (v) => setState(() => _brightness = v),
                        ),
                      ],
                    )),
                    const SizedBox(height: 20),

                    // ── 5. Preview button ──────────────────────────────
                    GradientButton(label: 'Preview', onTap: _preview),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // ── Bottom nav ───────────────────────────────────────────────
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
//  Segmented tabs — Patterns (inactive) | Colors (active)
// =============================================================================
class _SegmentedTabs extends StatelessWidget {
  final VoidCallback onPatternsTab;
  const _SegmentedTabs({required this.onPatternsTab});

  @override
  Widget build(BuildContext context) => Container(
        height: 46,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
        ),
        child: Row(children: [
          // Patterns tab (inactive)
          Expanded(
            child: GestureDetector(
              onTap: onPatternsTab,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text('Patterns',
                  style: _pp(size: 13, weight: FontWeight.w600,
                      color: _kMuted)),
              ),
            ),
          ),
          // Colors tab (active)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0E2030),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kCyan.withOpacity(.5), width: 1),
                boxShadow: [
                  BoxShadow(color: _kCyan.withOpacity(.08),
                      blurRadius: 8, spreadRadius: 1),
                ],
              ),
              alignment: Alignment.center,
              child: Text('Colors',
                style: _pp(size: 13, weight: FontWeight.w600)),
            ),
          ),
        ]),
      );
}

// =============================================================================
//  GlassCard — dark translucent card container
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
          color: _kCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kBorder),
        ),
        child: child,
      );
}

// =============================================================================
//  Swatch grid — 2 rows × 6 cols
// =============================================================================
class _SwatchGrid extends StatelessWidget {
  final List<Color>  colors;
  final Color?       selected;
  final ValueChanged<Color> onTap;
  const _SwatchGrid(
      {required this.colors, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount:   6,
          crossAxisSpacing: 8,
          mainAxisSpacing:  8,
          childAspectRatio: 1,
        ),
        itemCount: colors.length,
        itemBuilder: (_, i) => ColorSwatchCircle(
          color:    colors[i],
          selected: selected == colors[i],
          onTap:    () => onTap(colors[i]),
        ),
      );
}

// =============================================================================
//  ColorSwatchCircle — single colour swatch button
// =============================================================================
class ColorSwatchCircle extends StatelessWidget {
  final Color        color;
  final bool         selected;
  final VoidCallback onTap;
  const ColorSwatchCircle(
      {super.key, required this.color, required this.selected,
       required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = color.computeLuminance() < 0.05;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: selected
                ? _kCyan
                : isDark
                    ? _kBorder
                    : color.withOpacity(.3),
            width: selected ? 2.5 : 1.2,
          ),
          boxShadow: selected
              ? [BoxShadow(
                  color: (isDark ? _kCyan : color).withOpacity(.55),
                  blurRadius: 10, spreadRadius: 2)]
              : null,
        ),
      ),
    );
  }
}

// =============================================================================
//  GradientColorPickerBar — 2D hue × value picker with circle cursor
// =============================================================================
class GradientColorPickerBar extends StatelessWidget {
  final double hue;   // 0-360
  final double value; // 0-1
  final void Function(double hue, double value) onChanged;
  const GradientColorPickerBar({
    super.key,
    required this.hue,
    required this.value,
    required this.onChanged,
  });

  void _handle(Offset local, Size size) {
    final h = (local.dx / size.width * 360).clamp(0.0, 360.0);
    final v = (1 - local.dy / size.height).clamp(0.0, 1.0);
    onChanged(h, v);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (_, c) {
          final sz = Size(c.maxWidth, 150.0);
          return GestureDetector(
            onPanUpdate: (d) => _handle(d.localPosition, sz),
            onTapDown:   (d) => _handle(d.localPosition, sz),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CustomPaint(
                size: sz,
                painter: _PickerPainter(hue: hue, value: value),
              ),
            ),
          );
        },
      );
}

class _PickerPainter extends CustomPainter {
  final double hue, value;
  const _PickerPainter({required this.hue, required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // ── Hue rainbow (horizontal) ─────────────────────────────────────────
    canvas.drawRect(rect, Paint()
      ..shader = const LinearGradient(colors: [
        Color(0xFFFF0000), Color(0xFFFFFF00), Color(0xFF00FF00),
        Color(0xFF00FFFF), Color(0xFF0000FF), Color(0xFFFF00FF),
        Color(0xFFFF0000),
      ]).createShader(rect));

    // ── Value overlay: transparent → black (top → bottom) ────────────────
    canvas.drawRect(rect, Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end:   Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.black],
      ).createShader(rect));

    // ── Cursor ────────────────────────────────────────────────────────────
    final cx  = hue / 360 * size.width;
    final cy  = (1 - value) * size.height;
    final off = Offset(cx, cy);

    // Shadow ring
    canvas.drawCircle(off, 12,
        Paint()..color = Colors.black38..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    // White ring
    canvas.drawCircle(off, 11,
        Paint()..color = Colors.white..style = PaintingStyle.stroke
            ..strokeWidth = 2.5);
    // Inner colour dot
    canvas.drawCircle(off, 6,
        Paint()..color = HSVColor.fromAHSV(1, hue, 1, value).toColor());
  }

  @override
  bool shouldRepaint(_PickerPainter old) =>
      old.hue != hue || old.value != value;
}

// =============================================================================
//  SentioSlider — cyan-themed slider with phosphor icon endpoints
// =============================================================================
class SentioSlider extends StatelessWidget {
  final double             value;
  final PhosphorIconData   minIcon, maxIcon;
  final double             minSize, maxSize;
  final ValueChanged<double> onChanged;
  const SentioSlider({
    super.key,
    required this.value,
    required this.minIcon,
    required this.maxIcon,
    required this.minSize,
    required this.maxSize,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(minIcon, color: _kMuted, size: minSize),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor:   _kCyan,
              inactiveTrackColor: _kBorder,
              thumbColor:         _kCyan,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
              overlayColor: _kCyan.withOpacity(.12),
              trackHeight: 3.5,
            ),
            child: Slider(value: value, onChanged: onChanged),
          ),
        ),
        Icon(maxIcon, color: Colors.white70, size: maxSize),
      ]);
}

// =============================================================================
//  PalettePreviewCard — 5×5 LED grid thumbnail + name label
// =============================================================================
class PalettePreviewCard extends StatelessWidget {
  final String       name;
  final bool         isSelected;
  final VoidCallback onTap;
  const PalettePreviewCard({
    super.key,
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: const Color(0xFF060E18),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? _kCyan : _kBorder,
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [BoxShadow(color: _kCyan.withOpacity(.2),
                    blurRadius: 8, spreadRadius: 1)]
                : null,
          ),
          child: Column(children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(5, 5, 5, 2),
                child: CustomPaint(
                  painter: _PalettePainter(name: name),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(name,
                style: _pp(
                  size: 9, weight: FontWeight.w500,
                  color: isSelected ? _kCyan : Colors.white,
                )),
            ),
          ]),
        ),
      );
}

class _PalettePainter extends CustomPainter {
  final String name;
  const _PalettePainter({required this.name});

  @override
  void paint(Canvas canvas, Size size) {
    const n    = 5;
    final cellW = size.width  / n;
    final cellH = size.height / n;
    final dotR  = math.min(cellW, cellH) * .28;

    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        final cx    = (c + .5) * cellW;
        final cy    = (r + .5) * cellH;
        final color = _paletteColor(name, r, c);
        final off   = Offset(cx, cy);

        canvas.drawCircle(off, dotR * 1.8,
            Paint()..color = color.withOpacity(.25));
        canvas.drawCircle(off, dotR,
            Paint()..color = color);
      }
    }
  }

  @override
  bool shouldRepaint(_PalettePainter old) => old.name != name;
}

// =============================================================================
//  RainbowDirectionCard — small LED preview + arrow + label
// =============================================================================
class RainbowDirectionCard extends StatelessWidget {
  final String       direction;
  final bool         isSelected;
  final VoidCallback onTap;
  const RainbowDirectionCard({
    super.key,
    required this.direction,
    required this.isSelected,
    required this.onTap,
  });

  PhosphorIconData _arrowIcon() => switch (direction) {
    'Left to Right' => PhosphorIcons.arrowRight(),
    'Right to Left' => PhosphorIcons.arrowLeft(),
    'Top to Bottom' => PhosphorIcons.arrowDown(),
    'Bottom to Top' => PhosphorIcons.arrowUp(),
    _               => PhosphorIcons.arrowRight(),
  };

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF060E18),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? _kCyan : _kBorder,
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [BoxShadow(color: _kCyan.withOpacity(.18),
                    blurRadius: 8, spreadRadius: 1)]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // LED dot preview
              AspectRatio(
                aspectRatio: 1,
                child: CustomPaint(
                  painter: _DirPainter(direction: direction),
                ),
              ),
              const SizedBox(height: 5),
              // Arrow icon
              Icon(_arrowIcon(),
                  color: isSelected ? _kCyan : _kMuted, size: 14),
              const SizedBox(height: 3),
              // Label
              Text(
                _shortLabel(direction),
                textAlign: TextAlign.center,
                maxLines: 2,
                style: _pp(
                  size: 8.5, weight: FontWeight.w500,
                  color: isSelected ? _kCyan : Colors.white,
                ),
              ),
            ],
          ),
        ),
      );

  String _shortLabel(String dir) => switch (dir) {
    'Left to Right' => 'Left to\nRight',
    'Right to Left' => 'Right to\nLeft',
    'Top to Bottom' => 'Top to\nBottom',
    'Bottom to Top' => 'Bottom\nto Top',
    _               => dir,
  };
}

class _DirPainter extends CustomPainter {
  final String direction;
  const _DirPainter({required this.direction});

  @override
  void paint(Canvas canvas, Size size) {
    const rows = 4, cols = 4;
    final cw   = size.width  / cols;
    final ch   = size.height / rows;
    final dotR = math.min(cw, ch) * .3;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final cx    = (c + .5) * cw;
        final cy    = (r + .5) * ch;
        final color = _rainbowDirColor(direction, r, c, rows, cols);
        final off   = Offset(cx, cy);

        canvas.drawCircle(off, dotR * 1.6,
            Paint()..color = color.withOpacity(.22));
        canvas.drawCircle(off, dotR,
            Paint()..color = color);
      }
    }
  }

  @override
  bool shouldRepaint(_DirPainter old) => old.direction != direction;
}
