import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/scanned_device.dart';
import '../providers/ble_provider.dart';
import '../theme/theme.dart';

// ── Design tokens (local) ──────────────────────────────────────────────────────
const _kBg        = SentioColors.bgTop;
const _kCard      = SentioColors.card;
const _kBorder    = SentioColors.cardBorder;
const _kCyan      = SentioColors.cyan;
const _kGreen     = SentioColors.green;
const _kRed       = SentioColors.red;
const _kText      = SentioColors.textPrimary;
const _kMuted     = SentioColors.textSecondary;
const _kPurple    = SentioColors.purple;
const _kAmber     = SentioColors.yellow;

// ══════════════════════════════════════════════════════════════════════════════
// ConnectDeviceScreen
// ══════════════════════════════════════════════════════════════════════════════
class ConnectDeviceScreen extends StatefulWidget {
  const ConnectDeviceScreen({super.key});

  @override
  State<ConnectDeviceScreen> createState() => _ConnectDeviceScreenState();
}

class _ConnectDeviceScreenState extends State<ConnectDeviceScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowCtrl;
  final Set<String> _connecting = {};
  StreamSubscription<BluetoothAdapterState>? _btStateSub;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBluetoothAndScan();
    });

    _btStateSub = FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.off && mounted) {
        _showBluetoothOffDialog();
      }
    });
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _btStateSub?.cancel();
    super.dispose();
  }

  Future<void> _checkBluetoothAndScan() async {
    final state = await FlutterBluePlus.adapterState.first;
    if (!mounted) return;
    if (state == BluetoothAdapterState.off) {
      _showBluetoothOffDialog();
    } else {
      context.read<BleProvider>().startScan();
    }
  }

  void _showBluetoothOffDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _kBorder),
        ),
        title: Text(
          'Bluetooth is Off',
          style: GoogleFonts.poppins(color: _kText, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Please enable Bluetooth to scan for nearby devices.',
          style: GoogleFonts.poppins(color: _kMuted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: _kMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // On Android, FlutterBluePlus can request BT be turned on.
              if (Theme.of(context).platform == TargetPlatform.android) {
                FlutterBluePlus.turnOn();
              }
            },
            child: Text('Enable',
                style: GoogleFonts.poppins(
                    color: _kCyan, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleConnect(BleProvider ble, ScannedDevice device) async {
    final id = device.device.remoteId.str;
    setState(() => _connecting.add(id));
    try {
      await ble.connectToDevice(device.device);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Connection failed: ${e.toString().replaceAll('Exception: ', '')}',
            style: GoogleFonts.poppins(color: _kText, fontSize: 13),
          ),
          backgroundColor: _kRed.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _connecting.remove(id));
    }
  }

  Future<void> _handleDisconnect(BleProvider ble, ScannedDevice device) async {
    await ble.disconnectDevice(device.device);
  }

  void _openMacSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SentioColors.cardAlt,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _MacConnectSheet(
        onConnect: (mac) => context.read<BleProvider>().connectByMac(mac),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleProvider>();

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: kMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: kLg),

                    // ── Bluetooth hero ─────────────────────────────────────
                    Center(
                      child: _BluetoothHero(
                        glowCtrl: _glowCtrl,
                        isScanning: ble.isScanning,
                      ),
                    ),

                    const SizedBox(height: kLg),

                    // ── Scan status card ───────────────────────────────────
                    _ScanStatusCard(
                      isScanning: ble.isScanning,
                      onRefresh: () => ble.startScan(),
                    ),

                    const SizedBox(height: kMd),

                    // ── Connect by MAC ─────────────────────────────────────
                    _MacAddressButton(onTap: _openMacSheet),

                    const SizedBox(height: kLg),

                    // ── Device list ────────────────────────────────────────
                    if (ble.discoveredDevices.isNotEmpty) ...[
                      _SectionLabel('Available Devices',
                          badge: '${ble.discoveredDevices.length} found'),
                      const SizedBox(height: kMd),
                      for (final device in ble.discoveredDevices)
                        Padding(
                          padding: const EdgeInsets.only(bottom: kMd),
                          child: _DeviceCard(
                            device: device,
                            isConnected: ble.isDeviceConnected(device.device),
                            isConnecting: _connecting
                                .contains(device.device.remoteId.str),
                            onConnect: () => _handleConnect(ble, device),
                            onDisconnect: () => _handleDisconnect(ble, device),
                          ),
                        ),
                    ] else if (!ble.isScanning) ...[
                      const _EmptyState(),
                      const SizedBox(height: kLg),
                    ],

                    const SizedBox(height: kLg),

                    // ── Help section ───────────────────────────────────────
                    const _SectionLabel('Help'),
                    const SizedBox(height: kMd),
                    const _HelpSection(),

                    const SizedBox(height: kXl),
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

// ══════════════════════════════════════════════════════════════════════════════
// Header
// ══════════════════════════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: _kText, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Text(
              'Connect Device',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: _kText,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline_rounded,
                color: _kMuted, size: 22),
            onPressed: () => _showHelpSheet(context),
          ),
        ],
      ),
    );
  }

  void _showHelpSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: SentioColors.cardAlt,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _kBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Pairing Tips',
                style: GoogleFonts.poppins(
                    color: _kText,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            const _TipRow(icon: Icons.power_settings_new_rounded,
                text: 'Power on your device before scanning.'),
            const _TipRow(icon: Icons.bluetooth_rounded,
                text: 'Make sure the device is in pairing mode.'),
            const _TipRow(icon: Icons.location_on_outlined,
                text: 'Location permission is required for BLE scanning on Android.'),
            const _TipRow(icon: Icons.refresh_rounded,
                text: 'Tap Refresh if your device doesn\'t appear.'),
          ],
        ),
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _TipRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _kCyan, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: GoogleFonts.poppins(color: _kMuted, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Bluetooth Hero
// ══════════════════════════════════════════════════════════════════════════════
class _BluetoothHero extends StatelessWidget {
  final AnimationController glowCtrl;
  final bool isScanning;

  const _BluetoothHero({
    required this.glowCtrl,
    required this.isScanning,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glowCtrl,
      builder: (_, __) {
        final t = glowCtrl.value; // 0.0 → 1.0 → 0.0
        return Column(
          children: [
            // Glowing Bluetooth orb
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kCard,
                border: Border.all(
                  color: _kCyan.withValues(
                      alpha: isScanning ? 0.35 + t * 0.45 : 0.20),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _kCyan.withValues(
                        alpha: isScanning ? 0.08 + t * 0.18 : 0.04),
                    blurRadius: isScanning ? 32 + t * 24 : 16,
                    spreadRadius: isScanning ? 4 + t * 4 : 2,
                  ),
                ],
              ),
              child: Icon(
                Icons.bluetooth_rounded,
                size: 50,
                color: _kCyan.withValues(
                    alpha: isScanning ? 0.65 + t * 0.35 : 0.45),
              ),
            ),

            const SizedBox(height: kLg),

            Text(
              'Scan for Bluetooth Devices',
              style: GoogleFonts.poppins(
                color: _kText,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Make sure your device is powered on\nand in pairing mode',
              style: GoogleFonts.poppins(color: _kMuted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Scan status card
// ══════════════════════════════════════════════════════════════════════════════
class _ScanStatusCard extends StatelessWidget {
  final bool isScanning;
  final VoidCallback onRefresh;

  const _ScanStatusCard({
    required this.isScanning,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: kMd, vertical: 14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isScanning
              ? _kCyan.withValues(alpha: 0.30)
              : _kBorder,
        ),
      ),
      child: Row(
        children: [
          // Icon / spinner
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _kCyan.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: isScanning
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: _kCyan),
                  )
                : const Icon(Icons.bluetooth_searching_rounded,
                    color: _kCyan, size: 20),
          ),
          const SizedBox(width: kMd),

          // Status text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isScanning
                      ? 'Scanning for devices...'
                      : 'Tap Refresh to scan again',
                  style: GoogleFonts.poppins(
                    color: _kText,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isScanning)
                  Text(
                    'Scan runs for 10 seconds',
                    style: GoogleFonts.poppins(color: _kMuted, fontSize: 11),
                  ),
              ],
            ),
          ),

          // Refresh button (only when idle)
          if (!isScanning)
            GestureDetector(
              onTap: onRefresh,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: _kCyan.withValues(alpha: 0.40)),
                  borderRadius: BorderRadius.circular(10),
                  color: _kCyan.withValues(alpha: 0.08),
                ),
                child: const Icon(Icons.refresh_rounded,
                    color: _kCyan, size: 18),
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Section label
// ══════════════════════════════════════════════════════════════════════════════
class _SectionLabel extends StatelessWidget {
  final String label;
  final String? badge;

  const _SectionLabel(this.label, {this.badge});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 16, color: _kCyan,
            margin: const EdgeInsets.only(right: 8)),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.poppins(
            color: _kCyan,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        if (badge != null) ...[
          const Spacer(),
          Text(badge!,
              style: GoogleFonts.poppins(color: _kMuted, fontSize: 11)),
        ],
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Device card
// ══════════════════════════════════════════════════════════════════════════════
class _DeviceCard extends StatelessWidget {
  final ScannedDevice device;
  final bool isConnected;
  final bool isConnecting;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const _DeviceCard({
    required this.device,
    required this.isConnected,
    required this.isConnecting,
    required this.onConnect,
    required this.onDisconnect,
  });

  IconData get _icon => switch (device.kind) {
        BleDeviceKind.muse => Icons.headphones_rounded,
        BleDeviceKind.sentioHat => Icons.hardware_rounded,
        BleDeviceKind.other => Icons.bluetooth_rounded,
      };

  Color get _accentColor => switch (device.kind) {
        BleDeviceKind.muse => _kCyan,
        BleDeviceKind.sentioHat => _kPurple,
        BleDeviceKind.other => _kMuted,
      };

  Color get _signalColor => switch (device.signalLabel) {
        'Strong' => _kGreen,
        'Medium' => _kAmber,
        _ => _kMuted,
      };

  IconData get _signalIcon => switch (device.signalLabel) {
        'Strong' => Icons.signal_cellular_4_bar_rounded,
        'Medium' => Icons.signal_cellular_alt_2_bar_rounded,
        _ => Icons.signal_cellular_alt_1_bar_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final accent = isConnected ? _kGreen : _accentColor;

    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(
              color: isConnected ? _kGreen : _kBorder,
              width: isConnected ? 3 : 1),
          top: const BorderSide(color: _kBorder),
          right: const BorderSide(color: _kBorder),
          bottom: const BorderSide(color: _kBorder),
        ),
        boxShadow: isConnected
            ? [
                BoxShadow(
                  color: _kGreen.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      padding: const EdgeInsets.all(kMd),
      child: Row(
        children: [
          // Device icon
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withValues(alpha: 0.28)),
            ),
            child: Icon(_icon, color: accent, size: 24),
          ),

          const SizedBox(width: kMd),

          // Device info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + connected badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        device.name,
                        style: GoogleFonts.poppins(
                          color: _kText,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isConnected)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _kGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                              color: _kGreen.withValues(alpha: 0.40)),
                        ),
                        child: Text(
                          'Connected',
                          style: GoogleFonts.poppins(
                            color: _kGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 3),

                // Device type
                Text(
                  device.kind.typeLabel,
                  style: GoogleFonts.poppins(color: _kMuted, fontSize: 12),
                ),

                const SizedBox(height: 5),

                // Signal strength
                Row(
                  children: [
                    Icon(_signalIcon, color: _signalColor, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      device.signalLabel,
                      style: GoogleFonts.poppins(
                          color: _signalColor, fontSize: 11),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${device.rssi} dBm',
                      style: GoogleFonts.poppins(
                          color: _kMuted.withValues(alpha: 0.6), fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: kSm),

          // Action button
          if (isConnecting)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: _kCyan),
            )
          else if (isConnected)
            _OutlineButton(
              label: 'Disconnect',
              color: _kRed,
              onTap: onDisconnect,
            )
          else
            _OutlineButton(
              label: 'Connect',
              color: _kCyan,
              onTap: onConnect,
            ),
        ],
      ),
    );
  }
}

// ── Outlined action button ─────────────────────────────────────────────────────
class _OutlineButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _OutlineButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.55)),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Empty state
// ══════════════════════════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: kMd),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.bluetooth_disabled_rounded,
              color: _kMuted.withValues(alpha: 0.45), size: 40),
          const SizedBox(height: 12),
          Text(
            'No devices found',
            style: GoogleFonts.poppins(
                color: _kText, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Make sure your device is powered on\nand in pairing mode, then tap Refresh.',
            style: GoogleFonts.poppins(color: _kMuted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Help section
// ══════════════════════════════════════════════════════════════════════════════
class _HelpSection extends StatelessWidget {
  const _HelpSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          _HelpRow(
            icon: Icons.help_outline_rounded,
            label: 'Pairing Help',
            onTap: () => _showPairingHelp(context),
          ),
          const Divider(height: 1, thickness: 0.5,
              color: SentioColors.cardBorder),
          _HelpRow(
            icon: Icons.settings_bluetooth_rounded,
            label: 'Bluetooth Settings',
            onTap: () {
              // flutter_blue_plus can open adapter settings on Android
              if (Theme.of(context).platform == TargetPlatform.android) {
                FlutterBluePlus.turnOn();
              }
            },
          ),
        ],
      ),
    );
  }

  void _showPairingHelp(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: SentioColors.cardAlt,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: _kBorder,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text('Muse 2',
                style: GoogleFonts.poppins(
                    color: _kCyan,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Hold the power button for 2 seconds until the LED pulses. '
              'The device name starts with "Muse".',
              style: GoogleFonts.poppins(color: _kMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Text('SENTIO Hat',
                style: GoogleFonts.poppins(
                    color: _kPurple,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Power on the hat and wait for the LED to flash blue. '
              'The device will appear as "SENTIO Hat".',
              style: GoogleFonts.poppins(color: _kMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HelpRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: kMd, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: _kMuted, size: 20),
            const SizedBox(width: kMd),
            Expanded(
              child: Text(label,
                  style: GoogleFonts.poppins(color: _kText, fontSize: 14)),
            ),
            const Icon(Icons.chevron_right_rounded, color: _kMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Connect via MAC address button
// ══════════════════════════════════════════════════════════════════════════════
class _MacAddressButton extends StatelessWidget {
  final VoidCallback onTap;
  const _MacAddressButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: kMd, vertical: 14),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kCyan.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _kCyan.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.link_rounded, color: _kCyan, size: 18),
            ),
            const SizedBox(width: kMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connect via MAC Address',
                    style: GoogleFonts.poppins(
                      color: _kText,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Already know the device address?',
                    style: GoogleFonts.poppins(color: _kMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _kMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MAC address bottom sheet
// ══════════════════════════════════════════════════════════════════════════════
class _MacConnectSheet extends StatefulWidget {
  final Future<void> Function(String mac) onConnect;
  const _MacConnectSheet({required this.onConnect});

  @override
  State<_MacConnectSheet> createState() => _MacConnectSheetState();
}

class _MacConnectSheetState extends State<_MacConnectSheet> {
  final _ctrl = TextEditingController();
  String? _error;
  bool _isConnecting = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String? _validate(String mac) {
    if (mac.isEmpty) return 'Enter a MAC address';
    if (!isValidMac(mac)) return 'Invalid format — use AA:BB:CC:DD:EE:FF';
    return null;
  }

  Future<void> _connect() async {
    final mac = _ctrl.text.trim().toUpperCase();
    final err = _validate(mac);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _error = null;
      _isConnecting = true;
    });
    try {
      await widget.onConnect(mac);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Connection failed — make sure the device is on and nearby';
          _isConnecting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24, 16, 24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: _kBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Row(
            children: [
              const Icon(Icons.link_rounded, color: _kCyan, size: 20),
              const SizedBox(width: 8),
              Text(
                'Connect via MAC Address',
                style: GoogleFonts.poppins(
                  color: _kText,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Enter the Bluetooth MAC address of your device.',
            style: GoogleFonts.poppins(color: _kMuted, fontSize: 12),
          ),
          const SizedBox(height: 20),

          // Input
          TextField(
            controller: _ctrl,
            enabled: !_isConnecting,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            style: GoogleFonts.robotoMono(
              color: _kText,
              fontSize: 15,
              letterSpacing: 1.2,
            ),
            decoration: InputDecoration(
              hintText: 'AA:BB:CC:DD:EE:FF',
              hintStyle: GoogleFonts.robotoMono(
                color: _kMuted.withValues(alpha: 0.45),
                fontSize: 15,
              ),
              errorText: _error,
              errorStyle: GoogleFonts.poppins(color: _kRed, fontSize: 11),
              errorMaxLines: 2,
              filled: true,
              fillColor: SentioColors.bgTop,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kCyan, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kRed),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kRed, width: 1.5),
              ),
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _connect(),
          ),
          const SizedBox(height: 16),

          // Connect button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isConnecting ? null : _connect,
              style: FilledButton.styleFrom(
                backgroundColor: _kCyan,
                disabledBackgroundColor: _kCyan.withValues(alpha: 0.35),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isConnecting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Connect',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
