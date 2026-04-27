import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ble_provider.dart';
import '../models/muse_device.dart';
import '../theme/theme.dart';

class MuseScanScreen extends StatefulWidget {
  final VoidCallback onSkip;
  const MuseScanScreen({super.key, required this.onSkip});

  @override
  State<MuseScanScreen> createState() => _MuseScanScreenState();
}

class _MuseScanScreenState extends State<MuseScanScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _rotateCtrl;
  late final AnimationController _ringCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _rotateCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 4),
    )..repeat();
    _ringCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 2),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BleProvider>().requestPermissions();
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _rotateCtrl.dispose();
    _ringCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ble        = context.watch<BleProvider>();
    final isScanning = ble.state == BLEState.scanning;
    final isConnecting = ble.state == BLEState.connecting;
    final isActive   = isScanning || isConnecting;

    String subtitle;
    if (isConnecting) {
      subtitle = ble.reconnectAttempt > 0
          ? 'RE-ESTABLISHING NEURAL LINK… (${ble.reconnectAttempt}/5)'
          : 'ESTABLISHING NEURAL LINK…';
    } else if (isScanning) {
      subtitle = 'SEARCHING FOR ACTIVE MUSE RECEPTORS…';
    } else if (ble.state == BLEState.error) {
      subtitle = 'CONNECTION FAILED — RETRY OR SKIP';
    } else {
      subtitle = 'READY TO SCAN FOR MUSE 2 HEADSETS';
    }

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kMd),
                  child: Column(
                    children: [
                      const SizedBox(height: kMd),

                      // ── Animated orb ──────────────────────────────────
                      _OrbWidget(
                        pulseCtrl:  _pulseCtrl,
                        rotateCtrl: _rotateCtrl,
                        ringCtrl:   _ringCtrl,
                        isActive:   isActive,
                      ),

                      const SizedBox(height: kLg),

                      // ── Title / subtitle ──────────────────────────────
                      Text(
                        isActive ? 'Neural Syncing' : 'Neural Sync',
                        style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 26,
                          fontWeight: FontWeight.w800, color: kText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 10,
                          color: kMuted, letterSpacing: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: kXl),

                      // ── Discovered devices ────────────────────────────
                      if (ble.devices.isNotEmpty) ...[
                        _SectionHeader(
                          label: 'DISCOVERED DEVICES',
                          badge:
                              '${ble.devices.length} NODE${ble.devices.length != 1 ? "S" : ""} DETECTED',
                        ),
                        const SizedBox(height: kMd),
                        for (final d in ble.devices)
                          Padding(
                            padding: const EdgeInsets.only(bottom: kMd),
                            child: _DeviceCard(
                              device:      d,
                              isConnected: ble.connectedDevice?.id == d.id,
                              onConnect:   () => ble.connect(d),
                            ),
                          ),
                      ],

                      // ── Error card ────────────────────────────────────
                      if (ble.state == BLEState.error && ble.error != null) ...[
                        _ErrorCard(error: ble.error!),
                        const SizedBox(height: kMd),
                      ],

                      // ── Bottom status cards (scanning only) ───────────
                      if (isScanning) ...[
                        _StatusCard(
                          icon:     Icons.radar,
                          label:    'SYNC INTEGRITY',
                          subtitle: 'Scanning for Muse 2 headsets…',
                          trailing: _ScanSpinner(),
                        ),
                        const SizedBox(height: kSm),
                        _StatusCard(
                          icon:     Icons.hub_outlined,
                          label:    'MESH NETWORK',
                          subtitle: 'BLE scanning active.',
                          trailing: const Icon(Icons.check_circle, color: kCyan, size: 22),
                        ),
                        const SizedBox(height: kMd),
                        _SkipLink(onSkip: widget.onSkip),
                      ],

                      // ── Primary action (idle / error) ─────────────────
                      if (!isScanning && !isConnecting) ...[
                        _PrimaryButton(
                          label: ble.state == BLEState.error
                              ? 'RETRY SCAN'
                              : 'START SCANNING',
                          onTap: ble.scan,
                        ),
                        const SizedBox(height: kSm),
                        _SkipLink(onSkip: widget.onSkip),
                      ],

                      const SizedBox(height: kXl),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Top bar ────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kMd, vertical: kMd),
      child: Row(
        children: const [
          Icon(Icons.settings_input_antenna, color: kCyan, size: 18),
          SizedBox(width: 8),
          Text('SENTIO',
            style: TextStyle(
              fontFamily: 'monospace', fontSize: 15,
              fontWeight: FontWeight.w800, color: kCyan, letterSpacing: 4,
            )),
        ],
      ),
    );
  }
}

// ── Animated BLE orb ───────────────────────────────────────────────────────────
class _OrbWidget extends StatelessWidget {
  final AnimationController pulseCtrl;
  final AnimationController rotateCtrl;
  final AnimationController ringCtrl;
  final bool isActive;

  const _OrbWidget({
    required this.pulseCtrl,
    required this.rotateCtrl,
    required this.ringCtrl,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final orbSize = screenW * 0.72;

    return SizedBox(
      width: orbSize, height: orbSize,
      child: AnimatedBuilder(
        animation: Listenable.merge([pulseCtrl, rotateCtrl, ringCtrl]),
        builder: (context, _) {
          final pulse  = pulseCtrl.value;       // 0 → 1 → 0
          final rotate = rotateCtrl.value;      // 0 → 1 (full rotation)
          final ring   = ringCtrl.value;        // 0 → 1 (expand + fade)

          return Stack(
            alignment: Alignment.center,
            children: [
              // Expanding ring burst
              if (isActive)
                Opacity(
                  opacity: (1.0 - ring).clamp(0, 1) * 0.25,
                  child: Transform.scale(
                    scale: 0.55 + ring * 0.55,
                    child: _Ring(color: kCyan, width: 1.0, fraction: 1.0),
                  ),
                ),

              // Outer static ring
              Opacity(
                opacity: isActive ? 0.12 + pulse * 0.08 : 0.06,
                child: Transform.scale(
                  scale: isActive ? 0.95 + pulse * 0.04 : 0.95,
                  child: _Ring(color: kCyan, width: 1.0, fraction: 1.0),
                ),
              ),

              // Mid ring
              Opacity(
                opacity: isActive ? 0.18 + pulse * 0.12 : 0.09,
                child: Transform.scale(
                  scale: 0.72,
                  child: _Ring(color: kCyan, width: 1.0, fraction: 1.0),
                ),
              ),

              // Rotating arc (active only)
              if (isActive)
                Transform.rotate(
                  angle: rotate * 2 * pi,
                  child: SizedBox(
                    width: orbSize * 0.72, height: orbSize * 0.72,
                    child: CustomPaint(painter: _ArcPainter(color: kCyan)),
                  ),
                ),

              // Inner glow blob
              if (isActive)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: orbSize * 0.52,
                  height: orbSize * 0.52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: kCyan.withOpacity(0.06 + pulse * 0.06),
                        blurRadius: 40 + pulse * 20,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),

              // Centre circle
              Container(
                width: orbSize * 0.38, height: orbSize * 0.38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kBg2,
                  border: Border.all(
                    color: kCyan.withOpacity(isActive ? 0.45 + pulse * 0.3 : 0.25),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.bluetooth,
                  color: kCyan.withOpacity(isActive ? 0.75 + pulse * 0.25 : 0.5),
                  size: orbSize * 0.14,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  final Color color;
  final double width;
  final double fraction;
  const _Ring({required this.color, required this.width, required this.fraction});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: width),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final Color color;
  const _ArcPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect   = Offset.zero & size;
    final paint  = Paint()
      ..color       = color.withOpacity(0.55)
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap   = StrokeCap.round;
    canvas.drawArc(rect, 0, pi * 0.7, false, paint);

    final paint2 = Paint()
      ..color       = color.withOpacity(0.25)
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap   = StrokeCap.round;
    canvas.drawArc(rect, pi, pi * 0.5, false, paint2);
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.color != color;
}

// ── Section header ─────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  final String badge;
  const _SectionHeader({required this.label, required this.badge});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          Container(
            width: 3, height: 16,
            color: kCyan,
            margin: const EdgeInsets.only(right: 8),
          ),
          Text(label,
            style: const TextStyle(
              fontFamily: 'monospace', fontSize: 11,
              fontWeight: FontWeight.bold, color: kCyan, letterSpacing: 1.5,
            )),
        ]),
        Text(badge,
          style: const TextStyle(
            fontFamily: 'monospace', fontSize: 10,
            color: kCyan, letterSpacing: 1,
          )),
      ],
    );
  }
}

// ── Device card ────────────────────────────────────────────────────────────────
class _DeviceCard extends StatelessWidget {
  final MuseDevice device;
  final bool isConnected;
  final VoidCallback onConnect;
  const _DeviceCard({
    required this.device,
    required this.isConnected,
    required this.onConnect,
  });

  String _signalLabel(int rssi) {
    if (rssi >= -60) return 'OPTIMAL LINKAGE';
    if (rssi >= -70) return 'GOOD SIGNAL';
    if (rssi >= -80) return 'READY TO PAIR';
    return 'WEAK INTERFERENCE';
  }

  Color _signalColor(int rssi) {
    if (rssi >= -60) return kCyan;
    if (rssi >= -70) return const Color(0xFF52B788);
    if (rssi >= -80) return kMuted;
    return kMuted.withOpacity(0.5);
  }

  _BadgeKind _badge() {
    if (isConnected) return _BadgeKind.connected;
    if (device.rssi >= -75) return _BadgeKind.nearby;
    return _BadgeKind.lowSignal;
  }

  @override
  Widget build(BuildContext context) {
    final kind   = _badge();
    final dimmed = kind == _BadgeKind.lowSignal;

    return Container(
      decoration: BoxDecoration(
        color:  kBg2,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left:   BorderSide(color: isConnected ? kCyan : kBorder, width: isConnected ? 3 : 1),
          top:    const BorderSide(color: kBorder, width: 1),
          right:  const BorderSide(color: kBorder, width: 1),
          bottom: const BorderSide(color: kBorder, width: 1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(kMd),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: kBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isConnected ? kCyan.withOpacity(0.45) : kBorder,
                ),
              ),
              child: Icon(
                Icons.headphones,
                size:  22,
                color: isConnected ? kCyan : dimmed ? kMuted.withOpacity(0.4) : kMuted,
              ),
            ),

            const SizedBox(width: kMd),

            // Name + signal
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(device.name,
                          style: TextStyle(
                            fontFamily: 'monospace', fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: dimmed ? kMuted : kText,
                          )),
                      ),
                      _BadgeWidget(kind: kind),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(children: [
                    Icon(Icons.signal_cellular_alt,
                      size: 12, color: _signalColor(device.rssi)),
                    const SizedBox(width: 4),
                    Text(_signalLabel(device.rssi),
                      style: TextStyle(
                        fontFamily: 'monospace', fontSize: 10,
                        color: _signalColor(device.rssi), letterSpacing: 0.8,
                      )),
                  ]),
                ],
              ),
            ),

            // Connect button (hidden when already connected)
            if (!isConnected) ...[
              const SizedBox(width: kSm),
              GestureDetector(
                onTap: onConnect,
                child: Container(
                  width: 40, height: 40,
                  decoration: const BoxDecoration(
                    color: kCyan, shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow, color: kBg, size: 22),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _BadgeKind { connected, nearby, lowSignal }

class _BadgeWidget extends StatelessWidget {
  final _BadgeKind kind;
  const _BadgeWidget({required this.kind});

  @override
  Widget build(BuildContext context) {
    final label = switch (kind) {
      _BadgeKind.connected => 'CONNECTED',
      _BadgeKind.nearby    => 'NEARBY',
      _BadgeKind.lowSignal => 'LOW SIGNAL',
    };
    final isSolid = kind == _BadgeKind.connected;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:  isSolid ? kCyan : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: isSolid ? null : Border.all(color: kBorder),
      ),
      child: Text(label,
        style: TextStyle(
          fontFamily: 'monospace', fontSize: 9,
          fontWeight: FontWeight.bold, letterSpacing: 0.5,
          color: isSolid ? kBg : kMuted,
        )),
    );
  }
}

// ── Error card ─────────────────────────────────────────────────────────────────
class _ErrorCard extends StatelessWidget {
  final String error;
  const _ErrorCard({required this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(kMd),
      decoration: BoxDecoration(
        color: kBg2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kAmber.withOpacity(0.4)),
      ),
      child: Row(children: [
        Icon(Icons.warning_amber_rounded, color: kAmber, size: 22),
        const SizedBox(width: kMd),
        Expanded(
          child: Text(error,
            style: const TextStyle(
              fontFamily: 'monospace', fontSize: 11, color: kAmber,
            )),
        ),
      ]),
    );
  }
}

// ── Status card (bottom section) ───────────────────────────────────────────────
class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   subtitle;
  final Widget   trailing;
  const _StatusCard({
    required this.icon, required this.label,
    required this.subtitle, required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(kMd),
      decoration: BoxDecoration(
        color: kBg2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: kCyan.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: kCyan, size: 20),
        ),
        const SizedBox(width: kMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 12,
                  fontWeight: FontWeight.bold, color: kText, letterSpacing: 1,
                )),
              const SizedBox(height: 3),
              Text(subtitle,
                style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 11, color: kMuted,
                )),
            ],
          ),
        ),
        trailing,
      ]),
    );
  }
}

class _ScanSpinner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 28, height: 28,
    child: CircularProgressIndicator(strokeWidth: 2.5, color: kCyan),
  );
}

// ── Primary action button ──────────────────────────────────────────────────────
class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: kCyan, foregroundColor: kBg,
          padding: const EdgeInsets.symmetric(vertical: kMd),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
            fontFamily: 'monospace', fontSize: 13,
            fontWeight: FontWeight.bold, letterSpacing: 2,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

// ── Skip link ──────────────────────────────────────────────────────────────────
class _SkipLink extends StatelessWidget {
  final VoidCallback onSkip;
  const _SkipLink({required this.onSkip});

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onSkip,
    child: const Text(
      'Skip — use backend Bluetooth instead',
      style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: kMuted),
    ),
  );
}
