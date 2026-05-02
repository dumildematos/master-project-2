import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../models/session_led_pattern.dart';
import '../providers/ble_provider.dart';
import '../providers/session_provider.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kBg       = Color(0xFF02080D);
const _kCard     = Color(0xFF0E1822);
const _kBorder   = Color(0xFF182030);
const _kTextPri  = Color(0xFFFFFFFF);
const _kTextSec  = Color(0xFF9AA6B2);
const _kCyan     = Color(0xFF00D9FF);

class SessionPatternPreviewScreen extends StatefulWidget {
  const SessionPatternPreviewScreen({super.key});

  @override
  State<SessionPatternPreviewScreen> createState() =>
      _SessionPatternPreviewScreenState();
}

class _SessionPatternPreviewScreenState
    extends State<SessionPatternPreviewScreen> {
  bool _refreshing = false;
  bool _sending    = false;

  TextStyle _pp({
    double size = 14,
    FontWeight weight = FontWeight.normal,
    Color color = _kTextPri,
    double height = 1.4,
  }) =>
      GoogleFonts.poppins(
          fontSize: size, fontWeight: weight, color: color, height: height);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await context.read<SessionProvider>().fetchLatestPattern();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _previewOnHat() async {
    if (_sending) return;
    final pattern = context.read<SessionProvider>().latestPattern;
    final ble     = context.read<BleProvider>();

    if (!ble.isHatConnected) {
      _showSnack('SENTIO Hat not connected', isError: true);
      return;
    }
    if (pattern == null) {
      _showSnack('No pattern available', isError: true);
      return;
    }

    setState(() => _sending = true);
    try {
      await ble.sendHatPayload(jsonEncode(pattern.toJson()));
      _showSnack('Pattern sent to hat');
    } catch (e) {
      _showSnack('Failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: _pp(size: 13)),
      backgroundColor: isError ? const Color(0xFFFF3B4A) : const Color(0xFF00C48C),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Color _hexColor(String hex) {
    final s = hex.replaceFirst('#', '');
    return Color(int.parse('FF$s', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final pattern = context.watch<SessionProvider>().latestPattern;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _kTextPri, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Session Pattern',
            style: _pp(size: 17, weight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: _refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _kCyan))
                : Icon(PhosphorIcons.arrowClockwise(), color: _kCyan, size: 22),
            onPressed: _refreshing ? null : _refresh,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: pattern == null
          ? _buildEmpty()
          : _buildContent(pattern),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIcons.waveform(), color: _kTextSec, size: 48),
            const SizedBox(height: 16),
            Text('No pattern yet',
                style: _pp(size: 16, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Start a session to generate a pattern.',
                style: _pp(size: 13, color: _kTextSec)),
          ],
        ),
      );

  Widget _buildContent(SessionLedPattern p) {
    final primary   = _hexColor(p.primaryColor);
    final secondary = _hexColor(p.secondaryColor);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Emotion header
          _EmotionHeader(
            emotion:    p.emotion,
            modeName:   p.modeName,
            confidence: p.confidence,
            primary:    primary,
            secondary:  secondary,
            pp:         _pp,
          ),
          const SizedBox(height: 24),
          // 8×8 LED Grid
          _LedGrid(grid: p.grid, primary: primary, secondary: secondary),
          const SizedBox(height: 24),
          // Stats row
          _StatsRow(brightness: p.brightness, speed: p.speed, pp: _pp),
          const SizedBox(height: 32),
          // Preview button
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _sending ? null : _previewOnHat,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _sending
                        ? [_kCard, _kCard]
                        : [primary, secondary],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: primary.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: _sending
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: _kCyan))
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(PhosphorIcons.lightbulb(),
                                color: _kTextPri, size: 20),
                            const SizedBox(width: 8),
                            Text('Preview on Hat',
                                style: _pp(
                                    size: 15, weight: FontWeight.w600)),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Emotion header ─────────────────────────────────────────────────────────────
class _EmotionHeader extends StatelessWidget {
  final String emotion;
  final String modeName;
  final int confidence;
  final Color primary;
  final Color secondary;
  final TextStyle Function({double size, FontWeight weight, Color color, double height}) pp;

  const _EmotionHeader({
    required this.emotion,
    required this.modeName,
    required this.confidence,
    required this.primary,
    required this.secondary,
    required this.pp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primary.withValues(alpha: 0.3)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primary.withValues(alpha: 0.08),
            secondary.withValues(alpha: 0.04),
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [primary, secondary]),
            ),
            child: Center(
              child: Text(
                _emotionEmoji(emotion),
                style: const TextStyle(fontSize: 26),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  emotion[0].toUpperCase() + emotion.substring(1),
                  style: pp(size: 22, weight: FontWeight.w700),
                ),
                Text(modeName,
                    style: pp(size: 13, color: primary, weight: FontWeight.w500)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$confidence%',
                  style: pp(size: 24, weight: FontWeight.w700, color: primary)),
              Text('confidence',
                  style: pp(size: 11, color: _kTextSec)),
            ],
          ),
        ],
      ),
    );
  }

  String _emotionEmoji(String e) => switch (e.toLowerCase()) {
    'calm'     => '🌊',
    'focused'  => '🎯',
    'stressed' => '⚡',
    'relaxed'  => '🌸',
    'excited'  => '✨',
    _          => '🧠',
  };
}

// ── 8×8 LED grid ──────────────────────────────────────────────────────────────
class _LedGrid extends StatelessWidget {
  final List<List<int>> grid;
  final Color primary;
  final Color secondary;

  const _LedGrid({
    required this.grid,
    required this.primary,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder),
      ),
      child: AspectRatio(
        aspectRatio: 1,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 8,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: 64,
          itemBuilder: (_, i) {
            final row = i ~/ 8;
            final col = i  % 8;
            final on  = row < grid.length &&
                col < grid[row].length &&
                grid[row][col] == 1;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: on ? primary : primary.withValues(alpha: 0.08),
                boxShadow: on
                    ? [BoxShadow(
                        color: primary.withValues(alpha: 0.6),
                        blurRadius: 6,
                        spreadRadius: -1,
                      )]
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final int brightness;
  final int speed;
  final TextStyle Function({double size, FontWeight weight, Color color, double height}) pp;

  const _StatsRow({
    required this.brightness,
    required this.speed,
    required this.pp,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatCard(
          icon: PhosphorIcons.sun(),
          label: 'Brightness',
          value: '$brightness%',
          pp: pp,
        )),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(
          icon: PhosphorIcons.timer(),
          label: 'Speed',
          value: '$speed%',
          pp: pp,
        )),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final TextStyle Function({double size, FontWeight weight, Color color, double height}) pp;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.pp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: _kCyan, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: pp(size: 11, color: _kTextSec)),
              Text(value,
                  style: pp(size: 18, weight: FontWeight.w700, color: _kTextPri)),
            ],
          ),
        ],
      ),
    );
  }
}
