/// App root — state-machine navigation:
///   ble_connect  →  config  →  monitoring (tab bar)
///                  ↑
///               STOP button
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/ble_provider.dart';
import 'services/sentio_api.dart';
import 'screens/muse_scan_screen.dart';
import 'screens/config_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/history_screen.dart';
import 'theme/theme.dart';

enum _Screen { bleConnect, config, monitoring }

class SentioApp extends StatefulWidget {
  const SentioApp({super.key});

  @override
  State<SentioApp> createState() => _SentioAppState();
}

class _SentioAppState extends State<SentioApp> {
  _Screen _screen = _Screen.bleConnect;
  int     _tab    = 0;

  @override
  void initState() {
    super.initState();
    // Auto-advance once BLE connects
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BleProvider>().addListener(_onBleChanged);
    });
  }

  void _onBleChanged() {
    if (!mounted) return;
    final ble = context.read<BleProvider>();
    if (ble.state == BLEState.connected && _screen == _Screen.bleConnect) {
      setState(() => _screen = _Screen.config);
    }
  }

  @override
  void dispose() {
    // BleProvider is disposed by MultiProvider
    super.dispose();
  }

  Future<void> _handleStop() async {
    try { await stopSession(); } catch (_) {}
    setState(() { _screen = _Screen.bleConnect; _tab = 0; });
  }

  @override
  Widget build(BuildContext context) {
    return switch (_screen) {
      _Screen.bleConnect => MuseScanScreen(
          onSkip: () => setState(() => _screen = _Screen.config),
        ),
      _Screen.config => ConfigScreen(
          onStart: () => setState(() => _screen = _Screen.monitoring),
        ),
      _Screen.monitoring => _MonitoringShell(
          tab:    _tab,
          onTab:  (i) => setState(() => _tab = i),
          onStop: _handleStop,
        ),
    };
  }
}

// ── Monitoring shell (top bar + tab content + bottom nav) ─────────────────────
class _MonitoringShell extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onTab;
  final AsyncCallback onStop;

  const _MonitoringShell({
    required this.tab, required this.onTab, required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text('SENTIO'),
        actions: [
          TextButton(
            onPressed: onStop,
            child: const Text(
              'STOP ✕',
              style: TextStyle(
                fontFamily: 'monospace', fontSize: 11,
                color: kMuted, letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: tab,
        children: const [
          DashboardScreen(),
          HistoryScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: tab,
        onTap: onTab,
        items: const [
          BottomNavigationBarItem(
            icon:       Icon(Icons.monitor_heart_outlined),
            activeIcon: Icon(Icons.monitor_heart),
            label: 'MONITOR',
          ),
          BottomNavigationBarItem(
            icon:       Icon(Icons.tune_outlined),
            activeIcon: Icon(Icons.tune),
            label: 'PATTERNS',
          ),
        ],
      ),
    );
  }
}
