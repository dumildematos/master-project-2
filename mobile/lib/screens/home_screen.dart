import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/ble_provider.dart';
import '../providers/sentio_provider.dart';
import '../theme/theme.dart';
import '../widgets/emotion_ring.dart';
import 'live_brainwaves_screen.dart';
import 'led_display_screen.dart';
import 'session_screen.dart';
import 'settings_screen.dart';

const kBg = SentioColors.bgTop;
const kBg2 = SentioColors.card;
const kBorder = SentioColors.cardBorder;
const kText = SentioColors.textPrimary;
const kMuted = SentioColors.textMuted;
const kCyan = SentioColors.cyan;
const kPurple = SentioColors.purple;
const kGreen = SentioColors.green;
const kAmber = SentioColors.yellow;
const kRed = SentioColors.red;
const kBlue = Color(0xFF3B82F6);

const kSm = 12.0;
const kMd = 16.0;
const kXl = 28.0;

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleProvider>();
    final sentio = context.watch<SentioProvider>();
    final data = sentio.data;
    final isConn = ble.state == BLEState.connected;

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kMd, vertical: kSm),
              child: Row(
                children: [
                  const Icon(Icons.menu, color: kText, size: 22),
                  const SizedBox(width: kMd),
                  const Expanded(
                    child: Text(
                      'Dashboard',
                      style: TextStyle(
                        color: kText,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: kMuted),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: kMd),
                child: Column(
                  children: [
                    _ConnectionCard(isConnected: isConn, ble: ble),
                    const SizedBox(height: kMd),
                    _StateCard(data: data),
                    const SizedBox(height: kMd),
                    const _QuickActions(),
                    const SizedBox(height: kMd),
                    _BrainwavesTeaser(sentio: sentio),
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

class _ConnectionCard extends StatelessWidget {
  final bool isConnected;
  final BleProvider ble;

  const _ConnectionCard({
    required this.isConnected,
    required this.ble,
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
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (isConnected ? kCyan : kMuted).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.earbuds_outlined,
              color: isConnected ? kCyan : kMuted,
              size: 22,
            ),
          ),
          const SizedBox(width: kMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ble.connectedDevice?.name ?? 'Muse 2',
                  style: const TextStyle(
                    color: kText,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isConnected ? kGreen : kMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isConnected ? 'Connected' : 'Not connected',
                      style: TextStyle(
                        color: isConnected ? kGreen : kMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isConnected) const _BatteryWidget(pct: 90),
        ],
      ),
    );
  }
}

class _BatteryWidget extends StatelessWidget {
  final int pct;

  const _BatteryWidget({required this.pct});

  @override
  Widget build(BuildContext context) {
    final fillWidth = (23.0 * pct / 100).clamp(0.0, 23.0).toDouble();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 31,
          height: 13,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                width: 26,
                height: 13,
                decoration: BoxDecoration(
                  border: Border.all(color: kMuted, width: 1.2),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Positioned(
                left: 1.5,
                top: 1.5,
                child: Container(
                  width: fillWidth,
                  height: 10,
                  decoration: BoxDecoration(
                    color: pct > 50 ? kGreen : pct > 20 ? kAmber : kRed,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Positioned(
                right: 1,
                child: Container(
                  width: 3,
                  height: 6,
                  decoration: BoxDecoration(
                    color: kMuted,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$pct%',
          style: const TextStyle(color: kMuted, fontSize: 12),
        ),
      ],
    );
  }
}

class _StateCard extends StatelessWidget {
  final dynamic data;

  const _StateCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final emotion = data.emotion as String;
    final conf = data.confidence as double;
    final color = emotionColor(emotion);

    return Container(
      padding: const EdgeInsets.all(kMd),
      decoration: BoxDecoration(
        color: kBg2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Current State',
              style: TextStyle(
                color: kMuted,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: kMd),
          EmotionRing(
            emotion: emotion,
            confidence: conf / 100,
            size: 140,
          ),
          const SizedBox(height: kMd),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LiveBrainwavesScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: kMd, vertical: kSm),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Text(
                'View Live Brainwaves →',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: kSm),
          if (data.aiGuidance != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                data.aiGuidance!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: kMuted,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            const Text(
              'Wear your mind.',
              style: TextStyle(
                color: kCyan,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(color: kMuted, fontSize: 12, letterSpacing: 0.5),
        ),
        const SizedBox(height: kSm),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: kCyan,
              foregroundColor: kBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.play_circle_outline, size: 20),
            label: const Text(
              'Start Session',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SessionScreen()),
              );
            },
          ),
        ),
        const SizedBox(height: kSm),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPurple,
              foregroundColor: kText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.grid_view_outlined, size: 20),
            label: const Text(
              'LED Display',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LedDisplayScreen()),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BrainwavesTeaser extends StatelessWidget {
  final SentioProvider sentio;

  const _BrainwavesTeaser({required this.sentio});

  @override
  Widget build(BuildContext context) {
    final data = sentio.data;

    final bands = <_BandData>[
      _BandData('Delta', data.delta as double, kPurple),
      _BandData('Theta', data.theta as double, kBlue),
      _BandData('Alpha', data.alpha as double, kCyan),
      _BandData('Beta', data.beta as double, kGreen),
      _BandData('Gamma', data.gamma as double, kAmber),
    ];

    return Container(
      padding: const EdgeInsets.all(kMd),
      decoration: BoxDecoration(
        color: kBg2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Brainwave Summary',
                  style: TextStyle(
                    color: kText,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LiveBrainwavesScreen()),
                  );
                },
                child: const Text(
                  'See all →',
                  style: TextStyle(color: kCyan, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: kMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: bands
                .map(
                  (band) => _BandChip(
                    label: band.label,
                    value: band.value,
                    color: band.color,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _BandData {
  final String label;
  final double value;
  final Color color;

  const _BandData(this.label, this.value, this.color);
}

class _BandChip extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _BandChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final safeValue = value.clamp(0.0, 1.0).toDouble();
    final pct = (safeValue * 100).round();

    return Column(
      children: [
        Text(
          '$pct%',
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: kMuted, fontSize: 10),
        ),
        const SizedBox(height: 4),
        Container(
          width: 3,
          height: 20,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [color.withOpacity(0.2), color],
              stops: [0.0, safeValue.clamp(0.1, 1.0).toDouble()],
            ),
          ),
        ),
      ],
    );
  }
}