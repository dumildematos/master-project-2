import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ble_provider.dart';
import '../services/sentio_api.dart';
import '../services/storage_service.dart';
import '../theme/theme.dart';

// ── Pattern definitions ────────────────────────────────────────────────────────
class _Pattern {
  final String id, label;
  final IconData icon;
  const _Pattern(this.id, this.label, this.icon);
}

const _kPatterns = [
  _Pattern('organic',   'Organic',   Icons.psychology_outlined),
  _Pattern('geometric', 'Geometric', Icons.apps_rounded),
  _Pattern('fluid',     'Fluid',     Icons.waves),
  _Pattern('textile',   'Textile',   Icons.texture),
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class ConfigScreen extends StatefulWidget {
  final VoidCallback onStart;
  const ConfigScreen({super.key, required this.onStart});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  String _patternType  = 'organic';
  double _sensitivity  = 74;   // 0–100 → displayed as "%"
  double _smoothing    = 24;   // 0–100 → displayed as "X ms" (value/2)
  bool   _loading      = false;
  String _error        = '';

  int get _smoothingMs => (_smoothing / 2).round();

  Future<void> _handleStart() async {
    final ble = context.read<BleProvider>();
    setState(() { _loading = true; _error = ''; });
    try {
      await startSession(SessionConfig(
        patternType:       _patternType,
        signalSensitivity: _sensitivity / 100,
        emotionSmoothing:  _smoothing   / 100,
        deviceSource:      ble.state == BLEState.connected ? 'mobile' : null,
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
        child: Column(
          children: [
            // ── Top bar ───────────────────────────────────────────────────
            _TopBar(
              deviceName:  isConnected ? ble.connectedDevice?.name : null,
              onDisconnect: ble.disconnect,
            ),

            // ── Scrollable body ───────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(kMd, kMd, kMd, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    const Text('Pattern Selection',
                      style: TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w800, color: kText,
                      )),
                    const SizedBox(height: 6),
                    const Text(
                      'Configure the structural calibration of the neural output.',
                      style: TextStyle(fontSize: 14, color: kMuted, height: 1.4),
                    ),
                    const SizedBox(height: kXl),

                    // ── Pattern type ─────────────────────────────────────
                    _SectionLabel('PATTERN TYPE'),
                    const SizedBox(height: kMd),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: kMd,
                      mainAxisSpacing:  kMd,
                      childAspectRatio: 1.25,
                      children: _kPatterns.map((p) {
                        final active = _patternType == p.id;
                        return _PatternCard(
                          pattern: p,
                          active:  active,
                          onTap:   () => setState(() => _patternType = p.id),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: kXl),

                    // ── Calibration controls ─────────────────────────────
                    _SectionLabel('CALIBRATION CONTROLS'),
                    const SizedBox(height: kLg),

                    _CalibrationSlider(
                      label:    'Signal Sensibility',
                      subtitle: 'Adjust frequency detection thresholds',
                      value:    _sensitivity,
                      unit:     '%',
                      display:  '${_sensitivity.round()}',
                      onChanged: (v) => setState(() => _sensitivity = v),
                    ),
                    const SizedBox(height: kLg),

                    _CalibrationSlider(
                      label:    'State Smoothing',
                      subtitle: 'Temporal averaging of neural transitions',
                      value:    _smoothing,
                      unit:     'ms',
                      display:  '$_smoothingMs',
                      onChanged: (v) => setState(() => _smoothing = v),
                    ),

                    // Error
                    if (_error.isNotEmpty) ...[
                      const SizedBox(height: kMd),
                      Container(
                        padding: const EdgeInsets.all(kMd),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD00000).withOpacity(0.09),
                          border: Border.all(color: const Color(0xFFD00000).withOpacity(0.33)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(_error,
                          style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 12,
                            color: Color(0xFFFF6B6B),
                          )),
                      ),
                    ],

                    const SizedBox(height: kXl),

                    // ── Start button ─────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _handleStart,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kCyan,
                          foregroundColor: kBg,
                          disabledBackgroundColor: kCyan.withOpacity(0.55),
                          padding: const EdgeInsets.symmetric(vertical: kMd + 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontFamily: 'monospace', fontSize: 14,
                            fontWeight: FontWeight.bold, letterSpacing: 2,
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: kBg,
                                ),
                              )
                            : const Text('START SESSION'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // ── Settings FAB ─────────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSettings(context),
        backgroundColor: kBg2,
        foregroundColor: kMuted,
        elevation: 2,
        child: const Icon(Icons.settings_outlined, size: 22),
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

// ── Top bar ────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final String? deviceName;
  final VoidCallback onDisconnect;
  const _TopBar({required this.deviceName, required this.onDisconnect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kMd, kMd, kMd, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SENTIO',
            style: TextStyle(
              fontFamily: 'monospace', fontSize: 15,
              fontWeight: FontWeight.w800, color: kCyan, letterSpacing: 4,
            )),
          if (deviceName != null) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onLongPress: onDisconnect,
              child: Row(children: [
                Container(
                  width: 7, height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4ADE80), shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'CONNECTED: ${deviceName!.toUpperCase()}',
                  style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 10,
                    color: kMuted, letterSpacing: 1,
                  ),
                ),
              ]),
            ),
          ] else ...[
            const SizedBox(height: 4),
            const Text('NO HEADSET — BACKEND BLUETOOTH',
              style: TextStyle(
                fontFamily: 'monospace', fontSize: 10,
                color: kMuted, letterSpacing: 1,
              )),
          ],
        ],
      ),
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
    style: const TextStyle(
      fontFamily: 'monospace', fontSize: 11,
      fontWeight: FontWeight.bold, color: kMuted, letterSpacing: 2,
    ));
}

// ── Pattern card ───────────────────────────────────────────────────────────────
class _PatternCard extends StatelessWidget {
  final _Pattern  pattern;
  final bool      active;
  final VoidCallback onTap;
  const _PatternCard({required this.pattern, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: active ? kCyan.withOpacity(0.07) : kBg2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? kCyan : kBorder,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              pattern.icon,
              size:  34,
              color: active ? kCyan : kMuted.withOpacity(0.65),
            ),
            const SizedBox(height: 10),
            Text(pattern.label,
              style: TextStyle(
                fontFamily: 'monospace', fontSize: 13,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                color: active ? kCyan : kMuted,
              )),
          ],
        ),
      ),
    );
  }
}

// ── Calibration slider ─────────────────────────────────────────────────────────
class _CalibrationSlider extends StatelessWidget {
  final String label, subtitle, display, unit;
  final double value;
  final ValueChanged<double> onChanged;

  const _CalibrationSlider({
    required this.label,
    required this.subtitle,
    required this.display,
    required this.unit,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                    style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, color: kText,
                    )),
                  const SizedBox(height: 3),
                  Text(subtitle,
                    style: const TextStyle(fontSize: 12, color: kMuted)),
                ],
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(display,
                  style: const TextStyle(
                    fontSize: 36, fontWeight: FontWeight.w700,
                    color: kCyan, height: 1,
                  )),
                const SizedBox(width: 3),
                Text(unit,
                  style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 13,
                    color: kCyan, fontWeight: FontWeight.bold,
                  )),
              ],
            ),
          ],
        ),
        const SizedBox(height: kSm),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor:   kCyan,
            inactiveTrackColor: kBorder,
            thumbColor:         kCyan,
            overlayColor:       kCyan.withOpacity(0.12),
            trackHeight:        5,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(
            value: value, min: 0, max: 100,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
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
          decoration: const InputDecoration(hintText: 'http://192.168.1.42:8000'),
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
              textStyle: const TextStyle(
                fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold,
              ),
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
