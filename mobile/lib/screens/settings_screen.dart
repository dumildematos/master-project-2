import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/ble_provider.dart';
import '../theme/theme.dart';
import 'connect_device_screen.dart';
import 'splash_screen.dart';

// ══════════════════════════════════════════════════════════════════════════════
// SettingsScreen — rendered as a MainShell tab (shell provides bottom nav)
// Also used as a pushed route; back button auto-shows via canPop check.
// ══════════════════════════════════════════════════════════════════════════════
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _vibration = true;

  Future<void> _confirmSignOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SentioColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: SentioColors.cardBorder),
        ),
        title: Text('Sign Out',
            style: GoogleFonts.poppins(
                color: SentioColors.textPrimary,
                fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to sign out?',
            style: GoogleFonts.poppins(color: SentioColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: SentioColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Sign Out',
                style: GoogleFonts.poppins(
                    color: SentioColors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      await context.read<AuthProvider>().logout();
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
    final ble          = context.watch<BleProvider>();
    final connectedCount =
        (ble.isMuseConnected ? 1 : 0) + (ble.isHatConnected ? 1 : 0);
    final canPop = Navigator.of(context).canPop();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [SentioColors.bgTop, SentioColors.bgBottom],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _SettingsTopBar(showBack: canPop),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),

                    // ── DEVICE ───────────────────────────────────────────
                    const _SectionLabel('DEVICE'),
                    const SizedBox(height: 12),
                    _SettingsCard(children: [
                      _SettingsTile(
                        icon: PhosphorIcons.bluetooth(),
                        title: 'Connected Devices',
                        subtitle: connectedCount == 0
                            ? 'No devices connected'
                            : '$connectedCount device${connectedCount > 1 ? 's' : ''} connected',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ConnectDeviceScreen()),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 28),

                    // ── PREFERENCES ──────────────────────────────────────
                    const _SectionLabel('PREFERENCES'),
                    const SizedBox(height: 12),
                    _SettingsCard(children: [
                      _SettingsTile(
                        icon: PhosphorIcons.chartLineUp(),
                        title: 'Data & Insights',
                        subtitle: 'Manage your brain data and insights',
                        onTap: () {},
                      ),
                      const _RowDiv(),
                      _SettingsTile(
                        icon: PhosphorIcons.bell(),
                        title: 'Notifications',
                        subtitle: 'Customize your notifications',
                        onTap: () {},
                      ),
                      const _RowDiv(),
                      _SettingsTile(
                        icon: PhosphorIcons.moon(),
                        title: 'Focus Mode',
                        subtitle: 'Reduce distractions and stay focused',
                        onTap: () {},
                      ),
                      const _RowDiv(),
                      _SettingsTile(
                        icon: PhosphorIcons.palette(),
                        title: 'Appearance',
                        subtitle: 'Customize app theme and display',
                        onTap: () {},
                      ),
                      const _RowDiv(),
                      _SettingsTile(
                        icon: PhosphorIcons.globe(),
                        title: 'Language',
                        subtitle: null,
                        trailing: const _ValueChevron('English'),
                        onTap: () {},
                      ),
                      const _RowDiv(),
                      _SettingsTile(
                        icon: PhosphorIcons.ruler(),
                        title: 'Units',
                        subtitle: null,
                        trailing: const _ValueChevron('Metric (kg, cm)'),
                        onTap: () {},
                      ),
                      const _RowDiv(),
                      _SettingsTile(
                        icon: PhosphorIcons.vibrate(),
                        title: 'Vibration',
                        subtitle: _vibration ? 'On' : 'Off',
                        trailing: Switch(
                          value: _vibration,
                          onChanged: (v) => setState(() => _vibration = v),
                          activeTrackColor: SentioColors.cyan,
                          activeThumbColor: Colors.white,
                          inactiveTrackColor: SentioColors.cardBorder,
                          inactiveThumbColor: SentioColors.textSecondary,
                        ),
                        onTap: () => setState(() => _vibration = !_vibration),
                      ),
                    ]),
                    const SizedBox(height: 28),

                    // ── SUPPORT ──────────────────────────────────────────
                    const _SectionLabel('SUPPORT'),
                    const SizedBox(height: 12),
                    _SettingsCard(children: [
                      _SettingsTile(
                        icon: PhosphorIcons.question(),
                        title: 'Help & Support',
                        subtitle: 'Get help and find answers',
                        onTap: () {},
                      ),
                      const _RowDiv(),
                      _SettingsTile(
                        icon: PhosphorIcons.chatDots(),
                        title: 'Contact Support',
                        subtitle: 'We\'re here to help',
                        onTap: () {},
                      ),
                      const _RowDiv(),
                      _SettingsTile(
                        icon: PhosphorIcons.shieldCheck(),
                        title: 'Privacy Policy',
                        subtitle: 'How we protect your data',
                        onTap: () {},
                      ),
                      const _RowDiv(),
                      _SettingsTile(
                        icon: PhosphorIcons.fileText(),
                        title: 'Terms of Service',
                        subtitle: 'Read our terms and conditions',
                        onTap: () {},
                      ),
                    ]),
                    const SizedBox(height: 28),

                    // ── ABOUT ────────────────────────────────────────────
                    const _SectionLabel('ABOUT'),
                    const SizedBox(height: 12),
                    _SettingsCard(children: [
                      _SettingsTile(
                        icon: PhosphorIcons.info(),
                        title: 'SENTIO App',
                        subtitle: 'Version 1.0.0',
                        trailing: const SizedBox.shrink(),
                        onTap: () {},
                      ),
                    ]),
                    const SizedBox(height: 28),

                    // ── Sign Out ─────────────────────────────────────────
                    _SignOutButton(onTap: _confirmSignOut),
                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────
class _SettingsTopBar extends StatelessWidget {
  final bool showBack;
  const _SettingsTopBar({required this.showBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              icon: Icon(PhosphorIcons.caretLeft(),
                  color: SentioColors.textPrimary, size: 22),
              onPressed: () => Navigator.pop(context),
            )
          else
            const SizedBox(width: 48),
          Expanded(
            child: Text(
              'Settings',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: SentioColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

// ── Settings card (section container) ────────────────────────────────────────
class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: SentioColors.card,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: SentioColors.cardBorder),
      boxShadow: const [
        BoxShadow(color: Color(0x1A000000), blurRadius: 10, offset: Offset(0, 4)),
      ],
    ),
    child: Column(children: children),
  );
}

// ── Settings tile ─────────────────────────────────────────────────────────────
class _SettingsTile extends StatelessWidget {
  final IconData     icon;
  final String       title;
  final String?      subtitle;
  final Widget?      trailing;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: SentioColors.textSecondary, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: GoogleFonts.poppins(
                    color: SentioColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  )),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: GoogleFonts.poppins(
                      color: SentioColors.textSecondary,
                      fontSize: 12,
                    )),
                  ],
                ],
              ),
            ),
            trailing ??
                Icon(PhosphorIcons.caretRight(),
                    color: SentioColors.textSecondary, size: 16),
          ],
        ),
      ),
    );
  }
}

// ── Value + chevron trailing ──────────────────────────────────────────────────
class _ValueChevron extends StatelessWidget {
  final String value;
  const _ValueChevron(this.value);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(value, style: GoogleFonts.poppins(
        color: SentioColors.textSecondary,
        fontSize: 13,
      )),
      const SizedBox(width: 4),
      Icon(PhosphorIcons.caretRight(),
          color: SentioColors.textSecondary, size: 16),
    ],
  );
}

// ── Sign out button ───────────────────────────────────────────────────────────
class _SignOutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SignOutButton({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: SentioColors.red.withValues(alpha: 0.70), width: 1.5),
        color: SentioColors.red.withValues(alpha: 0.08),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIcons.signOut(), color: SentioColors.red, size: 20),
          const SizedBox(width: 10),
          Text('Sign Out', style: GoogleFonts.poppins(
            color: SentioColors.red,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          )),
        ],
      ),
    ),
  );
}

// ── Row divider ───────────────────────────────────────────────────────────────
class _RowDiv extends StatelessWidget {
  const _RowDiv();

  @override
  Widget build(BuildContext context) => const Divider(
    height: 1, thickness: 0.5,
    color: SentioColors.cardBorder,
    indent: 52, endIndent: 0,
  );
}

// ── Section label ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: GoogleFonts.poppins(
      color: SentioColors.textSecondary,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.2,
    ),
  );
}
