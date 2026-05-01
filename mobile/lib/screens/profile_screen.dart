import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme/theme.dart';
import 'settings_screen.dart';

const _kAvatarBg = Color(0xFF091622);

// ══════════════════════════════════════════════════════════════════════════════
// ProfileScreen — lives in MainShell IndexedStack (shell provides bottom nav)
// ══════════════════════════════════════════════════════════════════════════════
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user    = context.watch<AuthProvider>().currentUser;
    final name    = (user?.displayName.isNotEmpty == true)
        ? user!.displayName
        : 'Alex Johnson';
    final email   = (user?.email.isNotEmpty == true)
        ? user!.email
        : 'alex.johnson@email.com';
    final initial = user?.initials ?? 'A';

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
            _ProfileTopBar(onSettings: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            )),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 28),
                    _ProfileHero(
                        name: name, email: email, initial: initial,
                        photoUrl: user?.photoUrl),
                    const SizedBox(height: 24),
                    _StatsCard(),
                    const SizedBox(height: 28),
                    const _SectionTitle('ACCOUNT'),
                    const SizedBox(height: 12),
                    _AccountCard(),
                    const SizedBox(height: 24),
                    const _SectionTitle('CONNECTED ACCOUNTS'),
                    const SizedBox(height: 12),
                    _ConnectedAccountsCard(email: email),
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
class _ProfileTopBar extends StatelessWidget {
  final VoidCallback onSettings;
  const _ProfileTopBar({required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 14, 16, 0),
      child: Row(
        children: [
          const SizedBox(width: 40),
          Expanded(
            child: Text(
              'Profile',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: SentioColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          GestureDetector(
            onTap: onSettings,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 40, height: 40,
              child: Icon(PhosphorIcons.gear(),
                  color: SentioColors.cyan, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero section ──────────────────────────────────────────────────────────────
class _ProfileHero extends StatelessWidget {
  final String  name;
  final String  email;
  final String  initial;
  final String? photoUrl;

  const _ProfileHero({
    required this.name,
    required this.email,
    required this.initial,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Avatar + edit overlay
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kAvatarBg,
                border: Border.all(color: SentioColors.cyan, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: SentioColors.cyan.withValues(alpha: 0.28),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: (photoUrl != null && photoUrl!.isNotEmpty)
                  ? Image.network(photoUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _AvatarInitial(initial))
                  : _AvatarInitial(initial),
            ),
            // Edit button
            Positioned(
              bottom: 2, right: 2,
              child: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: SentioColors.cyan,
                  border: Border.all(color: SentioColors.bgTop, width: 2),
                ),
                child: Icon(PhosphorIcons.pencilSimple(),
                    color: SentioColors.bgTop, size: 14),
              ),
            ),
          ],
        ),
        const SizedBox(width: 20),
        // Name / email / premium
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: GoogleFonts.poppins(
                  color: SentioColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                email,
                style: GoogleFonts.poppins(
                  color: SentioColors.textSecondary,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              _PremiumBadge(),
            ],
          ),
        ),
      ],
    );
  }
}

class _AvatarInitial extends StatelessWidget {
  final String initial;
  const _AvatarInitial(this.initial);

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      initial,
      style: GoogleFonts.poppins(
        color: SentioColors.textPrimary,
        fontSize: 36,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _PremiumBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: SentioColors.cyan.withValues(alpha: 0.55)),
      color: SentioColors.cyan.withValues(alpha: 0.10),
    ),
    child: Text(
      'Premium',
      style: GoogleFonts.poppins(
        color: SentioColors.cyan,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

// ── Stats card ────────────────────────────────────────────────────────────────
class _StatsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _ProfileCard(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
    child: IntrinsicHeight(
      child: Row(
        children: [
          Expanded(child: _StatCol(
            icon: PhosphorIcons.calendarBlank(),
            label: 'Member Since',
            value: 'Jan 15, 2024',
          )),
          _VDiv(),
          Expanded(child: _StatCol(
            icon: PhosphorIcons.chartBar(),
            label: 'Total Sessions',
            value: '24',
          )),
          _VDiv(),
          Expanded(child: _StatCol(
            icon: PhosphorIcons.flame(),
            label: 'Current Streak',
            value: '7 days',
          )),
        ],
      ),
    ),
  );
}

class _StatCol extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;

  const _StatCol({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: SentioColors.cyan, size: 22),
      const SizedBox(height: 8),
      Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          color: SentioColors.textSecondary,
          fontSize: 11,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          color: SentioColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _VDiv extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    color: SentioColors.cardBorder,
  );
}

// ── Account card ──────────────────────────────────────────────────────────────
class _AccountCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _ProfileCard(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        _AccountTile(
          icon: PhosphorIcons.user(),
          label: 'Personal Information',
          subtitle: 'Update your personal details',
          onTap: () {},
        ),
        const _HDivider(),
        _AccountTile(
          icon: PhosphorIcons.shieldCheck(),
          label: 'Security',
          subtitle: 'Change password and security settings',
          onTap: () {},
        ),
        const _HDivider(),
        _AccountTile(
          icon: PhosphorIcons.creditCard(),
          label: 'Subscription',
          subtitle: 'Manage your plan and billing',
          trailing: _InlinePremiumBadge(),
          onTap: () {},
        ),
        const _HDivider(),
        _AccountTile(
          icon: PhosphorIcons.downloadSimple(),
          label: 'Data Export',
          subtitle: 'Download your data and insights',
          onTap: () {},
          last: true,
        ),
      ],
    ),
  );
}

class _AccountTile extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   subtitle;
  final Widget?  trailing;
  final VoidCallback onTap;
  final bool last;

  const _AccountTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: const Radius.circular(24),
        bottom: last ? const Radius.circular(24) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Icon in rounded square
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF0A1724),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SentioColors.cardBorder),
              ),
              child: Icon(icon, color: SentioColors.textSecondary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.poppins(
                    color: SentioColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  )),
                  const SizedBox(height: 2),
                  Text(subtitle, style: GoogleFonts.poppins(
                    color: SentioColors.textSecondary,
                    fontSize: 12,
                  )),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
            const SizedBox(width: 6),
            Icon(PhosphorIcons.caretRight(),
                color: SentioColors.textSecondary, size: 16),
          ],
        ),
      ),
    );
  }
}

class _InlinePremiumBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      gradient: const LinearGradient(
        colors: [SentioColors.cyan, SentioColors.purple],
      ),
    ),
    child: Text(
      'Premium',
      style: GoogleFonts.poppins(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

// ── Connected accounts card ───────────────────────────────────────────────────
class _ConnectedAccountsCard extends StatelessWidget {
  final String email;
  const _ConnectedAccountsCard({required this.email});

  @override
  Widget build(BuildContext context) => _ProfileCard(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        _SocialTile(
          logo: const _GoogleLogo(),
          name: 'Google',
          subtitle: email,
          connected: true,
          onTap: () {},
        ),
        const _HDivider(),
        _SocialTile(
          logo: const _AppleLogo(),
          name: 'Apple',
          subtitle: 'Not connected',
          connected: false,
          onTap: () {},
        ),
        const _HDivider(),
        _SocialTile(
          logo: const _FacebookLogo(),
          name: 'Facebook',
          subtitle: 'Not connected',
          connected: false,
          onTap: () {},
          last: true,
        ),
      ],
    ),
  );
}

class _SocialTile extends StatelessWidget {
  final Widget       logo;
  final String       name;
  final String       subtitle;
  final bool         connected;
  final VoidCallback onTap;
  final bool         last;

  const _SocialTile({
    required this.logo,
    required this.name,
    required this.subtitle,
    required this.connected,
    required this.onTap,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: const Radius.circular(24),
        bottom: last ? const Radius.circular(24) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            SizedBox(width: 42, height: 42, child: logo),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: GoogleFonts.poppins(
                    color: SentioColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  )),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      color: connected
                          ? SentioColors.textSecondary
                          : SentioColors.textMuted,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            connected ? const _ConnectedBadge() : _ConnectButton(onTap: onTap),
          ],
        ),
      ),
    );
  }
}

class _ConnectedBadge extends StatelessWidget {
  const _ConnectedBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: SentioColors.green.withValues(alpha: 0.45)),
      color: SentioColors.green.withValues(alpha: 0.10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_rounded,
            color: SentioColors.green, size: 13),
        const SizedBox(width: 4),
        Text('Connected', style: GoogleFonts.poppins(
          color: SentioColors.green,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        )),
      ],
    ),
  );
}

class _ConnectButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ConnectButton({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SentioColors.cardBorder),
        color: const Color(0xFF0A1724),
      ),
      child: Text('Connect', style: GoogleFonts.poppins(
        color: SentioColors.textPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      )),
    ),
  );
}

// ── Social logo widgets ───────────────────────────────────────────────────────
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) => _LogoContainer(
    child: Text('G', style: GoogleFonts.poppins(
      color: const Color(0xFF4285F4),
      fontSize: 22,
      fontWeight: FontWeight.w700,
    )),
  );
}

class _AppleLogo extends StatelessWidget {
  const _AppleLogo();

  @override
  Widget build(BuildContext context) => const _LogoContainer(
    child: Icon(Icons.apple_rounded, color: Colors.white, size: 26),
  );
}

class _FacebookLogo extends StatelessWidget {
  const _FacebookLogo();

  @override
  Widget build(BuildContext context) => _LogoContainer(
    child: Text('f', style: GoogleFonts.poppins(
      color: const Color(0xFF1877F2),
      fontSize: 26,
      fontWeight: FontWeight.w700,
    )),
  );
}

class _LogoContainer extends StatelessWidget {
  final Widget child;
  const _LogoContainer({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: 42, height: 42,
    decoration: BoxDecoration(
      color: const Color(0xFF0A1724),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: SentioColors.cardBorder),
    ),
    child: Center(child: child),
  );
}

// ── Shared helpers ────────────────────────────────────────────────────────────
class _ProfileCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _ProfileCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: SentioColors.card,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: SentioColors.cardBorder),
      boxShadow: const [
        BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, 4)),
      ],
    ),
    child: child,
  );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

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

class _HDivider extends StatelessWidget {
  const _HDivider();

  @override
  Widget build(BuildContext context) => const Divider(
    height: 1, thickness: 0.5,
    color: SentioColors.cardBorder,
    indent: 16, endIndent: 16,
  );
}
