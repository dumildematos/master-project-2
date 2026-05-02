// dashboard_screen.dart — SENTIO Dashboard
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../providers/ble_provider.dart';
import '../providers/sentio_provider.dart';
import '../providers/session_provider.dart';
import 'connect_device_screen.dart';
import 'history_screen.dart';
import 'led_display_screen.dart';
import 'session_pattern_preview_screen.dart';
import 'session_screen.dart';
import 'settings_screen.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kBg       = Color(0xFF02080D);
const _kBgEnd    = Color(0xFF07131B);
const _kCard     = Color(0xFF0E1822);
const _kStateBg  = Color(0xFF050C16); // darker background for state card
const _kBorder   = Color(0xFF182030);
const _kCyan     = Color(0xFF00D9FF);
const _kGreen    = Color(0xFF43F26B);
const _kBlue     = Color(0xFF3A86FF);
const _kMagenta  = Color(0xFFCC44FF);
const _kMuted    = Color(0xFF9AA6B2);

// ── Helpers ───────────────────────────────────────────────────────────────────
String _fmtSeconds(int secs) {
  final h = secs ~/ 3600;
  final m = (secs % 3600) ~/ 60;
  if (h > 0) return '${h}h ${m}m';
  if (m > 0) return '${m}m';
  return '0m';
}

String _emotionLabel(String e) => switch (e.toLowerCase()) {
  'calm'     => 'Calm',
  'relaxed'  => 'Relaxed',
  'focused'  => 'Focused',
  'excited'  => 'Excited',
  'stressed' => 'Stressed',
  _          => e.isEmpty ? 'Calm'
                : '${e[0].toUpperCase()}${e.substring(1).toLowerCase()}',
};

Color _emotionColor(String e) => switch (e.toLowerCase()) {
  'calm'     => _kCyan,
  'relaxed'  => const Color(0xFF52D68A),
  'focused'  => _kBlue,
  'excited'  => const Color(0xFFFF6BCB),
  'stressed' => const Color(0xFFFF5252),
  _          => _kCyan,
};

TextStyle _pp({
  double size = 14,
  FontWeight weight = FontWeight.normal,
  Color color = Colors.white,
  double? height,
  double? spacing,
}) => GoogleFonts.poppins(
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
  letterSpacing: spacing,
);

// ══════════════════════════════════════════════════════════════════════════════
// DashboardScreen
// ══════════════════════════════════════════════════════════════════════════════
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SessionProvider>().fetchDashboardSummary();
    });
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    final ble     = context.watch<BleProvider>();
    final sentio  = context.watch<SentioProvider>();
    final session = context.watch<SessionProvider>();
    final isConn  = ble.state == BLEState.connected;
    final emotion = sentio.data.emotion.toLowerCase();

    final dash = session.dashboardSummary;
    final focusTime  = dash != null ? _fmtSeconds(dash.focusTimeToday) : '—';
    final topState   = _emotionLabel(dash?.topStateToday ?? (sentio.emotionHistory.isEmpty ? 'focused' : _topEmotion(sentio.emotionHistory)));
    final sessionCnt = dash != null ? '${dash.sessionsToday}' : '—';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_kBg, _kBgEnd],
        ),
      ),
      child: SafeArea(
        child: Column(children: [
          // ── App bar ──────────────────────────────────────────────────
          _DashAppBar(onSettings: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),

          // ── Scrollable content ────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(children: [

                // ① Device Connection card
                DeviceCard(
                  museConnected: isConn,
                  museName: ble.connectedDevice?.name ?? 'Muse 2',
                  museBattery: ble.museBattery,
                  hatConnected: ble.isHatConnected,
                  hatName: ble.connectedHat?.platformName ?? 'SENTIO Hat',
                  hatBattery: ble.hatBattery,
                ),
                const SizedBox(height: 16),

                // ② Current State card
                CurrentStateCard(emotion: emotion),
                const SizedBox(height: 16),

                // ③ Today's Summary card
                SummaryCard(
                  focusTime: focusTime,
                  topState:  topState,
                  sessions:  sessionCnt,
                ),
                const SizedBox(height: 16),

                // ④ Quick Actions card
                _QuickActionsCard(context: context),
                const SizedBox(height: 8),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  static String _topEmotion(List<dynamic> h) {
    if (h.isEmpty) return 'focused';
    final counts = <String, int>{};
    for (final e in h) {
      final k = (e.emotion as String).toLowerCase();
      counts[k] = (counts[k] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// App bar
// ══════════════════════════════════════════════════════════════════════════════
class _DashAppBar extends StatelessWidget {
  final VoidCallback onSettings;
  const _DashAppBar({required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(children: [
        GestureDetector(
          onTap: () {},
          child: Icon(PhosphorIcons.list(), color: Colors.white, size: 26),
        ),
        Expanded(
          child: Text(
            'Dashboard',
            textAlign: TextAlign.center,
            style: _pp(size: 18, weight: FontWeight.w700),
          ),
        ),
        GestureDetector(
          onTap: onSettings,
          child: Icon(PhosphorIcons.gear(), color: Colors.white, size: 26),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// GlassCard — reusable dark rounded card
// ══════════════════════════════════════════════════════════════════════════════
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding ?? const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: color ?? _kCard,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: _kBorder, width: 1),
    ),
    child: child,
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// DeviceCard — shows only connected devices; empty state if none
// ══════════════════════════════════════════════════════════════════════════════
class DeviceCard extends StatelessWidget {
  final bool    museConnected;
  final String  museName;
  final int?    museBattery;
  final bool    hatConnected;
  final String  hatName;
  final int?    hatBattery;

  const DeviceCard({
    super.key,
    required this.museConnected,
    required this.museName,
    required this.museBattery,
    required this.hatConnected,
    required this.hatName,
    required this.hatBattery,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    if (museConnected) {
      rows.add(ConnectedDeviceRow(
        image: const _MuseThumb(),
        name: museName,
        type: 'EEG Headband',
        battery: museBattery,
      ));
    }

    if (hatConnected) {
      if (rows.isNotEmpty) {
        rows.add(const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Divider(color: _kBorder, height: 1, thickness: 1),
        ));
      }
      rows.add(ConnectedDeviceRow(
        image: const _HatThumb(),
        name: hatName,
        type: 'Smart LED Hat',
        battery: hatBattery,
      ));
    }

    if (rows.isEmpty) {
      return _DeviceEmptyState();
    }

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(children: rows),
    );
  }
}

// ── Connected device row (always green — only rendered when connected) ─────────
class ConnectedDeviceRow extends StatelessWidget {
  final Widget image;
  final String name;
  final String type;
  final int?   battery;

  const ConnectedDeviceRow({
    super.key,
    required this.image,
    required this.name,
    required this.type,
    this.battery,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(width: 72, height: 54, child: image),
      ),
      const SizedBox(width: 14),

      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: _pp(size: 15, weight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(type, style: _pp(size: 11, color: _kMuted)),
          const SizedBox(height: 4),
          Row(children: [
            Container(
              width: 7, height: 7,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _kGreen,
              ),
            ),
            const SizedBox(width: 5),
            Text('Connected',
                style: _pp(size: 12, color: _kGreen, weight: FontWeight.w500)),
          ]),
        ],
      )),

      if (battery != null)
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text('$battery%',
              style: _pp(size: 13, color: Colors.white, weight: FontWeight.w500)),
          const SizedBox(width: 6),
          SizedBox(
            width: 28, height: 14,
            child: CustomPaint(painter: _BatPainter(pct: battery!)),
          ),
        ]),
    ]);
  }
}

// ── Empty state — shown when no devices are connected ─────────────────────────
class _DeviceEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kCyan.withValues(alpha: 0.08),
              border: Border.all(color: _kCyan.withValues(alpha: 0.20)),
            ),
            child: Icon(PhosphorIcons.bluetoothSlash(),
                color: _kMuted, size: 26),
          ),
          const SizedBox(height: 14),
          Text('No devices connected',
              style: _pp(size: 15, weight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            'Connect your Muse 2 and SENTIO Hat to begin.',
            textAlign: TextAlign.center,
            style: _pp(size: 12, color: _kMuted),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ConnectDeviceScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: _kCyan.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kCyan.withValues(alpha: 0.40)),
              ),
              child: Text('Connect Device',
                  style: _pp(
                      size: 13,
                      color: _kCyan,
                      weight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CurrentStateCard — glowing circle + particle background
// ══════════════════════════════════════════════════════════════════════════════
class CurrentStateCard extends StatelessWidget {
  final String emotion;
  const CurrentStateCard({super.key, required this.emotion});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _kStateBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kBorder, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(alignment: Alignment.center, children: [
          // Particle wave background
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: _StateBgPainter()),
            ),
          ),
          // Glowing state circle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            child: CurrentStateCircle(emotion: emotion),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CurrentStateCircle — lotus + emotion + tagline inside glowing ring
// ══════════════════════════════════════════════════════════════════════════════
class CurrentStateCircle extends StatelessWidget {
  final String emotion;
  const CurrentStateCircle({super.key, required this.emotion});

  @override
  Widget build(BuildContext context) {
    final w   = MediaQuery.of(context).size.width;
    final sz  = (w - 100).clamp(180.0, 230.0);
    final col = _emotionColor(emotion);

    return Container(
      width: sz, height: sz,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF040B14),
        border: Border.all(color: col, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: col.withValues(alpha: 0.80),
            blurRadius: 12,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: col.withValues(alpha: 0.40),
            blurRadius: 32,
            spreadRadius: 8,
          ),
          BoxShadow(
            color: col.withValues(alpha: 0.15),
            blurRadius: 64,
            spreadRadius: 20,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Lotus icon
          SizedBox(
            width: sz * 0.34,
            height: sz * 0.34,
            child: CustomPaint(painter: _LotusPainter(color: col)),
          ),
          SizedBox(height: sz * 0.04),

          // Emotion label
          Text(
            _emotionLabel(emotion),
            style: _pp(
              size: sz * 0.120,
              weight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          SizedBox(height: sz * 0.02),

          // "Wear your mind."
          Text(
            'Wear your mind.',
            style: _pp(
              size: sz * 0.065,
              color: _kMuted,
              weight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

// For backwards-compatibility alias
typedef StatusCircle = CurrentStateCircle;

// ══════════════════════════════════════════════════════════════════════════════
// SummaryCard — Focus Time / Top State / Sessions with colored icons
// ══════════════════════════════════════════════════════════════════════════════
class SummaryCard extends StatelessWidget {
  final String focusTime;
  final String topState;
  final String sessions;

  const SummaryCard({
    super.key,
    required this.focusTime,
    required this.topState,
    required this.sessions,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Today's Summary", style: _pp(size: 16, weight: FontWeight.w600)),
          const SizedBox(height: 18),
          IntrinsicHeight(
            child: Row(children: [
              Expanded(child: _StatCol(
                icon: PhosphorIcons.clock(),
                iconColor: _kBlue,
                label: 'Focus Time',
                value: focusTime,
              )),
              _VDivider(),
              Expanded(child: _StatCol(
                icon: PhosphorIcons.crosshair(),
                iconColor: _kGreen,
                label: 'Top State',
                value: topState,
              )),
              _VDivider(),
              Expanded(child: _StatCol(
                icon: PhosphorIcons.chartBar(),
                iconColor: _kMagenta,
                label: 'Sessions',
                value: sessions,
              )),
            ]),
          ),
        ],
      ),
    );
  }
}

class _StatCol extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final String   label;
  final String   value;

  const _StatCol({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // Icon in a circular container
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: iconColor.withValues(alpha: 0.12),
          border: Border.all(color: iconColor.withValues(alpha: 0.35), width: 1.5),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      const SizedBox(height: 10),
      Text(
        label,
        textAlign: TextAlign.center,
        style: _pp(size: 11.5, color: _kMuted),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        textAlign: TextAlign.center,
        style: _pp(size: 17, weight: FontWeight.w700),
      ),
    ],
  );
}

class _VDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    color: _kBorder,
    margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// Quick Actions card
// ══════════════════════════════════════════════════════════════════════════════
class _QuickActionsCard extends StatelessWidget {
  final BuildContext context;
  const _QuickActionsCard({required this.context});

  Future<void> _handleStartSession() async {
    final ble      = context.read<BleProvider>();
    final session  = context.read<SessionProvider>();

    if (ble.state != BLEState.connected) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _kCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('No Device Connected',
              style: _pp(size: 17, weight: FontWeight.w600)),
          content: Text(
            'Connect your Muse 2 headband before starting a session.',
            style: _pp(size: 13, color: _kMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: _pp(size: 14, color: _kMuted)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ConnectDeviceScreen()));
              },
              child: Text('Connect',
                  style: _pp(size: 14, color: _kCyan, weight: FontWeight.w600)),
            ),
          ],
        ),
      );
      return;
    }

    if (session.hasActiveSession) {
      final endAndStart = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _kCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Session Already Running',
              style: _pp(size: 17, weight: FontWeight.w600)),
          content: Text(
            'A session is already active. End it and start a new one?',
            style: _pp(size: 13, color: _kMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: _pp(size: 14, color: _kMuted)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('End & Start New',
                  style: _pp(size: 14, color: _kCyan, weight: FontWeight.w600)),
            ),
          ],
        ),
      );
      if (endAndStart != true) return;
      try { await session.stopSession(); } catch (_) {}
    }

    if (!context.mounted) return;
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const SessionScreen()));
  }

  @override
  Widget build(BuildContext ctx) {
    final hasSession = ctx.watch<SessionProvider>().hasActiveSession;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Actions', style: _pp(size: 16, weight: FontWeight.w600)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              QuickActionItem(
                icon: Icon(PhosphorIcons.play(), color: _kCyan, size: 26),
                label: 'Start\nSession',
                accent: _kCyan,
                onTap: _handleStartSession,
              ),
              QuickActionItem(
                icon: Icon(PhosphorIcons.dotsSixVertical(), color: _kMagenta, size: 26),
                label: 'LED\nDisplay',
                accent: _kMagenta,
                onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const LedDisplayScreen())),
              ),
              QuickActionItem(
                icon: Icon(PhosphorIcons.clockCounterClockwise(), color: _kBlue, size: 26),
                label: 'History',
                accent: _kBlue,
                onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const HistoryScreen())),
              ),
              QuickActionItem(
                icon: Icon(PhosphorIcons.waveform(),
                    color: hasSession ? _kCyan : _kMuted, size: 26),
                label: 'Session\nPattern',
                accent: hasSession ? _kCyan : _kMuted,
                enabled: hasSession,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SessionPatternPreviewScreen())),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// QuickActionItem — icon in a glowing box + label
// ══════════════════════════════════════════════════════════════════════════════
class QuickActionItem extends StatefulWidget {
  final Widget icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;
  final bool enabled;

  const QuickActionItem({
    super.key,
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
    this.enabled = true,
  });

  @override
  State<QuickActionItem> createState() => _QuickActionItemState();
}

class _QuickActionItemState extends State<QuickActionItem> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   widget.enabled ? (_) => setState(() => _down = true) : null,
      onTapUp:     widget.enabled ? (_) { setState(() => _down = false); widget.onTap(); } : null,
      onTapCancel: widget.enabled ? ()  => setState(() => _down = false) : null,
      child: AnimatedOpacity(
        opacity: !widget.enabled ? 0.38 : (_down ? 0.65 : 1.0),
        duration: const Duration(milliseconds: 80),
        child: Column(children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: widget.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.accent.withValues(alpha: 0.28),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.accent.withValues(alpha: 0.15),
                  blurRadius: 12,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Center(child: widget.icon),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 72,
            child: Text(
              widget.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: _pp(size: 11.5, color: Colors.white70, height: 1.3),
            ),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Custom painters
// ══════════════════════════════════════════════════════════════════════════════

// ── Lotus flower (stroke outline) ─────────────────────────────────────────────
class _LotusPainter extends CustomPainter {
  final Color color;
  const _LotusPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final sw = size.width * 0.055;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width, h = size.height;
    final cx = w / 2, cy = h * 0.60;

    void petal(double bx, double by, double tilt, double pw, double ph) {
      final c = math.cos(tilt), s = math.sin(tilt);
      final tx = bx - ph * s, ty = by - ph * c;
      final path = Path()
        ..moveTo(bx, by)
        ..cubicTo(bx - ph * 0.30 * s - pw * c, by - ph * 0.30 * c + pw * s,
            tx - pw * 0.50 * c, ty + pw * 0.50 * s, tx, ty)
        ..cubicTo(tx + pw * 0.50 * c, ty - pw * 0.50 * s,
            bx - ph * 0.30 * s + pw * c, by - ph * 0.30 * c - pw * s, bx, by);
      canvas.drawPath(path, p);
    }

    petal(cx, cy, 0, w * 0.145, h * 0.48);
    petal(cx - w * 0.04, cy - h * 0.03, -0.48, w * 0.120, h * 0.38);
    petal(cx + w * 0.04, cy - h * 0.03,  0.48, w * 0.120, h * 0.38);
    petal(cx - w * 0.08, cy - h * 0.01, -0.95, w * 0.090, h * 0.28);
    petal(cx + w * 0.08, cy - h * 0.01,  0.95, w * 0.090, h * 0.28);

    final base = Path()
      ..moveTo(cx - w * 0.35, cy + h * 0.05)
      ..cubicTo(cx - w * 0.10, cy + h * 0.14,
          cx + w * 0.10, cy + h * 0.14,
          cx + w * 0.35, cy + h * 0.05);
    canvas.drawPath(base, p..strokeWidth = sw * 0.8);
  }

  @override
  bool shouldRepaint(_LotusPainter o) => o.color != color;
}

class _MuseThumb extends StatelessWidget {
  const _MuseThumb();

  @override
  Widget build(BuildContext context) {
    // Try loading the real PNG, fall back to a stylised icon
    return Image.asset(
      'assets/images/muse.png',
      width: 72,
      height: 54,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => SizedBox(
        width: 72, height: 54,
        child: Center(
          child: Icon(
            PhosphorIcons.headphones(),
            color: _kMuted,
            size: 32,
          ),
        ),
      ),
    );
  }
}

// ── SENTIO Hat thumbnail (simplified for device row) ──────────────────────────
class _HatThumb extends StatelessWidget {
  const _HatThumb();

  @override
  Widget build(BuildContext context) {
    // Try loading the real PNG, fall back to a stylised icon
    return Image.asset(
      'assets/images/sentio-hat.png',
      width: 72,
      height: 54,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => SizedBox(
        width: 72, height: 54,
        child: Center(
          child: Icon(
            PhosphorIcons.hardHat(),
            color: _kCyan,
            size: 32,
          ),
        ),
      ),
    );
  }
}

// ── Green battery indicator ────────────────────────────────────────────────────
class _BatPainter extends CustomPainter {
  final int pct;
  const _BatPainter({required this.pct});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final borderPaint = Paint()
      ..color = const Color(0xFF4A5568)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Shell
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, w * 0.88, h),
        const Radius.circular(3)),
      borderPaint,
    );

    // Terminal nub
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.90, h * 0.28, w * 0.10, h * 0.44),
        const Radius.circular(2)),
      Paint()..color = const Color(0xFF4A5568),
    );

    // Green fill
    final fillW = ((w * 0.88) - 3.0) * pct / 100;
    if (fillW > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(1.5, 1.5, fillW, h - 3),
          const Radius.circular(2)),
        Paint()..color = _kGreen,
      );
    }
  }

  @override
  bool shouldRepaint(_BatPainter o) => o.pct != pct;
}

// ── State card particle background ────────────────────────────────────────────
class _StateBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(7);
    final w = size.width, h = size.height;

    // Left cyan stream
    _particles(canvas, rng, w, h,
      col: _kCyan,
      x0: -0.05, y0: 0.95, x1: 0.45, y1: 0.05,
      count: 90, spread: 0.18);

    // Right purple stream
    _particles(canvas, rng, w, h,
      col: _kMagenta,
      x0: 1.05, y0: 0.05, x1: 0.55, y1: 0.95,
      count: 70, spread: 0.16);
  }

  void _particles(
    Canvas canvas,
    math.Random rng,
    double w, double h, {
    required Color col,
    required double x0, required double y0,
    required double x1, required double y1,
    required int count,
    required double spread,
  }) {
    final dx = x1 - x0, dy = y1 - y0;
    final len = math.sqrt(dx * dx + dy * dy) + 1e-9;
    final nx = -dy / len, ny = dx / len;
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < count; i++) {
      final t   = rng.nextDouble();
      final bx  = (x0 + t * dx) * w;
      final by  = (y0 + t * dy) * h;
      final off = (rng.nextDouble() - 0.5) * spread;
      final px  = bx + nx * off * w;
      final py  = by + ny * off * h;
      final prx = (1 - off.abs() / (spread * 0.5)).clamp(0.35, 1.0);
      final r   = 0.5 + rng.nextDouble() * 2.0 * prx;
      final opa = (0.08 + rng.nextDouble() * 0.50 * prx).clamp(0.0, 0.65);

      // Glow
      paint.color = col.withValues(alpha: opa * 0.3);
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(Offset(px, py), r * 2.2, paint);

      // Core
      paint.maskFilter = null;
      paint.color = col.withValues(alpha: opa);
      canvas.drawCircle(Offset(px, py), r, paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
