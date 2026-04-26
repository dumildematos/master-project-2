import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ble_provider.dart';
import '../models/muse_device.dart';
import '../theme/theme.dart';

class MuseScanScreen extends StatelessWidget {
  final VoidCallback onSkip;
  const MuseScanScreen({super.key, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleProvider>();

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(kMd, kXl, kMd, kLg),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: kBorder)),
              ),
              child: Column(children: [
                const Text('SENTIO',
                  style: TextStyle(
                    fontFamily: 'monospace', fontSize: 26, fontWeight: FontWeight.w800,
                    letterSpacing: 6, color: kCyan,
                  )),
                const SizedBox(height: 4),
                const Text('Connect your Muse 2 headset',
                  style: TextStyle(
                    fontFamily: 'monospace', fontSize: 11, color: kMuted, letterSpacing: 2,
                  )),
              ]),
            ),

            Expanded(
              child: switch (ble.state) {
                BLEState.idle       => _IntroPhase(onSkip: onSkip),
                BLEState.scanning   => _ScanningPhase(devices: ble.devices, onSkip: onSkip),
                BLEState.connecting => const _ConnectingPhase(),
                BLEState.connected  => const _ConnectingPhase(), // navigated by parent
                BLEState.error      => _ErrorPhase(error: ble.error, onSkip: onSkip),
                BLEState.disconnected => _IntroPhase(onSkip: onSkip),
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Phase A: Intro ─────────────────────────────────────────────────────────────
class _IntroPhase extends StatelessWidget {
  final VoidCallback onSkip;
  const _IntroPhase({required this.onSkip});

  @override
  Widget build(BuildContext context) {
    final ble = context.read<BleProvider>();
    return _CentreLayout(
      icon: '📡',
      title: 'Find Your Muse 2',
      body:  'Sentio will scan for nearby Muse 2 EEG headsets.\n'
             'Your Bluetooth data is never shared or stored.',
      primaryLabel: 'Start Scanning',
      onPrimary: ble.scan,
      onSkip: onSkip,
    );
  }
}

// ── Phase B: Scanning ─────────────────────────────────────────────────────────
class _ScanningPhase extends StatelessWidget {
  final List<MuseDevice> devices;
  final VoidCallback onSkip;
  const _ScanningPhase({required this.devices, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    final ble = context.read<BleProvider>();
    return Column(
      children: [
        // Status pill
        Padding(
          padding: const EdgeInsets.all(kMd),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: kMd, vertical: kSm),
            decoration: BoxDecoration(
              color: kBg2,
              border: Border.all(color: kCyan.withOpacity(0.33)),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2, color: kCyan,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  devices.isEmpty
                      ? 'Scanning for Muse headsets…'
                      : '${devices.length} headset${devices.length != 1 ? "s" : ""} found',
                  style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 11, color: kCyan, letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Device list or empty hint
        Expanded(
          child: devices.isEmpty
              ? _EmptyHint()
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: kMd),
                  itemCount: devices.length,
                  separatorBuilder: (_, __) => const SizedBox(height: kSm),
                  itemBuilder: (_, i) => _DeviceCard(device: devices[i]),
                ),
        ),

        // Actions bar
        Container(
          padding: const EdgeInsets.fromLTRB(kMd, kMd, kMd, kXl),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: kBorder)),
          ),
          child: Column(children: [
            _OutlineBtn(label: 'Stop Scanning', onTap: ble.stopScan),
            const SizedBox(height: kSm),
            _SkipLink(onSkip: onSkip),
          ]),
        ),
      ],
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final MuseDevice device;
  const _DeviceCard({required this.device});

  Color _rssiColor(int rssi) {
    if (rssi >= -60) return const Color(0xFF4ADE80);
    if (rssi >= -75) return kCyan;
    return kMuted;
  }

  int _signalLevel(int rssi) {
    if (rssi >= -60) return 3;
    if (rssi >= -75) return 2;
    if (rssi >= -90) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final ble   = context.read<BleProvider>();
    final color = _rssiColor(device.rssi);
    final level = _signalLevel(device.rssi);

    return GestureDetector(
      onTap: () => ble.connect(device),
      child: Container(
        padding: const EdgeInsets.all(kMd),
        decoration: BoxDecoration(
          color: kBg2,
          border: Border.all(color: kCyan.withOpacity(0.33)),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: kCyan.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            // Signal bars
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(3, (i) => Container(
                width: 5, height: 6.0 + i * 5,
                margin: const EdgeInsets.only(right: 3),
                decoration: BoxDecoration(
                  color: level > i ? color : kBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              )),
            ),
            const SizedBox(width: kMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(device.name,
                    style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 15,
                      fontWeight: FontWeight.bold, color: kText,
                    )),
                  const SizedBox(height: 3),
                  Text('${device.id} · ${device.rssi} dBm',
                    style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 10, color: kMuted,
                    )),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: kMd, vertical: 6),
              decoration: BoxDecoration(
                color: kCyan, borderRadius: BorderRadius.circular(999),
              ),
              child: const Text('CONNECT',
                style: TextStyle(
                  fontFamily: 'monospace', fontSize: 11,
                  fontWeight: FontWeight.bold, color: kBg, letterSpacing: 1,
                )),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('🎧', style: TextStyle(fontSize: 48)),
        SizedBox(height: kMd),
        Text('No headsets detected',
          style: TextStyle(
            fontFamily: 'monospace', fontSize: 14,
            fontWeight: FontWeight.bold, color: kText,
          )),
        SizedBox(height: kSm),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: kXl),
          child: Text(
            'Power on your Muse 2 and hold\nthe button for 2 s until you hear a beep.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'monospace', fontSize: 12, color: kMuted, height: 1.6,
            )),
        ),
      ],
    ),
  );
}

// ── Phase C: Connecting ────────────────────────────────────────────────────────
class _ConnectingPhase extends StatelessWidget {
  const _ConnectingPhase();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(color: kCyan),
        SizedBox(height: kLg),
        Text('Connecting to Muse 2…',
          style: TextStyle(
            fontFamily: 'monospace', fontSize: 16,
            fontWeight: FontWeight.bold, color: kText, letterSpacing: 2,
          )),
        SizedBox(height: kSm),
        Text('Subscribing to EEG channels',
          style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: kMuted)),
      ],
    ),
  );
}

// ── Error phase ────────────────────────────────────────────────────────────────
class _ErrorPhase extends StatelessWidget {
  final String? error;
  final VoidCallback onSkip;
  const _ErrorPhase({this.error, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    final ble = context.read<BleProvider>();
    return _CentreLayout(
      icon: '⚠️',
      title: 'Connection Error',
      body:  error ?? 'An unexpected error occurred.',
      primaryLabel: 'Try Again',
      onPrimary: ble.scan,
      onSkip: onSkip,
    );
  }
}

// ── Reusable layout ────────────────────────────────────────────────────────────
class _CentreLayout extends StatelessWidget {
  final String icon, title, body, primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onSkip;

  const _CentreLayout({
    required this.icon, required this.title, required this.body,
    required this.primaryLabel, required this.onPrimary, required this.onSkip,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(kXl),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(icon, style: const TextStyle(fontSize: 52)),
        const SizedBox(height: kMd),
        Text(title,
          style: const TextStyle(
            fontFamily: 'monospace', fontSize: 16,
            fontWeight: FontWeight.w700, color: kText,
          ), textAlign: TextAlign.center),
        const SizedBox(height: kSm),
        Text(body,
          style: const TextStyle(
            fontFamily: 'monospace', fontSize: 12, color: kMuted, height: 1.7,
          ), textAlign: TextAlign.center),
        const SizedBox(height: kMd),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onPrimary,
            style: ElevatedButton.styleFrom(
              backgroundColor: kCyan, foregroundColor: kBg,
              padding: const EdgeInsets.symmetric(vertical: kMd),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(
                fontFamily: 'monospace', fontSize: 14,
                fontWeight: FontWeight.bold, letterSpacing: 1,
              ),
            ),
            child: Text(primaryLabel),
          ),
        ),
        const SizedBox(height: kSm),
        _SkipLink(onSkip: onSkip),
      ],
    ),
  );
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlineBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: kMuted,
        side: const BorderSide(color: kBorder),
        padding: const EdgeInsets.symmetric(vertical: kMd),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 13, letterSpacing: 1),
      ),
      child: Text(label),
    ),
  );
}

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
