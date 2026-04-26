import 'package:flutter/material.dart';
import '../theme/theme.dart';

class StatItem {
  final String label;
  final String? value;
  final String unit;
  final Color? color;

  const StatItem({
    required this.label, this.value, this.unit = '', this.color,
  });
}

class StatRow extends StatelessWidget {
  final List<StatItem> items;
  const StatRow({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: items.map((item) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(
              right: items.last == item ? 0 : kSm,
            ),
            padding: const EdgeInsets.all(kSm),
            decoration: BoxDecoration(
              color: kBg2,
              border: Border.all(color: kBorder),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  item.label,
                  style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 9,
                    color: kMuted, letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.value != null ? '${item.value}${item.unit}' : '—',
                  style: TextStyle(
                    fontFamily: 'monospace', fontSize: 17,
                    color: item.color ?? kText, fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
