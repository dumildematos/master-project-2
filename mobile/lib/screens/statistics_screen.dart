import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../models/sentio_state.dart';
import '../providers/sentio_provider.dart';
import '../theme/theme.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kBgTop      = Color(0xFF02080D);
const _kBgBottom   = Color(0xFF07131B);
const _kCardBg     = Color(0xFF101820);
const _kCardBorder = Color(0xFF1E2A33);
const _kCyan       = Color(0xFF00D9FF);
const _kBlue       = Color(0xFF2DA8FF);
const _kPurple     = Color(0xFF7B2CFF);
const _kGreen      = Color(0xFF43F26B);
const _kRed        = Color(0xFFFF4D4D);
const _kTextPri    = Color(0xFFFFFFFF);
const _kTextSec    = Color(0xFFA8B2BD);
const _kCardRadius = 24.0;

// ── Bar data model ─────────────────────────────────────────────────────────────
class BarEntry {
  final String label;
  final double value;    // 0–100 (minutes of focus time)
  final Color  topColor;
  final Color  botColor;
  const BarEntry(this.label, this.value, this.topColor, this.botColor);
}

// TODO: replace all const bar data with real backend-aggregated session stats
const _weekBars = [
  BarEntry('Mon', 25, Color(0xFF43F26B), Color(0xFF00BFA0)),
  BarEntry('Tue', 55, Color(0xFF00D9FF), Color(0xFF009ABE)),
  BarEntry('Wed', 35, Color(0xFF2DA8FF), Color(0xFF1A7ACC)),
  BarEntry('Thu', 40, Color(0xFF3898FF), Color(0xFF2060CC)),
  BarEntry('Fri', 62, Color(0xFF5580FF), Color(0xFF3350CC)),
  BarEntry('Sat', 78, Color(0xFF7B2CFF), Color(0xFF5518CC)),
  BarEntry('Sun', 40, Color(0xFF7B2CFF), Color(0xFF4D10BB)),
];

const _dayBars = [
  BarEntry('6am',  18, Color(0xFF43F26B), Color(0xFF00BFA0)),
  BarEntry('9am',  48, Color(0xFF00D9FF), Color(0xFF009ABE)),
  BarEntry('12pm', 62, Color(0xFF2DA8FF), Color(0xFF1A7ACC)),
  BarEntry('3pm',  38, Color(0xFF5580FF), Color(0xFF3350CC)),
  BarEntry('6pm',  52, Color(0xFF7B2CFF), Color(0xFF5518CC)),
  BarEntry('9pm',  22, Color(0xFF7B2CFF), Color(0xFF4D10BB)),
];

const _monthBars = [
  BarEntry('Wk 1', 42, Color(0xFF43F26B), Color(0xFF00BFA0)),
  BarEntry('Wk 2', 68, Color(0xFF2DA8FF), Color(0xFF1A7ACC)),
  BarEntry('Wk 3', 55, Color(0xFF5580FF), Color(0xFF3350CC)),
  BarEntry('Wk 4', 62, Color(0xFF7B2CFF), Color(0xFF5518CC)),
];

// ── Month names helper ─────────────────────────────────────────────────────────
const _kMonths = [
  'Jan','Feb','Mar','Apr','May','Jun',
  'Jul','Aug','Sep','Oct','Nov','Dec',
];

// ══════════════════════════════════════════════════════════════════════════════
// StatisticsScreen
// ══════════════════════════════════════════════════════════════════════════════
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  int _period = 1; // 0=Day  1=Week  2=Month — default matches screenshot
  int _offset = 0; // navigation offset within the selected period

  // ── Date label ───────────────────────────────────────────────────────────────
  String _fmtShort(DateTime d) => '${_kMonths[d.month - 1]} ${d.day}';

  String get _dateLabel {
    // Reference anchor: the screenshot shows May 6–12 2024 for Week, offset 0
    switch (_period) {
      case 0: // Day — navigate by single days
        final day = DateTime(2024, 5, 12).add(Duration(days: _offset));
        return '${_kMonths[day.month - 1]} ${day.day}, ${day.year}';
      case 2: // Month — navigate by calendar months
        final base    = DateTime(2024, 5 + _offset);
        return '${_kMonths[base.month - 1]} ${base.year}';
      default: // Week — navigate by 7-day blocks
        final mon = DateTime(2024, 5, 6).add(Duration(days: _offset * 7));
        final sun = mon.add(const Duration(days: 6));
        return '${_fmtShort(mon)} - ${_fmtShort(sun)}, ${sun.year}';
    }
  }

  List<BarEntry> get _bars {
    switch (_period) {
      case 0:  return _dayBars;
      case 2:  return _monthBars;
      default: return _weekBars;
    }
  }

  // TODO: derive focusTime / changeStr from real backend aggregates
  ({String time, String change, bool positive}) get _summary {
    switch (_period) {
      case 0:  return (time: '4h 32m',  change: '+18% from previous day',   positive: true);
      case 2:  return (time: '72h 10m', change: '-3% from previous month',  positive: false);
      default: return (time: '4h 32m',  change: '+18% from previous week',  positive: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final emotionHist = context.watch<SentioProvider>().emotionHistory;
    final s = _summary;

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
              _TopBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      SegmentedTimeSelector(
                        selectedIndex: _period,
                        onChanged: (i) => setState(() {
                          _period = i;
                          _offset = 0; // reset nav when switching period
                        }),
                      ),
                      const SizedBox(height: 16),
                      _DateNavRow(
                        label:  _dateLabel,
                        onPrev: () => setState(() => _offset--),
                        onNext: () => setState(() => _offset++),
                      ),
                      const SizedBox(height: 14),
                      FocusTimeChartCard(
                        focusTime: s.time,
                        changeStr: s.change,
                        positive:  s.positive,
                        bars:      _bars,
                      ),
                      const SizedBox(height: 14),
                      // TODO: derive TopStatesCard data from backend session history
                      TopStatesCard(emotionHistory: emotionHist),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              SentioBottomNavBar(
                currentIndex: 1, // History tab active
                onTap: (_) {}, // navigation handled by MainShell
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _TopBar
// ══════════════════════════════════════════════════════════════════════════════
class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(PhosphorIcons.list(), color: _kTextPri, size: 22),
            onPressed: () {},
          ),
          Expanded(
            child: Text(
              'Statistics',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: _kTextPri,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 48), // mirror the icon button for centering
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// GlassCard — reusable dark translucent card
// ══════════════════════════════════════════════════════════════════════════════
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

// ══════════════════════════════════════════════════════════════════════════════
// SegmentedTimeSelector
// ══════════════════════════════════════════════════════════════════════════════
class SegmentedTimeSelector extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  static const _labels = ['Day', 'Week', 'Month'];

  const SegmentedTimeSelector({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kCardBorder),
      ),
      child: Row(
        children: List.generate(_labels.length, (i) {
          final sel = i == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  color: sel ? const Color(0xFF1A2B40) : Colors.transparent,
                  border: sel
                      ? Border.all(
                          color: _kCyan.withValues(alpha: 0.55),
                          width: 1,
                        )
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  _labels[i],
                  style: GoogleFonts.poppins(
                    color: sel ? _kTextPri : _kTextSec,
                    fontSize: 14,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _DateNavRow
// ══════════════════════════════════════════════════════════════════════════════
class _DateNavRow extends StatelessWidget {
  final String       label;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _DateNavRow({
    required this.label,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(PhosphorIcons.caretLeft(), color: _kTextPri, size: 18),
          onPressed: onPrev,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: _kTextPri,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: Icon(PhosphorIcons.caretRight(), color: _kTextPri, size: 18),
          onPressed: onNext,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FocusTimeChartCard  (fl_chart BarChart with gradient bars)
// ══════════════════════════════════════════════════════════════════════════════
class FocusTimeChartCard extends StatelessWidget {
  // TODO: wire focusTime and bars to real aggregated data from backend API
  final String        focusTime;
  final String        changeStr;
  final bool          positive;
  final List<BarEntry> bars;

  const FocusTimeChartCard({
    super.key,
    required this.focusTime,
    required this.changeStr,
    required this.positive,
    required this.bars,
  });

  BarChartData _chartData() {
    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: 90,
      minY: 0,
      barGroups: List.generate(bars.length, (i) => BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: bars[i].value,
            width: 26,
            borderRadius: const BorderRadius.only(
              topLeft:  Radius.circular(7),
              topRight: Radius.circular(7),
            ),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end:   Alignment.bottomCenter,
              colors: [bars[i].topColor, bars[i].botColor],
            ),
          ),
        ],
      )),
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(
        show: true,
        border: const Border(
          bottom: BorderSide(color: _kCardBorder, width: 1),
        ),
      ),
      titlesData: FlTitlesData(
        topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            getTitlesWidget: (value, _) {
              final i = value.toInt();
              if (i < 0 || i >= bars.length) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  bars[i].label,
                  style: GoogleFonts.poppins(
                    color: _kTextSec,
                    fontSize: 11,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      barTouchData: BarTouchData(enabled: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Focus Time',
            style: GoogleFonts.poppins(color: _kTextSec, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            focusTime,
            style: GoogleFonts.poppins(
              color: _kTextPri,
              fontSize: 38,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            changeStr,
            style: GoogleFonts.poppins(
              color: positive ? _kGreen : _kRed,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: BarChart(_chartData()),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TopStatesCard
// ══════════════════════════════════════════════════════════════════════════════
class TopStatesCard extends StatelessWidget {
  // TODO: compute from real aggregated session emotion data from backend
  final List<EmotionHistoryEntry> emotionHistory;

  const TopStatesCard({super.key, required this.emotionHistory});

  List<StateData> _states() {
    if (emotionHistory.isEmpty) {
      // Demo data matching the screenshot
      return const [
        StateData('Focused',  0.65, 'focused'),
        StateData('Calm',     0.20, 'calm'),
        StateData('Relaxed',  0.10, 'relaxed'),
        StateData('Stressed', 0.05, 'stressed'),
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
    return sorted.take(4).map((e) => StateData(
      emotionLabel(e.key),
      e.value / total,
      e.key,
    )).toList();
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top States',
            style: GoogleFonts.poppins(
              color: _kCyan, // title is cyan as in the screenshot
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          ..._states().map((s) => StateProgressRow(data: s)),
        ],
      ),
    );
  }
}

class StateData {
  final String label;
  final double fraction;
  final String emotionKey;
  const StateData(this.label, this.fraction, this.emotionKey);
}

// ── StateProgressRow — icon + label + full-width bar beneath ──────────────────
class StateProgressRow extends StatelessWidget {
  final StateData data;
  const StateProgressRow({super.key, required this.data});

  IconData _icon() {
    switch (data.emotionKey) {
      case 'focused':  return PhosphorIcons.crosshair();
      case 'stressed': return PhosphorIcons.atom();
      case 'excited':  return PhosphorIcons.lightning();
      default:         return PhosphorIcons.flowerLotus(); // calm, relaxed, neutral
    }
  }

  Color _iconColor() {
    switch (data.emotionKey) {
      case 'focused':  return _kCyan;
      case 'calm':     return _kBlue;
      case 'relaxed':  return _kPurple;
      case 'stressed': return _kRed;
      default:         return _kCyan;
    }
  }

  Color _barColor() {
    switch (data.emotionKey) {
      case 'relaxed':  return _kPurple;
      case 'stressed': return const Color(0xFFCC44FF); // magenta for stressed
      default:         return _kCyan;
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconCol = _iconColor();
    final barCol  = _barColor();

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconCircle(icon: _icon(), color: iconCol),
              const SizedBox(width: 12),
              Text(
                data.label,
                style: GoogleFonts.poppins(
                  color: _kTextPri,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                '${(data.fraction * 100).round()}%',
                style: GoogleFonts.poppins(
                  color: _kTextPri,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Full-width progress bar below the row
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: data.fraction,
              minHeight: 4,
              backgroundColor: _kCardBorder,
              valueColor: AlwaysStoppedAnimation<Color>(barCol),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconCircle extends StatelessWidget {
  final IconData icon;
  final Color    color;
  const _IconCircle({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1.5),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SentioBottomNavBar
// ══════════════════════════════════════════════════════════════════════════════
class SentioBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const SentioBottomNavBar({
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
              icon:     PhosphorIcons.chartBar(),
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
  final IconData     icon;
  final String       label;
  final bool         selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final col = selected ? _kCyan : _kTextSec;
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
