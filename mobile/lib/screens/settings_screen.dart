import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../providers/ble_provider.dart';
import '../services/auth_service.dart';
import 'splash_screen.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kBgTop      = Color(0xFF02080D);
const _kBgBottom   = Color(0xFF07131B);
const _kCardBg     = Color(0xFF101820);
const _kCardBorder = Color(0xFF1E2A33);
const _kCyan       = Color(0xFF00D9FF);
const _kGreen      = Color(0xFF43F26B);
const _kRed        = Color(0xFFFF3B3B);
const _kTextPri    = Color(0xFFFFFFFF);
const _kTextSec    = Color(0xFF9AA6B2);
const _kDivider    = Color(0xFF1A2530);
const _kToggle     = Color(0xFF18DFA3); // notifications toggle active
const _kCardRadius = 24.0;

// ══════════════════════════════════════════════════════════════════════════════
// SettingsScreen — pushed route from ProfileScreen / Dashboard quick actions
// ══════════════════════════════════════════════════════════════════════════════
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;

  Future<void> _confirmSignOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _kCardBorder),
        ),
        title: Text(
          'Sign Out',
          style: GoogleFonts.poppins(
            color: _kTextPri,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to sign out?',
          style: GoogleFonts.poppins(color: _kTextSec),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: _kTextSec),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Sign Out',
              style: GoogleFonts.poppins(
                color: _kRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      await clearAuth(); // clears JWT + cached user from secure storage
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const SplashScreen()),
          (_) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ble            = context.watch<BleProvider>();
    final muse2Connected = ble.state == BLEState.connected;
    final muse2Name      = ble.connectedDevice?.name ?? 'Muse 2';
    final hatConnected   = ble.isHatConnected;
    final hatName        = ble.connectedHat?.platformName ?? 'SENTIO Hat';

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
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),

                      // ── Device card ──────────────────────────────────
                      GlassCard(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _CardTitle('Device'),
                            const SizedBox(height: 16),
                            // TODO: device list from real BLE scan results
                            DeviceStatusRow(
                              deviceName: muse2Name,
                              connected:  muse2Connected,
                              batteryPct: 90,
                              icon:       PhosphorIcons.headphones(),
                              iconColor:  const Color(0xFF6B7FA3),
                            ),
                            const _RowDivider(),
                            DeviceStatusRow(
                              deviceName: hatName,
                              connected:  hatConnected,
                              batteryPct: 80,
                              icon:       PhosphorIcons.hardHat(),
                              iconColor:  _kCyan,
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── App card ─────────────────────────────────────
                      GlassCard(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _CardTitle('App'),
                            const SizedBox(height: 8),
                            SettingsListRow(
                              icon:  PhosphorIcons.bell(),
                              label: 'Notifications',
                              trailing: Switch(
                                value:              _notifications,
                                onChanged:          (v) => setState(() => _notifications = v),
                                activeThumbColor:   Colors.white,
                                activeTrackColor:   _kToggle,
                                inactiveTrackColor: _kCardBorder,
                                inactiveThumbColor: _kTextSec,
                              ),
                              onTap: () => setState(
                                () => _notifications = !_notifications,
                              ),
                            ),
                            const _RowDivider(),
                            SettingsListRow(
                              icon:     PhosphorIcons.downloadSimple(),
                              label:    'Data Export',
                              trailing: Icon(PhosphorIcons.caretRight(), color: _kTextSec, size: 18),
                              onTap:    () {}, // TODO: export session data to file
                            ),
                            const _RowDivider(),
                            SettingsListRow(
                              icon:     PhosphorIcons.question(),
                              label:    'Help & Support',
                              trailing: Icon(PhosphorIcons.caretRight(), color: _kTextSec, size: 18),
                              onTap:    () {}, // TODO: open support URL
                            ),
                            const _RowDivider(),
                            SettingsListRow(
                              icon:     PhosphorIcons.shieldCheck(),
                              label:    'Privacy Policy',
                              trailing: Icon(PhosphorIcons.caretRight(), color: _kTextSec, size: 18),
                              onTap:    () {}, // TODO: open privacy policy URL
                            ),
                            const _RowDivider(),
                            SettingsListRow(
                              icon:     PhosphorIcons.article(),
                              label:    'Terms of Use',
                              trailing: Icon(PhosphorIcons.caretRight(), color: _kTextSec, size: 18),
                              onTap:    () {}, // TODO: open terms of use URL
                            ),
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      SignOutButton(onTap: _confirmSignOut),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // Bottom nav — Profile tab active (this screen is under Profile)
              SentioBottomNav(
                currentIndex: 2,
                onTap: (i) {
                  if (i == 2) {
                    Navigator.pop(context);
                  } else {
                    // Pop back to MainShell root for Home / History
                    Navigator.popUntil(context, (r) => r.isFirst);
                  }
                },
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
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(PhosphorIcons.caretLeft(), color: _kTextPri, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              'Settings',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: _kTextPri,
                fontSize: 20,
                fontWeight: FontWeight.w700,
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
// GlassCard — reusable dark rounded card
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
// DeviceStatusRow — single connected device with battery indicator
// ══════════════════════════════════════════════════════════════════════════════
class DeviceStatusRow extends StatelessWidget {
  final String   deviceName;
  final bool     connected;
  final int      batteryPct;    // 0–100
  final IconData icon;
  final Color    iconColor;

  const DeviceStatusRow({
    super.key,
    required this.deviceName,
    required this.connected,
    required this.batteryPct,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = connected ? _kGreen : _kTextSec;
    final statusLabel = connected ? 'Connected' : 'Disconnected';

    return SizedBox(
      height: 72,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Device avatar — styled icon placeholder
          // TODO: replace with Image.asset('assets/images/<device>.png')
          //       once product images are available
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: iconColor.withValues(alpha: 0.10),
              border: Border.all(
                color: iconColor.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(width: 14),

          // Device name + connection status
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deviceName,
                  style: GoogleFonts.poppins(
                    color: _kTextPri,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusLabel,
                  style: GoogleFonts.poppins(
                    color: statusColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Battery icon + percentage (only when connected)
          if (connected) ...[
            Icon(
              PhosphorIcons.batteryHigh(),
              color: _kGreen,
              size: 24,
            ),
            const SizedBox(width: 6),
            Text(
              '$batteryPct%',
              style: GoogleFonts.poppins(
                color: _kTextSec,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SettingsListRow — single settings row with icon, label, and trailing widget
// ══════════════════════════════════════════════════════════════════════════════
class SettingsListRow extends StatelessWidget {
  final IconData      icon;
  final String        label;
  final Widget?       trailing;
  final VoidCallback? onTap;

  const SettingsListRow({
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
        height: 60,
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

// ══════════════════════════════════════════════════════════════════════════════
// SignOutButton — full-width red-bordered destructive action button
// ══════════════════════════════════════════════════════════════════════════════
class SignOutButton extends StatelessWidget {
  final VoidCallback onTap;

  const SignOutButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 64,
        decoration: BoxDecoration(
          color: _kRed.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(_kCardRadius),
          border: Border.all(color: _kRed, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(
          'Sign Out',
          style: GoogleFonts.poppins(
            color: _kRed,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SentioBottomNav — pill-style floating bottom navigation
// ══════════════════════════════════════════════════════════════════════════════
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
