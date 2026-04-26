import 'package:flutter/material.dart';
import '../theme/theme.dart';

class ConnectionBanner extends StatelessWidget {
  final bool connected;
  final bool hasSignal;

  const ConnectionBanner({
    super.key, required this.connected, required this.hasSignal,
  });

  @override
  Widget build(BuildContext context) {
    if (connected && hasSignal) return const SizedBox.shrink();
    final isWaiting = connected && !hasSignal;
    final dotColor  = isWaiting ? kAmber : kMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: kMd),
      padding: const EdgeInsets.all(kSm),
      decoration: BoxDecoration(
        color: kBg2,
        border: Border.all(color: isWaiting ? kAmber.withOpacity(0.27) : kBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Container(
              width: 8, height: 8,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  !connected
                      ? 'Not connected — check backend address in Settings'
                      : 'Connected · no EEG stream active',
                  style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 12, color: kText,
                  ),
                ),
                if (isWaiting) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Start a session from the web dashboard or use Demo Mode.',
                    style: TextStyle(
                      fontFamily: 'monospace', fontSize: 11, color: kMuted,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
