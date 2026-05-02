import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../models/sentio_state.dart';
import '../providers/ai_provider.dart';
import '../providers/sentio_provider.dart';
import '../providers/session_provider.dart';
import '../services/sentio_api.dart' as api;
import '../theme/theme.dart';

// ── Screen-local design tokens ─────────────────────────────────────────────────
const _kBgTop      = Color(0xFF02080D);
const _kBgBottom   = Color(0xFF07131B);
const _kCardBg     = Color(0xFF101820);
const _kCardBorder = Color(0xFF1E2A33);
const _kAccentCyan = Color(0xFF00D9FF);
const _kAccentPurp = Color(0xFF8A3FFC);
const _kAccentRed  = Color(0xFFFF3B4A);
const _kAccentYell = Color(0xFFFFC107);
const _kAccentGrn  = Color(0xFF00C48C);
const _kTextPri    = Color(0xFFFFFFFF);
const _kTextSec    = Color(0xFF9AA6B2);
const _kCardRadius = 24.0;

// ── Root screen ────────────────────────────────────────────────────────────────
class SessionScreen extends StatefulWidget {
  final String? title;
  const SessionScreen({super.key, this.title});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  bool _running = true;
  int  _seconds = 0;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _startSession();
    _tick();
  }

  void _tick() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      if (_running) setState(() => _seconds++);
      _tick();
    });
  }

  Future<void> _startSession() async {
    final provider = context.read<SessionProvider>();
    try {
      await api.startSession(const api.SessionConfig(
        patternType:       'fluid',
        signalSensitivity: 0.5,
        emotionSmoothing:  0.5,
        deviceSource:      'mobile',
      ));
    } catch (_) {}
    try {
      await provider.startSession(widget.title);
    } catch (_) {}
  }

  Future<void> _endSession() async {
    final confirmed = await _showStopDialog();
    if (!confirmed) return;
    await _doStop();
  }

  Future<void> _doStop() async {
    setState(() => _running = false);
    final provider = context.read<SessionProvider>();
    try { await api.stopSession(); } catch (_) {}
    Map<String, dynamic>? summary;
    try { summary = await provider.stopSession(); } catch (_) {}
    if (!mounted) return;
    if (summary != null) {
      _showSummaryDialog(summary);
    } else {
      Navigator.pop(context);
    }
  }

  Future<bool> _showStopDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: _kCardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Stop this session?',
                style: GoogleFonts.poppins(
                    color: _kTextPri, fontSize: 17, fontWeight: FontWeight.w600)),
            content: Text('Your session data will be saved.',
                style: GoogleFonts.poppins(color: _kTextSec, fontSize: 14)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel',
                    style: GoogleFonts.poppins(color: _kTextSec, fontSize: 14)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Stop',
                    style: GoogleFonts.poppins(
                        color: _kAccentYell, fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSummaryDialog(Map<String, dynamic> summary) {
    final dur = summary['duration_seconds'] as int? ?? 0;
    final h = dur ~/ 3600;
    final m = (dur % 3600) ~/ 60;
    final timeStr = h > 0 ? '${h}h ${m}m' : '${m}m';
    final state = (summary['dominant_state'] as String? ?? 'neutral');
    final conf  = ((summary['average_confidence'] as num? ?? 0) * 100).round();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Session Complete',
            style: GoogleFonts.poppins(
                color: _kTextPri, fontSize: 17, fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SummaryRow('Duration',    timeStr),
            _SummaryRow('Top State',   '${state[0].toUpperCase()}${state.substring(1)}'),
            _SummaryRow('Confidence',  '$conf%'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text('Done',
                style: GoogleFonts.poppins(
                    color: _kAccentCyan, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _togglePause() => setState(() => _running = !_running);

  String get _timerStr {
    final m = _seconds ~/ 60;
    final s = _seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sentio       = context.watch<SentioProvider>();
    final data         = sentio.data;
    final emotionHist  = sentio.emotionHistory;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_kBgTop, _kBgBottom],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(onBack: _endSession),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Column(
                    children: [
                      // 1. Current Session card
                      SessionHeaderCard(
                        timerStr:      _timerStr,
                        isRunning:     _running,
                        onPauseResume: _togglePause,
                        sessionTitle:  widget.title,
                      ),
                      const SizedBox(height: 14),

                      // 2. State Timeline chart
                      // TODO: pass real sentio.emotionHistory when EEG signal available
                      StateTimelineChart(emotionHistory: emotionHist),
                      const SizedBox(height: 14),

                      // 3. Session Average
                      SessionAverageCard(
                        emotion:    data.emotion,
                        percentage: data.confidence.round(),
                      ),
                      const SizedBox(height: 14),

                      // 3b. AI Feedback card
                      _AiFeedbackCard(sentioData: data),
                      const SizedBox(height: 14),

                      // 4. Top States breakdown
                      TopStatesCard(emotionHistory: emotionHist),
                      const SizedBox(height: 20),

                      // 5. Stop Session button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _endSession,
                          icon: Icon(PhosphorIcons.stop(), color: _kAccentYell, size: 18),
                          label: Text('Stop Session',
                              style: GoogleFonts.poppins(
                                  color: _kAccentYell,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: _kAccentYell, width: 1.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              // Fixed bottom nav
              SentioBottomNav(
                currentIndex: 1, // History tab is active during a session
                onTap: (i) { if (i != 1) _endSession(); },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Summary row used inside the stop-session result dialog ────────────────────
class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.poppins(color: _kTextSec, fontSize: 13)),
          Text(value,
              style: GoogleFonts.poppins(
                  color: _kTextPri, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── AI Feedback Card ──────────────────────────────────────────────────────────
class _AiFeedbackCard extends StatefulWidget {
  final SentioState sentioData;
  const _AiFeedbackCard({required this.sentioData});

  @override
  State<_AiFeedbackCard> createState() => _AiFeedbackCardState();
}

class _AiFeedbackCardState extends State<_AiFeedbackCard> {
  bool _confirmed = false;
  bool _corrected = false;

  static const _emotions = ['calm', 'focused', 'relaxed', 'stressed', 'excited'];

  IconData _icon(String e) {
    switch (e) {
      case 'focused':  return PhosphorIcons.crosshair();
      case 'stressed': return PhosphorIcons.atom();
      case 'excited':  return PhosphorIcons.lightning();
      default:         return PhosphorIcons.flowerLotus();
    }
  }

  Future<void> _onCorrect() async {
    final session  = context.read<SessionProvider>();
    final aiProv   = context.read<AiProvider>();
    final d        = widget.sentioData;
    await aiProv.submitFeedback(
      label:     d.emotion,
      sessionId: session.activeSessionId,
      alpha: d.alpha, beta: d.beta, theta: d.theta,
      gamma: d.gamma, delta: d.delta,
    );
    if (!mounted) return;
    setState(() { _confirmed = true; _corrected = false; });
  }

  Future<void> _onWrong() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _kCardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: _kCardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('What were you actually feeling?',
                style: GoogleFonts.poppins(
                    color: _kTextPri, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            ..._emotions.map((e) => ListTile(
                  leading: Icon(_icon(e), color: emotionColor(e), size: 22),
                  title: Text(emotionLabel(e),
                      style: GoogleFonts.poppins(color: _kTextPri, fontSize: 14)),
                  onTap: () => Navigator.pop(ctx, e),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                )),
          ],
        ),
      ),
    );

    if (picked == null || !mounted) return;

    final session = context.read<SessionProvider>();
    final aiProv  = context.read<AiProvider>();
    final d       = widget.sentioData;
    await aiProv.submitFeedback(
      label:     picked,
      sessionId: session.activeSessionId,
      alpha: d.alpha, beta: d.beta, theta: d.theta,
      gamma: d.gamma, delta: d.delta,
    );
    if (!mounted) return;
    setState(() { _confirmed = false; _corrected = true; });
  }

  @override
  void didUpdateWidget(_AiFeedbackCard old) {
    super.didUpdateWidget(old);
    // Reset feedback state when emotion changes so the user can re-label
    if (old.sentioData.emotion != widget.sentioData.emotion) {
      setState(() { _confirmed = false; _corrected = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d    = widget.sentioData;
    final col  = emotionColor(d.emotion);
    final conf = (d.confidence * 100).round();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.brain(), color: _kAccentCyan, size: 16),
              const SizedBox(width: 6),
              Text('AI Detection',
                  style: GoogleFonts.poppins(
                      color: _kTextSec, fontSize: 12)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _kAccentCyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$conf% confidence',
                    style: GoogleFonts.poppins(
                        color: _kAccentCyan, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(_icon(d.emotion), color: col, size: 22),
              const SizedBox(width: 8),
              Text(emotionLabel(d.emotion),
                  style: GoogleFonts.poppins(
                      color: _kTextPri,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 14),
          if (_confirmed)
            _StatusChip(
              icon: PhosphorIcons.checkCircle(),
              label: 'Thanks for confirming!',
              color: _kAccentGrn,
            )
          else if (_corrected)
            _StatusChip(
              icon: PhosphorIcons.checkCircle(),
              label: 'Feedback saved — model will improve',
              color: _kAccentCyan,
            )
          else
            Row(
              children: [
                Text('Is this correct?',
                    style: GoogleFonts.poppins(
                        color: _kTextSec, fontSize: 13)),
                const Spacer(),
                _FeedbackBtn(
                  icon:    PhosphorIcons.thumbsUp(),
                  color:   _kAccentGrn,
                  onTap:   _onCorrect,
                ),
                const SizedBox(width: 10),
                _FeedbackBtn(
                  icon:    PhosphorIcons.thumbsDown(),
                  color:   _kAccentRed,
                  onTap:   _onWrong,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _FeedbackBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _FeedbackBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      );
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatusChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                style: GoogleFonts.poppins(color: color, fontSize: 12)),
          ),
        ],
      );
}

// ── Top bar ────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(PhosphorIcons.arrowLeft(), color: _kTextPri, size: 22),
            onPressed: onBack,
          ),
          Expanded(
            child: Text(
              'Session',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: _kTextPri,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 48), // mirror the icon button width for centering
        ],
      ),
    );
  }
}

// ── Reusable glass card ────────────────────────────────────────────────────────
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = _kCardRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _kCardBorder),
      ),
      child: child,
    );
  }
}

// ── 1. Session Header Card ─────────────────────────────────────────────────────
class SessionHeaderCard extends StatelessWidget {
  final String timerStr;
  final bool isRunning;
  final VoidCallback onPauseResume;
  final String? sessionTitle;

  const SessionHeaderCard({
    super.key,
    required this.timerStr,
    required this.isRunning,
    required this.onPauseResume,
    this.sessionTitle,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Session',
                  style: GoogleFonts.poppins(
                    color: _kTextSec,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sessionTitle ?? 'Session',
                  style: GoogleFonts.poppins(
                    color: _kTextPri,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  timerStr,
                  style: GoogleFonts.poppins(
                    color: _kTextPri,
                    fontSize: 50,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onPauseResume,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kAccentCyan, width: 1.5),
              ),
              child: Text(
                isRunning ? 'Pause' : 'Resume',
                style: GoogleFonts.poppins(
                  color: _kTextPri,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 2. State Timeline Chart ────────────────────────────────────────────────────
class StateTimelineChart extends StatelessWidget {
  // TODO: receives real emotion history from SentioProvider once EEG is live
  final List<EmotionHistoryEntry> emotionHistory;

  const StateTimelineChart({super.key, required this.emotionHistory});

  static const _emotionY = <String, double>{
    'focused':  3.6,
    'calm':     2.8,
    'relaxed':  2.2,
    'neutral':  2.0,
    'excited':  1.6,
    'stressed': 1.0,
  };

  // Demo waveform that mirrors the screenshot; replaced by real history when present
  static const _demoSpots = [
    FlSpot(0.0, 2.0),  FlSpot(0.8, 2.6),  FlSpot(1.5, 3.2),
    FlSpot(2.2, 2.8),  FlSpot(3.0, 3.4),  FlSpot(3.8, 2.6),
    FlSpot(4.5, 2.1),  FlSpot(5.0, 2.4),  FlSpot(5.8, 3.0),
    FlSpot(6.5, 3.7),  FlSpot(7.3, 3.3),  FlSpot(8.0, 3.8),
    FlSpot(9.0, 3.1),  FlSpot(9.8, 3.5),  FlSpot(10.5, 2.6),
    FlSpot(11.0, 2.2), FlSpot(11.8, 2.5), FlSpot(12.5, 2.1),
    FlSpot(13.2, 2.4), FlSpot(14.0, 2.2), FlSpot(15.0, 2.3),
  ];

  List<FlSpot> _buildSpots() {
    if (emotionHistory.length < 2) return _demoSpots;
    final n = emotionHistory.length;
    return List.generate(n, (i) {
      final e = emotionHistory[i].emotion.toLowerCase();
      return FlSpot((i / (n - 1)) * 15.0, _emotionY[e] ?? 2.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final spots = _buildSpots();
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'State Timeline',
            style: GoogleFonts.poppins(
              color: _kTextPri,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 168,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left emotion legend icons
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _EmotionDot(
                      icon: PhosphorIcons.crosshair(),
                      color: _kAccentGrn,
                    ),
                    _EmotionDot(
                      // Stressed — mandala-like; use atom as closest phosphor match
                      icon: PhosphorIcons.atom(),
                      color: _kAccentRed,
                    ),
                    _EmotionDot(
                      // Relaxed / Calm lotus — fallback to Icons.spa if unavailable
                      icon: PhosphorIcons.flowerLotus(),
                      color: _kAccentPurp,
                    ),
                    _EmotionDot(
                      icon: PhosphorIcons.lightning(),
                      color: _kAccentPurp,
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(child: _buildChart(spots)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(List<FlSpot> spots) {
    return LineChart(
      LineChartData(
        minX: 0, maxX: 15,
        minY: 0.5, maxY: 4.5,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: _kCardBorder,
            strokeWidth: 1,
            dashArray: [4, 6],
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 5,
              getTitlesWidget: (v, _) => Text(
                '${v.toInt()}:00',
                style: GoogleFonts.poppins(
                  color: _kTextSec,
                  fontSize: 10,
                ),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.30,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
            // Multicolor gradient: blue → cyan → yellow matching screenshot
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xFF3A86FF), // blue  (0:00 – 5:00)
                _kAccentCyan,      // cyan  (5:00 – 10:00)
                _kAccentYell,      // yellow (10:00 – 15:00)
              ],
              stops: [0.0, 0.50, 1.0],
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 200),
    );
  }
}

class _EmotionDot extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _EmotionDot({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1.2),
      ),
      child: Icon(icon, color: color, size: 14),
    );
  }
}

// ── 3. Session Average Card ────────────────────────────────────────────────────
class SessionAverageCard extends StatelessWidget {
  // TODO: derive from aggregated sentio.emotionHistory once EEG is live
  final String emotion;
  final int percentage;

  const SessionAverageCard({
    super.key,
    required this.emotion,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    final e   = emotion.isEmpty ? 'calm' : emotion.toLowerCase();
    final pct = percentage == 0 ? 72 : percentage; // 72 % demo fallback
    final col = emotionColor(e);
    final lbl = emotionLabel(e);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Session Average',
            style: GoogleFonts.poppins(color: _kTextSec, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: col.withValues(alpha: 0.15),
                ),
                child: Icon(_iconForEmotion(e), color: col, size: 22),
              ),
              const SizedBox(width: 14),
              Text(
                lbl,
                style: GoogleFonts.poppins(
                  color: _kTextPri,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '$pct%',
                style: GoogleFonts.poppins(
                  color: _kTextPri,
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconForEmotion(String e) {
    switch (e) {
      case 'focused': return PhosphorIcons.crosshair();
      case 'stressed': return PhosphorIcons.atom();
      case 'excited': return PhosphorIcons.lightning();
      default: return PhosphorIcons.flowerLotus(); // calm, relaxed, neutral
    }
  }
}

// ── 4. Top States Card ─────────────────────────────────────────────────────────
class TopStatesCard extends StatelessWidget {
  // TODO: compute real percentages from sentio.emotionHistory once EEG is live
  final List<EmotionHistoryEntry> emotionHistory;

  const TopStatesCard({super.key, required this.emotionHistory});

  List<_TopStateRow> _rows() {
    if (emotionHistory.isEmpty) {
      // Demo data that matches the screenshot
      return const [
        _TopStateRow('Focused',  0.65, 'focused'),
        _TopStateRow('Calm',     0.20, 'calm'),
        _TopStateRow('Relaxed',  0.10, 'relaxed'),
        _TopStateRow('Stressed', 0.05, 'stressed'),
      ];
    }
    final counts = <String, int>{};
    for (final e in emotionHistory) {
      final k = e.emotion.toLowerCase();
      counts[k] = (counts[k] ?? 0) + 1;
    }
    final total  = emotionHistory.length;
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(4).map((e) => _TopStateRow(
      emotionLabel(e.key),
      e.value / total,
      e.key,
    )).toList();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows();
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top States',
            style: GoogleFonts.poppins(
              color: _kTextPri,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          ...rows.map((r) => _TopStateRowWidget(row: r)),
        ],
      ),
    );
  }
}

class _TopStateRow {
  final String label;
  final double fraction;
  final String emotionKey;
  const _TopStateRow(this.label, this.fraction, this.emotionKey);
}

class _TopStateRowWidget extends StatelessWidget {
  final _TopStateRow row;
  const _TopStateRowWidget({required this.row});

  IconData _icon() {
    switch (row.emotionKey) {
      case 'focused': return PhosphorIcons.crosshair();
      case 'stressed': return PhosphorIcons.atom();
      case 'excited': return PhosphorIcons.lightning();
      default: return PhosphorIcons.flowerLotus(); // calm, relaxed, neutral
    }
  }

  Color _barColor() {
    switch (row.emotionKey) {
      case 'relaxed': return _kAccentPurp;
      case 'stressed': return _kAccentRed;
      case 'excited': return _kAccentYell;
      default: return _kAccentCyan; // focused, calm, neutral
    }
  }

  @override
  Widget build(BuildContext context) {
    final col = emotionColor(row.emotionKey);
    final bar = _barColor();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(_icon(), color: col, size: 20),
          const SizedBox(width: 10),
          SizedBox(
            width: 60,
            child: Text(
              row.label,
              style: GoogleFonts.poppins(
                color: _kTextPri,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: row.fraction,
                minHeight: 5,
                backgroundColor: _kCardBorder,
                valueColor: AlwaysStoppedAnimation<Color>(bar),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 34,
            child: Text(
              '${(row.fraction * 100).round()}%',
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                color: _kTextPri,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom Navigation ──────────────────────────────────────────────────────────
class SentioBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const SentioBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: _kCardBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon:     PhosphorIcons.house(),
              label:    'Home',
              selected: currentIndex == 0,
              onTap:    () => onTap(0),
            ),
            _NavItem(
              icon:     PhosphorIcons.shield(),
              label:    'History',
              selected: currentIndex == 1,
              onTap:    () => onTap(1),
            ),
            _NavItem(
              icon:     PhosphorIcons.user(),
              label:    'Profile',
              selected: currentIndex == 2,
              onTap:    () => onTap(2),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final col = selected ? _kAccentCyan : _kTextSec;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: col, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: col,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
