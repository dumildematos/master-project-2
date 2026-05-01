import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'settings_screen.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kBgTop      = Color(0xFF02080D);
const _kBgBottom   = Color(0xFF07131B);
const _kCardBg     = Color(0xFF101820);
const _kCardBorder = Color(0xFF1E2A33);
const _kCyan       = Color(0xFF00D9FF);
const _kGreen      = Color(0xFF18DFA3); // vibration toggle active
const _kTextPri    = Color(0xFFFFFFFF);
const _kTextSec    = Color(0xFF9AA6B2);
const _kDivider    = Color(0xFF1A2530);
const _kAvatarBg   = Color(0xFF0D2838); // dark teal avatar fill
const _kCardRadius = 24.0;

// ══════════════════════════════════════════════════════════════════════════════
// ProfileScreen
// Lives inside MainShell's IndexedStack — the shell provides the bottom nav.
// ══════════════════════════════════════════════════════════════════════════════
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _vibration = true;

  @override
  Widget build(BuildContext context) {
    // TODO: load name/email/avatar from AuthService or a UserProvider
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TopBar(
                  onSettingsTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
                const SizedBox(height: 28),
                // User section — row layout as shown in the reference screenshot
                const ProfileHeader(name: 'Alex', email: 'alex@email.com'),
                const SizedBox(height: 28),
                // Preferences settings card
                _PreferencesCard(
                  vibration: _vibration,
                  onVibrationChanged: (v) => setState(() => _vibration = v),
                ),
                const SizedBox(height: 16),
                // About card
                const AboutCard(),
                const SizedBox(height: 40),
              ],
            ),
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
  final VoidCallback onSettingsTap;
  const _TopBar({required this.onSettingsTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          const SizedBox(width: 32), // balance the right gear icon width
          Expanded(
            child: Text(
              'Profile',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: _kTextPri,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          GestureDetector(
            onTap: onSettingsTap,
            behavior: HitTestBehavior.opaque,
            child: Icon(PhosphorIcons.gear(), color: _kTextSec, size: 24),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// GlassCard — reusable dark rounded card with soft shadow
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
        boxShadow: const [
          BoxShadow(
            color: Color(0x28000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ProfileHeader — avatar + name + email row
// ══════════════════════════════════════════════════════════════════════════════
class ProfileHeader extends StatelessWidget {
  // TODO: replace with AuthUser from AuthService once user session is available
  final String name;
  final String email;

  const ProfileHeader({
    super.key,
    required this.name,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Circular avatar with cyan ring
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _kAvatarBg,
            border: Border.all(color: _kCyan, width: 2.5),
          ),
          alignment: Alignment.center,
          child: Text(
            initial,
            style: GoogleFonts.poppins(
              color: _kTextPri,
              fontSize: 30,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 20),
        // Name and email
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: GoogleFonts.poppins(
                color: _kTextPri,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              email,
              style: GoogleFonts.poppins(
                color: _kTextSec,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _PreferencesCard
// ══════════════════════════════════════════════════════════════════════════════
class _PreferencesCard extends StatelessWidget {
  final bool vibration;
  final ValueChanged<bool> onVibrationChanged;

  const _PreferencesCard({
    required this.vibration,
    required this.onVibrationChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle('Preferences'),
          const SizedBox(height: 8),
          PreferenceRow(
            icon:     PhosphorIcons.slidersHorizontal(),
            label:    'Sensitivity',
            trailing: const _ValueChevron(value: 'Medium'),
            onTap:    () {}, // TODO: open sensitivity picker
          ),
          const _RowDivider(),
          PreferenceRow(
            icon:     PhosphorIcons.clockCounterClockwise(),
            label:    'Update Baseline',
            trailing: const _ChevronIcon(),
            onTap:    () {}, // TODO: trigger baseline recalibration
          ),
          const _RowDivider(),
          PreferenceRow(
            icon:     PhosphorIcons.percent(),
            label:    'Units',
            trailing: const _ValueChevron(value: '%'),
            onTap:    () {}, // TODO: open units selector
          ),
          const _RowDivider(),
          PreferenceRow(
            icon:  PhosphorIcons.vibrate(),
            label: 'Vibration',
            trailing: Switch(
              value:              vibration,
              onChanged:          onVibrationChanged,
              activeThumbColor:   _kGreen,
              activeTrackColor:   _kGreen.withValues(alpha: 0.35),
              inactiveTrackColor: _kCardBorder,
              inactiveThumbColor: _kTextSec,
            ),
            onTap: () => onVibrationChanged(!vibration),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// AboutCard — device version info
// ══════════════════════════════════════════════════════════════════════════════
class AboutCard extends StatelessWidget {
  const AboutCard({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle('About'),
          const SizedBox(height: 8),
          PreferenceRow(
            icon:  PhosphorIcons.fileText(),
            label: 'SENTIO Device',
            trailing: Text(
              'v1.0.0',
              style: GoogleFonts.poppins(
                color: _kTextSec,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
            onTap: () {}, // TODO: open device info / firmware update
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PreferenceRow — single settings row with icon, label, and optional trailing
// ══════════════════════════════════════════════════════════════════════════════
class PreferenceRow extends StatelessWidget {
  final IconData      icon;
  final String        label;
  final Widget?       trailing;
  final VoidCallback? onTap;

  const PreferenceRow({
    super.key,
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 58,
        child: Row(
          children: [
            Icon(icon, color: _kTextSec, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  color: _kTextPri,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

// ── Private helpers ────────────────────────────────────────────────────────────

class _CardTitle extends StatelessWidget {
  final String text;
  const _CardTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        color: _kTextPri,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 0.5,
      color: _kDivider,
    );
  }
}

class _ValueChevron extends StatelessWidget {
  final String value;
  const _ValueChevron({required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(color: _kTextSec, fontSize: 14),
        ),
        const SizedBox(width: 6),
        Icon(PhosphorIcons.caretRight(), color: _kTextSec, size: 16),
      ],
    );
  }
}

class _ChevronIcon extends StatelessWidget {
  const _ChevronIcon();

  @override
  Widget build(BuildContext context) =>
      Icon(PhosphorIcons.caretRight(), color: _kTextSec, size: 16);
}

// ══════════════════════════════════════════════════════════════════════════════
// SentioBottomNavBar — reusable pill nav for standalone pushed screens.
// ProfileScreen itself relies on MainShell's bottom nav (not rendered here).
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
              icon:     PhosphorIcons.chartLine(),
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
