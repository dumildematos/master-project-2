/// BleProvider
/// ------------
/// ChangeNotifier that manages the full Muse 2 BLE lifecycle:
///   scan → connect → bond → subscribe EEG chars → decode → buffer →
///   compute band powers → POST /api/eeg/mobile-bands every 250 ms.
///
/// Auto-reconnects up to _kMaxReconnects times with exponential backoff
/// when the connection drops unexpectedly.
import 'dart:async';
import 'dart:io';
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

const Duration _kScanTimeout   = Duration(seconds: 15);
const Duration _kPostInterval  = Duration(milliseconds: 250);
const int      _kMaxReconnects = 5;

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
  int _reconnectAttempt = 0;

  // Internal state
  BluetoothDevice? _device;
  MuseDevice? _lastDevice; // kept for auto-reconnect
  final List<List<double>> _buffers = [[], [], [], []];
  Timer? _postTimer;
  Timer? _scanTimer;
  Timer? _reconnectTimer;
  final List<StreamSubscription> _subs = [];

  // ── Getters ────────────────────────────────────────────────────────────────
  BLEState         get state            => _state;
  List<MuseDevice> get devices          => List.unmodifiable(_devices);
  MuseDevice?      get connectedDevice  => _connectedDevice;
  BandPowers?      get bandPowers       => _bandPowers;
  double           get signalQuality    => _signalQuality;
  String?          get error            => _error;
  /// > 0 while auto-reconnect is in progress (shows attempt number in UI).
  int              get reconnectAttempt => _reconnectAttempt;

  // ── Permissions ────────────────────────────────────────────────────────────
  Future<bool> requestPermissions() => _requestPermissions();

  // ── Scan ───────────────────────────────────────────────────────────────────
  Future<void> scan() async {
    _cleanup();
    _devices = [];
    _error = null;
    _setState(BLEState.scanning);

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
  Future<void> connect(MuseDevice museDevice, {bool isReconnect = false}) async {
    if (!isReconnect) {
      _reconnectAttempt = 0;
      _lastDevice = museDevice;
    }

    _cleanup();
    await FlutterBluePlus.stopScan().catchError((_) {});
    _setState(BLEState.connecting);
    _error = null;

    try {
      final device = BluetoothDevice.fromId(museDevice.id);
      _device = device;

      // Watch for unexpected disconnects and auto-reconnect.
      _subs.add(
        device.connectionState.listen((cs) {
          if (cs == BluetoothConnectionState.disconnected &&
              _state == BLEState.connected) {
            _onDropped();
          }
        }),
      );

      await device.connect(timeout: const Duration(seconds: 15));

      // Bond the device so the OS maintains the pairing across sessions.
      if (Platform.isAndroid) {
        await device.createBond().catchError((_) {});
      }

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

      _reconnectAttempt = 0;
      _connectedDevice  = museDevice;
      _setState(BLEState.connected);

      _postTimer = Timer.periodic(_kPostInterval, (_) => _processBands());

    } catch (e) {
      _error = e.toString();
      _setState(BLEState.error);
    }
  }

  /// Called when the OS reports an unexpected disconnect.
  void _onDropped() {
    _postTimer?.cancel(); _postTimer = null;
    for (final s in _subs) s.cancel();
    _subs.clear();
    _bandPowers    = null;
    _signalQuality = 0;
    notifyListeners();

    if (_reconnectAttempt < _kMaxReconnects && _lastDevice != null) {
      _reconnectAttempt++;
      _setState(BLEState.connecting);
      // Exponential backoff: 2 s, 4 s, 6 s, 8 s, 10 s
      final backoff = Duration(seconds: _reconnectAttempt * 2);
      _reconnectTimer = Timer(
        backoff,
        () => connect(_lastDevice!, isReconnect: true),
      );
    } else {
      _reconnectAttempt = 0;
      _connectedDevice  = null;
      _setState(BLEState.disconnected);
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
    // Prevent auto-reconnect from triggering.
    _lastDevice       = null;
    _reconnectAttempt = _kMaxReconnects;

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
    _connectedDevice  = null;
    _bandPowers       = null;
    _signalQuality    = 0;
    _reconnectAttempt = 0;
    _setState(BLEState.idle);
  }

  // ── Internal ───────────────────────────────────────────────────────────────
  void _cleanup() {
    _scanTimer?.cancel();     _scanTimer     = null;
    _postTimer?.cancel();     _postTimer     = null;
    _reconnectTimer?.cancel(); _reconnectTimer = null;
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

  final allGranted = statuses.values.every(
    (s) => s == PermissionStatus.granted || s == PermissionStatus.limited,
  );

  if (!allGranted) {
    final anyPermanentlyDenied = statuses.values
        .any((s) => s == PermissionStatus.permanentlyDenied);
    if (anyPermanentlyDenied) openAppSettings();
  }

  return allGranted;
}
