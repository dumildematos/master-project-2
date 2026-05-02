import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../providers/session_provider.dart';
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

const _kRangeOptions = ['day', 'week', 'month'];
const _kRangeLabels  = {'day': 'Today', 'week': 'This Week', 'month': 'This Month'};

String _fmtDuration(int? secs) {
  if (secs == null || secs == 0) return '—';
  final h = secs ~/ 3600;
  final m = (secs % 3600) ~/ 60;
  if (h > 0) return '${h}h ${m}m';
  return '${m}m';
}

String _fmtDate(String iso) {
  try {
    final d = DateTime.parse(iso).toLocal();
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  } catch (_) {
    return iso;
  }
}

IconData _iconForState(String? state) {
  switch (state?.toLowerCase()) {
    case 'focused':  return PhosphorIcons.crosshair();
    case 'stressed': return PhosphorIcons.atom();
    case 'excited':  return PhosphorIcons.lightning();
    default:         return PhosphorIcons.flowerLotus();
  }
}

Color _colorForState(String? state) {
  switch (state?.toLowerCase()) {
    case 'focused':  return _kGreen;
    case 'stressed': return const Color(0xFFFF5252);
    case 'excited':  return _kYellow;
    case 'relaxed':  return _kPurple;
    default:         return _kCyan;
  }
}

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
  String _range = 'week';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SessionProvider>().fetchHistory(_range);
    });
  }

  Future<void> _confirmDelete(String sessionId) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: _kCardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Delete this session permanently?',
                style: GoogleFonts.poppins(
                    color: _kTextPri, fontSize: 16, fontWeight: FontWeight.w600)),
            content: Text('This action cannot be undone.',
                style: GoogleFonts.poppins(color: _kTextSec, fontSize: 13)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel',
                    style: GoogleFonts.poppins(color: _kTextSec, fontSize: 14)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Delete',
                    style: GoogleFonts.poppins(
                        color: const Color(0xFFFF3B4A),
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) return;

    final session = context.read<SessionProvider>();
    try {
      await session.deleteSession(sessionId);
      session.fetchDashboardSummary();
      session.fetchStats(_range);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete session')),
        );
      }
    }
  }

  void _openFilter() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _kCardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => _FilterSheet(
        current: _kRangeLabels[_range]!,
        options: _kRangeLabels.values.toList(),
        onSelect: (label) {
          final newRange = _kRangeOptions[_kRangeLabels.values.toList().indexOf(label)];
          setState(() => _range = newRange);
          context.read<SessionProvider>().fetchHistory(newRange);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final items   = session.history;

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
                  value: _kRangeLabels[_range]!,
                  onTap: _openFilter,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: session.isLoading
                    ? const Center(child: CircularProgressIndicator(color: _kCyan))
                    : items.isEmpty
                        ? Center(child: Text('No sessions yet',
                            style: GoogleFonts.poppins(color: _kTextSec, fontSize: 14)))
                        : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final s = items[i];
                    return SessionHistoryCard(
                      date:      _fmtDate(s.startedAt),
                      title:     s.title ?? s.dominantState ?? 'Session',
                      duration:  _fmtDuration(s.durationSeconds),
                      score:     ((s.averageConfidence ?? 0) * 100).round(),
                      icon:      _iconForState(s.dominantState),
                      iconColor: _colorForState(s.dominantState),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const StatisticsScreen(),
                        ),
                      ),
                      onDelete: () => _confirmDelete(s.sessionId),
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
      padding: const EdgeInsets.fromLTRB(8, 14, 20, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(PhosphorIcons.arrowLeft(), color: _kTextPri, size: 22),
            onPressed: () => Navigator.maybePop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
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
  final VoidCallback? onDelete;

  const SessionHistoryCard({
    super.key,
    required this.date,
    required this.title,
    required this.duration,
    required this.score,
    required this.icon,
    required this.iconColor,
    this.onTap,
    this.onDelete,
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
            Icon(icon, color: iconColor, size: 54),
            const SizedBox(width: 18),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(date,
                      style: GoogleFonts.poppins(
                          color: _kTextSec, fontSize: 12, fontWeight: FontWeight.w400)),
                  const SizedBox(height: 2),
                  Text(title,
                      style: GoogleFonts.poppins(
                          color: _kCyan, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(duration,
                      style: GoogleFonts.poppins(
                          color: _kTextPri, fontSize: 15, fontWeight: FontWeight.w500)),
                ],
              ),
            ),

            Text('$score%',
                style: GoogleFonts.poppins(
                    color: _kGreen, fontSize: 22, fontWeight: FontWeight.w700)),

            if (onDelete != null) ...[
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFF3B4A).withValues(alpha: 0.10),
                    border: Border.all(
                        color: const Color(0xFFFF3B4A).withValues(alpha: 0.35)),
                  ),
                  child: Icon(PhosphorIcons.trash(),
                      color: const Color(0xFFFF3B4A), size: 16),
                ),
              ),
            ],
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
