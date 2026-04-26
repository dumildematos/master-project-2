import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ble_provider.dart';
import '../services/sentio_api.dart';
import '../services/storage_service.dart';
import '../theme/theme.dart';

const _kPatterns = [
  ('organic',   'Organic',   'Flowing natural forms'),
  ('geometric', 'Geometric', 'Structured symmetry'),
  ('fluid',     'Fluid',     'Liquid motion patterns'),
  ('textile',   'Textile',   'Woven fabric inspired'),
];

class ConfigScreen extends StatefulWidget {
  final VoidCallback onStart;
  const ConfigScreen({super.key, required this.onStart});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  String _patternType = 'organic';
  double _sensitivity = 50;
  double _smoothing   = 50;
  bool   _loading     = false;
  String _error       = '';

  Future<void> _handleStart() async {
    final ble  = context.read<BleProvider>();
    final isConnected = ble.state == BLEState.connected;
    setState(() { _loading = true; _error = ''; });
    try {
      await startSession(SessionConfig(
        patternType:       _patternType,
        signalSensitivity: _sensitivity / 100,
        emotionSmoothing:  _smoothing   / 100,
        deviceSource:      isConnected ? 'mobile' : null,
      ));
      widget.onStart();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ble         = context.watch<BleProvider>();
    final isConnected = ble.state == BLEState.connected;

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(kMd, kXl, kMd, 80),
          child: Column(
            children: [
              // Header
              const Column(children: [
                Text('SENTIO',
                  style: TextStyle(
                    fontFamily: 'monospace', fontSize: 28, fontWeight: FontWeight.w800,
                    letterSpacing: 6, color: kCyan,
                  )),
                SizedBox(height: 4),
                Text('emotion-driven fabric patterns',
                  style: TextStyle(
                    fontFamily: 'monospace', fontSize: 11, color: kMuted, letterSpacing: 2,
                  )),
              ]),
              const SizedBox(height: kXl),

              // Card
              Container(
                decoration: BoxDecoration(
                  color: kBg2,
                  border: Border.all(color: kBorder),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(kLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Configure Session',
                      style: TextStyle(
                        fontFamily: 'monospace', fontSize: 16,
                        fontWeight: FontWeight.bold, color: kText,
                      )),
                    const SizedBox(height: kLg),

                    // BLE status banner
                    if (isConnected && ble.connectedDevice != null) ...[
                      _BleBanner(device: ble.connectedDevice!.name, onDisconnect: ble.disconnect),
                    ] else ...[
                      _NoBanner(),
                    ],
                    const SizedBox(height: kMd),

                    // Pattern type
                    const Text('PATTERN TYPE',
                      style: TextStyle(
                        fontFamily: 'monospace', fontSize: 10,
                        color: kMuted, letterSpacing: 2,
                      )),
                    const SizedBox(height: kSm),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: kSm,
                      mainAxisSpacing: kSm,
                      childAspectRatio: 1.4,
                      children: _kPatterns.map((p) {
                        final (id, label, desc) = p;
                        final active = _patternType == id;
                        return GestureDetector(
                          onTap: () => setState(() => _patternType = id),
                          child: Container(
                            decoration: BoxDecoration(
                              color: active ? kCyan.withOpacity(0.05) : kBg,
                              border: Border.all(
                                color: active ? kCyan.withOpacity(0.53) : kBorder,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(kSm),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _PatternPreview(type: id, active: active),
                                const SizedBox(height: 4),
                                Text(label,
                                  style: TextStyle(
                                    fontFamily: 'monospace', fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: active ? kCyan : kText,
                                  )),
                                Text(desc,
                                  style: const TextStyle(
                                    fontFamily: 'monospace', fontSize: 9, color: kMuted,
                                  )),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: kMd),

                    // Sliders
                    _Slider(
                      label: 'Signal Sensitivity',
                      value: _sensitivity,
                      leftLabel: 'Low noise', rightLabel: 'High detail',
                      onChanged: (v) => setState(() => _sensitivity = v),
                    ),
                    _Slider(
                      label: 'State Smoothing',
                      value: _smoothing,
                      leftLabel: 'Reactive', rightLabel: 'Stable',
                      onChanged: (v) => setState(() => _smoothing = v),
                    ),

                    // Error
                    if (_error.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(kSm),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD00000).withOpacity(0.09),
                          border: Border.all(color: const Color(0xFFD00000).withOpacity(0.33)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(_error,
                          style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 12, color: Color(0xFFFF6B6B),
                          )),
                      ),
                      const SizedBox(height: kMd),
                    ],

                    // Start button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _handleStart,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kCyan, foregroundColor: kBg,
                          disabledBackgroundColor: kCyan.withOpacity(0.6),
                          padding: const EdgeInsets.symmetric(vertical: kMd),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontFamily: 'monospace', fontSize: 14,
                            fontWeight: FontWeight.bold, letterSpacing: 1,
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: kBg),
                              )
                            : const Text('Start Session →'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSettings(context),
        backgroundColor: kCyan,
        foregroundColor: kBg,
        child: const Text('⚙️', style: TextStyle(fontSize: 22)),
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kBg2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => const _SettingsSheet(),
    );
  }
}

// ── BLE banners ────────────────────────────────────────────────────────────────
class _BleBanner extends StatelessWidget {
  final String device;
  final VoidCallback onDisconnect;
  const _BleBanner({required this.device, required this.onDisconnect});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(kSm),
    decoration: BoxDecoration(
      color: const Color(0xFF00FF88).withOpacity(0.08),
      border: Border.all(color: const Color(0xFF4ADE80).withOpacity(0.27)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Container(
          width: 8, height: 8,
          decoration: const BoxDecoration(
            color: Color(0xFF4ADE80), shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: kSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(device,
                style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 12,
                  fontWeight: FontWeight.bold, color: Color(0xFF4ADE80),
                )),
              const Text('Mobile Bluetooth · connected',
                style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: kMuted)),
            ],
          ),
        ),
        TextButton(
          onPressed: onDisconnect,
          child: const Text('Disconnect',
            style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: kMuted)),
        ),
      ],
    ),
  );
}

class _NoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(kSm),
    decoration: BoxDecoration(
      color: kBg,
      border: Border.all(color: kBorder),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Center(
      child: Text('⚡ No headset — backend will use its own Bluetooth',
        style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: kMuted)),
    ),
  );
}

// ── Pattern preview ────────────────────────────────────────────────────────────
class _PatternPreview extends StatelessWidget {
  final String type;
  final bool active;
  const _PatternPreview({required this.type, required this.active});

  @override
  Widget build(BuildContext context) {
    final col = active ? kCyan : kMuted;
    return Container(
      width: double.infinity, height: 44,
      decoration: BoxDecoration(
        color: active ? kCyan.withOpacity(0.09) : kBg,
        border: Border.all(color: active ? kCyan.withOpacity(0.33) : kBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: CustomPaint(painter: _PatternPainter(type: type, color: col)),
    );
  }
}

class _PatternPainter extends CustomPainter {
  final String type;
  final Color color;
  const _PatternPainter({required this.type, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    switch (type) {
      case 'organic':
        canvas.drawCircle(Offset(size.width * 0.4, size.height * 0.5), 14, paint);
        canvas.drawCircle(Offset(size.width * 0.6, size.height * 0.5), 9, paint..color = color.withOpacity(0.35));
      case 'geometric':
        final rect = Rect.fromCenter(center: Offset(size.width / 2, size.height / 2), width: 20, height: 20);
        canvas.save();
        canvas.translate(size.width / 2, size.height / 2);
        canvas.rotate(0.26);
        canvas.translate(-size.width / 2, -size.height / 2);
        canvas.drawRect(rect, paint);
        canvas.restore();
      case 'fluid':
        canvas.drawLine(
          Offset(size.width * 0.2, size.height / 2),
          Offset(size.width * 0.8, size.height / 2), paint);
      case 'textile':
        for (int i = 0; i < 3; i++) {
          final x = size.width * 0.3 + i * size.width * 0.15;
          canvas.drawLine(Offset(x, 6), Offset(x, size.height - 6), paint);
        }
    }
  }

  @override
  bool shouldRepaint(_PatternPainter old) =>
      old.type != type || old.color != color;
}

// ── Slider ─────────────────────────────────────────────────────────────────────
class _Slider extends StatelessWidget {
  final String label;
  final double value;
  final String leftLabel, rightLabel;
  final ValueChanged<double> onChanged;

  const _Slider({
    required this.label, required this.value,
    required this.leftLabel, required this.rightLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: kMd),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
              style: const TextStyle(
                fontFamily: 'monospace', fontSize: 11, color: kMuted,
              )),
            Text('${value.round()}%',
              style: const TextStyle(
                fontFamily: 'monospace', fontSize: 11, color: kCyan,
              )),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor:   kCyan,
            inactiveTrackColor: kBorder,
            thumbColor:         kCyan,
            overlayColor:       kCyan.withOpacity(0.12),
            trackHeight:        6,
          ),
          child: Slider(
            value: value, min: 0, max: 100,
            onChanged: onChanged,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(leftLabel,  style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: kMuted)),
            Text(rightLabel, style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: kMuted)),
          ],
        ),
      ],
    ),
  );
}

// ── Settings bottom sheet ──────────────────────────────────────────────────────
class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet();
  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    StorageService.getApiUrl().then((url) {
      if (mounted) setState(() => _ctrl.text = url);
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    final url = _ctrl.text.trim();
    if (url.isNotEmpty && !url.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL must start with http:// or https://')),
      );
      return;
    }
    if (url.isNotEmpty) await StorageService.saveApiUrl(url);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: kLg, right: kLg, top: kLg,
      bottom: MediaQuery.of(context).viewInsets.bottom + 40,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: kBorder, borderRadius: BorderRadius.circular(2),
          ),
        )),
        const SizedBox(height: kLg),
        const Text('Backend Settings',
          style: TextStyle(
            fontFamily: 'monospace', fontSize: 14,
            fontWeight: FontWeight.bold, color: kText, letterSpacing: 2,
          )),
        const SizedBox(height: kMd),
        const Text('API URL',
          style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: kMuted, letterSpacing: 2)),
        const SizedBox(height: 6),
        TextField(
          controller: _ctrl,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 14, color: kText),
          decoration: const InputDecoration(
            hintText: 'http://192.168.1.42:8000',
          ),
          keyboardType: TextInputType.url,
          autocorrect: false,
        ),
        const SizedBox(height: 4),
        const Text('Address of the Sentio backend server.',
          style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: kMuted)),
        const SizedBox(height: kLg),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: kCyan, foregroundColor: kBg,
              padding: const EdgeInsets.symmetric(vertical: kMd),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold),
            ),
            child: const Text('Save'),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
            style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: kMuted)),
        ),
      ],
    ),
  );
}
