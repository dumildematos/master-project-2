import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../providers/sentio_provider.dart';
import 'statistics_screen.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kBgTop      = Color(0xFF02070D);
const _kBgBottom   = Color(0xFF06131B);
const _kCardBg     = Color(0xFF101923);
const _kCardBorder = Color(0xFF1E2A35);
const _kCyan       = Color(0xFF00D9FF);
const _kPurple     = Color(0xFFA855F7);
const _kGreen      = Color(0xFF4ADE80);
const _kYellow     = Color(0xFFFACC15);
const _kTextPri    = Color(0xFFFFFFFF);
const _kTextSec    = Color(0xFF9AA6B2);
const _kCardRadius = 20.0;

// ── Session data model (private to this file) ──────────────────────────────────
// TODO: replace with a real SessionRecord model fetched from the backend API
class _SessionData {
  final String   date;
  final String   title;
  final String   duration;
  final int      score;
  final IconData icon;
  final Color    iconColor;

  const _SessionData({
    required this.date,
    required this.title,
    required this.duration,
    required this.score,
    required this.icon,
    required this.iconColor,
  });
}

const _kFilterOptions = [
  'All Sessions',
  'Meditation',
  'Focus Work',
  'Relax',
  'Study',
];

// ══════════════════════════════════════════════════════════════════════════════
// HistoryScreen
// Lives inside MainShell's IndexedStack — the shell provides the bottom nav.
// ══════════════════════════════════════════════════════════════════════════════
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _filter = 'All Sessions';

  // TODO: load real session history from SentioApi / local database
  late final List<_SessionData> _sessions;

  @override
  void initState() {
    super.initState();
    _sessions = [
      _SessionData(
        date: 'May 12, 2024', title: 'Meditation',
        duration: '4h 32m',   score: 72,
        icon: PhosphorIcons.target(),
        iconColor: _kPurple,
      ),
      _SessionData(
        date: 'May 11, 2024', title: 'Focus Work',
        duration: '2h 15m',   score: 68,
        icon: PhosphorIcons.crosshair(),
        iconColor: _kGreen,
      ),
      _SessionData(
        date: 'May 10, 2024', title: 'Relax',
        duration: '1h 10m',   score: 75,
        icon: PhosphorIcons.flowerLotus(),
        iconColor: _kPurple,
      ),
      _SessionData(
        date: 'May 9, 2024', title: 'Study',
        duration: '3h 05m',  score: 65,
        icon: PhosphorIcons.lightning(),
        iconColor: _kYellow,
      ),
    ];
  }

  List<_SessionData> get _filtered => _filter == 'All Sessions'
      ? _sessions
      : _sessions.where((s) => s.title == _filter).toList();

  void _openFilter() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _kCardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => _FilterSheet(
        current: _filter,
        options: _kFilterOptions,
        onSelect: (v) {
          setState(() => _filter = v);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<SentioProvider>(); // rebuild when live EEG data updates

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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopBar(onFilterTap: _openFilter),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: HistoryFilterDropdown(
                  value: _filter,
                  onTap: _openFilter,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final s = _filtered[i];
                    return SessionHistoryCard(
                      date:      s.date,
                      title:     s.title,
                      duration:  s.duration,
                      score:     s.score,
                      icon:      s.icon,
                      iconColor: s.iconColor,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const StatisticsScreen(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Filter bottom sheet ────────────────────────────────────────────────────────
class _FilterSheet extends StatelessWidget {
  final String current;
  final List<String> options;
  final ValueChanged<String> onSelect;

  const _FilterSheet({
    required this.current,
    required this.options,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 10),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: _kCardBorder,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        ...options.map((o) {
          final sel = o == current;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            title: Text(
              o,
              style: GoogleFonts.poppins(
                color: sel ? _kCyan : _kTextPri,
                fontSize: 15,
                fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            trailing: sel
                ? Icon(PhosphorIcons.check(), color: _kCyan, size: 18)
                : null,
            onTap: () => onSelect(o),
          );
        }),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _TopBar
// ══════════════════════════════════════════════════════════════════════════════
class _TopBar extends StatelessWidget {
  final VoidCallback onFilterTap;
  const _TopBar({required this.onFilterTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 20, 0),
      child: Row(
        children: [
          const SizedBox(width: 32), // balance for the right icon
          Expanded(
            child: Text(
              'History',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: _kTextPri,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            icon: Icon(PhosphorIcons.funnel(), color: _kTextSec, size: 22),
            onPressed: onFilterTap,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// GlassCard — reusable dark rounded card
// ══════════════════════════════════════════════════════════════════════════════
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final List<BoxShadow>? shadows;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = _kCardRadius,
    this.shadows,
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
        boxShadow: shadows,
      ),
      child: child,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// HistoryFilterDropdown — "All Sessions" selector card
// ══════════════════════════════════════════════════════════════════════════════
class HistoryFilterDropdown extends StatelessWidget {
  final String       value;
  final VoidCallback onTap;

  const HistoryFilterDropdown({
    super.key,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Text(
              value,
              style: GoogleFonts.poppins(
                color: _kTextPri,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Icon(PhosphorIcons.caretDown(), color: _kTextSec, size: 22),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SessionHistoryCard — single past-session row
// ══════════════════════════════════════════════════════════════════════════════
class SessionHistoryCard extends StatelessWidget {
  final String   date;
  final String   title;
  final String   duration;
  final int      score;
  final IconData icon;
  final Color    iconColor;
  final VoidCallback? onTap;

  const SessionHistoryCard({
    super.key,
    required this.date,
    required this.title,
    required this.duration,
    required this.score,
    required this.icon,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        shadows: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Large session icon — no background, stroke style via Phosphor
            Icon(icon, color: iconColor, size: 54),
            const SizedBox(width: 18),

            // Date / title / duration
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date,
                    style: GoogleFonts.poppins(
                      color: _kTextSec,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: _kCyan,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    duration,
                    style: GoogleFonts.poppins(
                      color: _kTextPri,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Score — always bright green as per design
            Text(
              '$score%',
              style: GoogleFonts.poppins(
                color: _kGreen,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// BottomNavBar — reusable standalone bottom navigation
// Used by screens pushed as routes (SessionScreen, StatisticsScreen, etc.).
// HistoryScreen itself relies on MainShell for the bottom nav.
// ══════════════════════════════════════════════════════════════════════════════
class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNavBar({
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
