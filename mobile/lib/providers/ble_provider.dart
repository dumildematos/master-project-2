/// BleProvider
/// ------------
/// ChangeNotifier that manages the full Muse 2 BLE lifecycle:
///   scan → connect → subscribe EEG chars → decode → buffer →
///   compute band powers → POST /api/eeg/mobile-bands every 250 ms.
///
/// Uses flutter_blue_plus for BLE and permission_handler for Android permissions.
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/muse_device.dart';
import '../models/band_powers.dart';
import '../services/eeg_processor.dart';
import '../services/sentio_api.dart';

// ── GATT constants ────────────────────────────────────────────────────────────
const _kServiceUUID  = '0000fe8d-0000-1000-8000-00805f9b34fb';
const _kControlUUID  = '273e0001-4c4d-454d-96be-f03bac821358';
const _kEEGUUIDs     = [
  '273e0003-4c4d-454d-96be-f03bac821358', // TP9
  '273e0004-4c4d-454d-96be-f03bac821358', // AF7
  '273e0005-4c4d-454d-96be-f03bac821358', // AF8
  '273e0006-4c4d-454d-96be-f03bac821358', // TP10
];
const _kCmdStart = [0x02, 0x64, 0x0a]; // 'd' — start EEG
const _kCmdStop  = [0x02, 0x68, 0x0a]; // 'h' — stop EEG

const Duration _kScanTimeout  = Duration(seconds: 15);
const Duration _kPostInterval = Duration(milliseconds: 250);

// ── State enum ────────────────────────────────────────────────────────────────
enum BLEState { idle, scanning, connecting, connected, disconnected, error }

// ── Provider ──────────────────────────────────────────────────────────────────
class BleProvider extends ChangeNotifier {
  BLEState _state = BLEState.idle;
  List<MuseDevice> _devices = [];
  MuseDevice? _connectedDevice;
  BandPowers? _bandPowers;
  double _signalQuality = 0;
  String? _error;

  // Internal state
  BluetoothDevice? _device;
  final List<List<double>> _buffers = [[], [], [], []];
  Timer? _postTimer;
  Timer? _scanTimer;
  final List<StreamSubscription> _subs = [];

  // ── Getters ────────────────────────────────────────────────────────────────
  BLEState    get state           => _state;
  List<MuseDevice> get devices    => List.unmodifiable(_devices);
  MuseDevice? get connectedDevice => _connectedDevice;
  BandPowers? get bandPowers      => _bandPowers;
  double      get signalQuality   => _signalQuality;
  String?     get error           => _error;

  // ── Scan ───────────────────────────────────────────────────────────────────
  Future<void> scan() async {
    _cleanup();
    _devices = [];
    _error = null;
    _setState(BLEState.scanning);

    // Request Android BLE permissions
    final granted = await _requestPermissions();
    if (!granted) {
      _error = 'Bluetooth permission denied';
      _setState(BLEState.error);
      return;
    }

    final found = <String, MuseDevice>{};

    _subs.add(
      FlutterBluePlus.onScanResults.listen((results) {
        for (final r in results) {
          final name = r.device.platformName;
          if (!name.startsWith('Muse')) continue;
          final id = r.device.remoteId.str;
          if (!found.containsKey(id)) {
            found[id] = MuseDevice(id: id, name: name, rssi: r.rssi);
            _devices = List.of(found.values);
            notifyListeners();
          }
        }
      }),
    );

    await FlutterBluePlus.startScan(timeout: _kScanTimeout);

    _scanTimer = Timer(_kScanTimeout, () {
      if (found.isEmpty) _setState(BLEState.idle);
    });
  }

  Future<void> stopScan() async {
    _scanTimer?.cancel();
    _scanTimer = null;
    await FlutterBluePlus.stopScan();
    _setState(BLEState.idle);
  }

  // ── Connect ────────────────────────────────────────────────────────────────
  Future<void> connect(MuseDevice museDevice) async {
    _cleanup();
    await FlutterBluePlus.stopScan().catchError((_) {});
    _setState(BLEState.connecting);
    _error = null;

    try {
      final device = BluetoothDevice.fromId(museDevice.id);
      _device = device;

      // Listen for disconnect
      _subs.add(
        device.connectionState.listen((state) {
          if (state == BluetoothConnectionState.disconnected) {
            _cleanup();
            _connectedDevice = null;
            _bandPowers = null;
            _setState(BLEState.disconnected);
          }
        }),
      );

      await device.connect(timeout: const Duration(seconds: 15));

      // Discover services
      final services = await device.discoverServices();
      final service  = services.firstWhere(
        (s) => s.serviceUuid.str128.toLowerCase() == _kServiceUUID,
        orElse: () => throw Exception('Muse 2 service not found'),
      );

      // Reset per-channel buffers
      for (final b in _buffers) b.clear();

      // Subscribe to each EEG characteristic
      for (int i = 0; i < _kEEGUUIDs.length; i++) {
        final uuid = _kEEGUUIDs[i];
        final char = service.characteristics.firstWhere(
          (c) => c.characteristicUuid.str128.toLowerCase() == uuid,
          orElse: () => throw Exception('EEG char $uuid not found'),
        );
        await char.setNotifyValue(true);
        final idx = i;
        _subs.add(
          char.onValueReceived.listen((value) {
            final packet = decodeEEGPacket(value);
            if (packet == null) return;
            _buffers[idx].addAll(packet.samples);
            if (_buffers[idx].length > kBandWindowSize * 2) {
              _buffers[idx] =
                  _buffers[idx].sublist(_buffers[idx].length - kBandWindowSize * 2);
            }
          }),
        );
      }

      // Send start EEG command (Write-Without-Response — non-fatal if it fails)
      try {
        final ctrl = service.characteristics.firstWhere(
          (c) => c.characteristicUuid.str128.toLowerCase() == _kControlUUID,
        );
        await ctrl.write(_kCmdStart, withoutResponse: true);
      } catch (_) { /* non-fatal */ }

      _connectedDevice = museDevice;
      _setState(BLEState.connected);

      // Periodic band-power POST
      _postTimer = Timer.periodic(_kPostInterval, (_) => _processBands());

    } catch (e) {
      _error = e.toString();
      _setState(BLEState.error);
    }
  }

  void _processBands() async {
    final ready = _buffers
        .where((b) => b.length >= kBandWindowSize)
        .map((b) => b.sublist(b.length - kBandWindowSize))
        .toList();

    if (ready.length < 2) return;

    final bands = averageBandPowers(ready);
    final sq    = estimateSignalQuality(bands);
    _bandPowers    = bands;
    _signalQuality = sq;
    notifyListeners();

    await postMobileBands({...bands.toJson(), 'signal_quality': sq});
  }

  // ── Disconnect ─────────────────────────────────────────────────────────────
  Future<void> disconnect() async {
    _cleanup();
    if (_device != null) {
      try {
        final services = await _device!.discoverServices();
        final service  = services.firstWhere(
          (s) => s.serviceUuid.str128.toLowerCase() == _kServiceUUID,
          orElse: () => throw Exception(),
        );
        final ctrl = service.characteristics.firstWhere(
          (c) => c.characteristicUuid.str128.toLowerCase() == _kControlUUID,
          orElse: () => throw Exception(),
        );
        await ctrl.write(_kCmdStop, withoutResponse: true);
      } catch (_) { /* best effort */ }
      await _device!.disconnect().catchError((_) {});
      _device = null;
    }
    _connectedDevice = null;
    _bandPowers      = null;
    _signalQuality   = 0;
    _setState(BLEState.idle);
  }

  // ── Internal ───────────────────────────────────────────────────────────────
  void _cleanup() {
    _scanTimer?.cancel(); _scanTimer = null;
    _postTimer?.cancel(); _postTimer = null;
    for (final s in _subs) s.cancel();
    _subs.clear();
  }

  void _setState(BLEState s) {
    _state = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }
}

// ── Android permission helper ─────────────────────────────────────────────────
Future<bool> _requestPermissions() async {
  final statuses = await [
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.location,
  ].request();
  return statuses.values.every(
    (s) => s == PermissionStatus.granted || s == PermissionStatus.limited,
  );
}
