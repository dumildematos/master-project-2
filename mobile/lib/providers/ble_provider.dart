/// BleProvider
/// ------------
/// Manages BLE lifecycle for both Muse 2 and SENTIO Hat devices.
///
/// Legacy API (used by MuseScanScreen):
///   scan() → connect(MuseDevice) → disconnect()
///   Exposes: state (BLEState), devices (List<MuseDevice>), connectedDevice,
///            bandPowers, signalQuality, reconnectAttempt
///
/// New multi-device API (used by ConnectDeviceScreen):
///   startScan() → connectToDevice(BluetoothDevice) → disconnectDevice()
///   Exposes: isScanning, discoveredDevices (List<ScannedDevice>),
///            connectedMuse, connectedHat, isMuseConnected, isHatConnected
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/muse_device.dart';
import '../models/band_powers.dart';
import '../models/scanned_device.dart';
import '../services/eeg_processor.dart';
import '../services/sentio_api.dart';

// ── Muse 2 GATT constants ──────────────────────────────────────────────────────
const _kMuseServiceUUID = '0000fe8d-0000-1000-8000-00805f9b34fb';
const _kControlUUID     = '273e0001-4c4d-454d-96be-f03bac821358';
const _kEEGUUIDs        = [
  '273e0003-4c4d-454d-96be-f03bac821358', // TP9
  '273e0004-4c4d-454d-96be-f03bac821358', // AF7
  '273e0005-4c4d-454d-96be-f03bac821358', // AF8
  '273e0006-4c4d-454d-96be-f03bac821358', // TP10
];
const _kCmdStart = [0x02, 0x64, 0x0a];
const _kCmdStop  = [0x02, 0x68, 0x0a];

// ── SENTIO Hat GATT constants ──────────────────────────────────────────────────
const _kHatServiceUUID = '7b1e0001-9f4c-4d21-8b6f-2c5f7e8a1000';
const _kHatCommandUUID = '7b1e0002-9f4c-4d21-8b6f-2c5f7e8a1000';
const _kHatStatusUUID  = '7b1e0003-9f4c-4d21-8b6f-2c5f7e8a1000';

const Duration _kMuseScanTimeout = Duration(seconds: 15);
const Duration _kNewScanTimeout  = Duration(seconds: 10);
const Duration _kPostInterval    = Duration(milliseconds: 250);
const int      _kMaxReconnects   = 5;

// ── State enum (Muse lifecycle — kept for backward compat) ────────────────────
enum BLEState { idle, scanning, connecting, connected, disconnected, error }

// ── Provider ──────────────────────────────────────────────────────────────────
class BleProvider extends ChangeNotifier {

  // ── Legacy Muse state ──────────────────────────────────────────────────────
  BLEState           _state           = BLEState.idle;
  List<MuseDevice>   _devices         = [];
  MuseDevice?        _connectedDevice;
  BandPowers?        _bandPowers;
  double             _signalQuality   = 0;
  String?            _error;
  int                _reconnectAttempt = 0;
  BluetoothDevice?   _museDevice;
  MuseDevice?        _lastDevice;
  final List<List<double>> _buffers   = [[], [], [], []];
  Timer?             _postTimer;
  Timer?             _scanTimer;
  Timer?             _reconnectTimer;
  final List<StreamSubscription> _subs = [];

  // ── New multi-device state ─────────────────────────────────────────────────
  bool                          _isScanning       = false;
  bool                          _isConnecting     = false;
  List<ScannedDevice>           _scannedDevices   = [];
  BluetoothDevice?              _connectedMuse;
  BluetoothDevice?              _connectedHat;
  BluetoothCharacteristic?      _hatCommandChar;
  int?                          _museBattery;
  int?                          _hatBattery;
  final Map<String, List<BluetoothService>> _deviceServices = {};
  final List<StreamSubscription> _scanSubs         = [];
  final List<StreamSubscription> _hatSubs           = [];

  // ── Legacy getters ─────────────────────────────────────────────────────────
  BLEState         get state            => _state;
  List<MuseDevice> get devices          => List.unmodifiable(_devices);
  MuseDevice?      get connectedDevice  => _connectedDevice;
  BandPowers?      get bandPowers       => _bandPowers;
  double           get signalQuality    => _signalQuality;
  String?          get error            => _error;
  int              get reconnectAttempt => _reconnectAttempt;

  // ── New getters ────────────────────────────────────────────────────────────
  bool                get isScanning       => _isScanning;
  bool                get isConnecting     => _isConnecting;
  List<ScannedDevice> get discoveredDevices => List.unmodifiable(_scannedDevices);
  BluetoothDevice?    get connectedMuse    => _connectedMuse;
  BluetoothDevice?    get connectedHat     => _connectedHat;
  bool                get isMuseConnected  => _connectedMuse != null;
  bool                get isHatConnected   => _connectedHat  != null;
  int?                get museBattery      => _museBattery;
  int?                get hatBattery       => _hatBattery;

  bool isDeviceConnected(BluetoothDevice device) =>
      _connectedMuse?.remoteId == device.remoteId ||
      _connectedHat?.remoteId  == device.remoteId;

  // ── Permissions ────────────────────────────────────────────────────────────
  Future<bool> requestPermissions() => _requestPermissions();

  // ════════════════════════════════════════════════════════════════════════════
  // Legacy scan (MuseScanScreen — Muse only, 15 s timeout)
  // ════════════════════════════════════════════════════════════════════════════
  Future<void> scan() async {
    _cleanup();
    _devices = [];
    _error   = null;
    _setState(BLEState.scanning);

    final granted = await _requestPermissions();
    if (!granted) {
      _error = 'Bluetooth permission denied';
      _setState(BLEState.error);
      return;
    }

    final found = <String, MuseDevice>{};

    _subs.add(FlutterBluePlus.onScanResults.listen((results) {
      for (final r in results) {
        final name = r.device.platformName;
        if (!name.startsWith('Muse')) continue;
        final id = r.device.remoteId.str;
        if (!found.containsKey(id)) {
          found[id] = MuseDevice(id: id, name: name, rssi: r.rssi);
          _devices  = List.of(found.values);
          notifyListeners();
        }
      }
    }));

    await FlutterBluePlus.startScan(timeout: _kMuseScanTimeout);

    _scanTimer = Timer(_kMuseScanTimeout, () {
      if (found.isEmpty) _setState(BLEState.idle);
    });
  }

  Future<void> stopScan() async {
    _cancelNewScan();
    _scanTimer?.cancel();
    _scanTimer = null;
    await FlutterBluePlus.stopScan().catchError((_) {});
    _isScanning = false;
    if (_state == BLEState.scanning) _setState(BLEState.idle);
    else notifyListeners();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // New multi-device scan (ConnectDeviceScreen — all devices, 10 s timeout)
  // ════════════════════════════════════════════════════════════════════════════
  Future<void> startScan() async {
    _cancelNewScan();
    await FlutterBluePlus.stopScan().catchError((_) {});

    _scannedDevices = [];
    _devices        = [];
    _error          = null;
    _isScanning     = true;
    notifyListeners();

    final granted = await _requestPermissions();
    if (!granted) {
      _isScanning = false;
      _error      = 'Bluetooth permission denied';
      notifyListeners();
      return;
    }

    final found = <String, ScannedDevice>{};

    _scanSubs.add(FlutterBluePlus.onScanResults.listen((results) {
      var changed = false;
      for (final r in results) {
        final name = r.device.platformName;
        if (name.isEmpty) continue;
        final id   = r.device.remoteId.str;
        final kind = BleDeviceKindX.classify(name);
        debugPrint('[BLE Scan] $name | $id | RSSI: ${r.rssi} | kind: $kind');
        final sd   = ScannedDevice(device: r.device, rssi: r.rssi, kind: kind);
        if (!found.containsKey(id) || found[id]!.rssi != r.rssi) {
          found[id] = sd;
          changed = true;
        }
      }
      if (changed) {
        _scannedDevices = _sortDevices(found.values.toList());
        _devices = _scannedDevices
            .where((d) => d.kind == BleDeviceKind.muse)
            .map((d) => MuseDevice(
                  id: d.device.remoteId.str, name: d.name, rssi: d.rssi))
            .toList();
        notifyListeners();
      }
    }));

    await FlutterBluePlus.startScan(timeout: _kNewScanTimeout);

    _scanTimer = Timer(_kNewScanTimeout, () {
      _isScanning = false;
      if (_state == BLEState.scanning) _setState(BLEState.idle);
      else notifyListeners();
    });
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Legacy Muse connect (MuseScanScreen — full EEG pipeline)
  // ════════════════════════════════════════════════════════════════════════════
  Future<void> connect(MuseDevice museDevice, {bool isReconnect = false}) async {
    if (!isReconnect) {
      _reconnectAttempt = 0;
      _lastDevice       = museDevice;
    }

    _cleanup();
    await FlutterBluePlus.stopScan().catchError((_) {});
    _setState(BLEState.connecting);
    _isConnecting = true;
    _error = null;

    try {
      final device = BluetoothDevice.fromId(museDevice.id);
      _museDevice  = device;

      debugPrint('[BLE Connect] Connecting to ${museDevice.name} (${museDevice.id}) — BLE only, no pairing');

      _subs.add(device.connectionState.listen((cs) {
        debugPrint('[BLE State] ${device.remoteId} → $cs');
        if (cs == BluetoothConnectionState.disconnected &&
            _state == BLEState.connected) {
          _onDropped();
        }
      }));

      await device.connect(autoConnect: false, timeout: const Duration(seconds: 15));

      await Future.delayed(const Duration(milliseconds: 500));

      final services = await device.discoverServices();
      _deviceServices[device.remoteId.str] = services;
      debugPrint('[BLE Services] Discovered ${services.length} services for ${device.remoteId}');

      final service = services.firstWhere(
        (s) => s.serviceUuid.str128.toLowerCase() == _kMuseServiceUUID,
        orElse: () => throw Exception('Muse 2 service not found'),
      );

      for (final b in _buffers) b.clear();

      for (int i = 0; i < _kEEGUUIDs.length; i++) {
        final uuid = _kEEGUUIDs[i];
        final char = service.characteristics.firstWhere(
          (c) => c.characteristicUuid.str128.toLowerCase() == uuid,
          orElse: () => throw Exception('EEG char $uuid not found'),
        );
        debugPrint('[BLE EEG] Subscribing to channel $i: $uuid');
        await char.setNotifyValue(true);
        final idx = i;
        _subs.add(char.onValueReceived.listen((value) {
          final packet = decodeEEGPacket(value);
          if (packet == null) return;
          _buffers[idx].addAll(packet.samples);
          if (_buffers[idx].length > kBandWindowSize * 2) {
            _buffers[idx] =
                _buffers[idx].sublist(_buffers[idx].length - kBandWindowSize * 2);
          }
        }));
      }

      try {
        final ctrl = service.characteristics.firstWhere(
          (c) => c.characteristicUuid.str128.toLowerCase() == _kControlUUID,
        );
        await ctrl.write(_kCmdStart, withoutResponse: true);
      } catch (_) {}

      _reconnectAttempt = 0;
      _connectedDevice  = museDevice;
      _connectedMuse    = device;
      _isConnecting     = false;
      _setState(BLEState.connected);
      debugPrint('[BLE Connect] Connected to ${museDevice.name} — EEG streaming started');

      _postTimer = Timer.periodic(_kPostInterval, (_) => _processBands());
    } catch (e) {
      debugPrint('[BLE Error] connect() failed: $e');
      _error        = e.toString();
      _isConnecting = false;
      _setState(BLEState.error);
    }
  }

  void _onDropped() {
    _postTimer?.cancel();
    _postTimer = null;
    for (final s in _subs) s.cancel();
    _subs.clear();
    _bandPowers    = null;
    _signalQuality = 0;
    notifyListeners();

    if (_reconnectAttempt < _kMaxReconnects && _lastDevice != null) {
      _reconnectAttempt++;
      _setState(BLEState.connecting);
      final backoff = Duration(seconds: _reconnectAttempt * 2);
      _reconnectTimer = Timer(backoff, () => connect(_lastDevice!, isReconnect: true));
    } else {
      _reconnectAttempt = 0;
      _connectedDevice  = null;
      _connectedMuse    = null; // ← new API
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

  // ── Legacy disconnect ──────────────────────────────────────────────────────
  Future<void> disconnect() async {
    _lastDevice       = null;
    _reconnectAttempt = _kMaxReconnects;

    _cleanup();
    if (_museDevice != null) {
      try {
        final services = _deviceServices[_museDevice!.remoteId.str] ??
            await _museDevice!.discoverServices();
        final service = services.firstWhere(
          (s) => s.serviceUuid.str128.toLowerCase() == _kMuseServiceUUID,
          orElse: () => throw Exception(),
        );
        final ctrl = service.characteristics.firstWhere(
          (c) => c.characteristicUuid.str128.toLowerCase() == _kControlUUID,
          orElse: () => throw Exception(),
        );
        await ctrl.write(_kCmdStop, withoutResponse: true);
      } catch (_) {}
      await _museDevice!.disconnect().catchError((_) {});
      _museDevice = null;
    }
    _connectedDevice  = null;
    _connectedMuse    = null;
    _bandPowers       = null;
    _signalQuality    = 0;
    _reconnectAttempt = 0;
    _setState(BLEState.idle);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // New multi-device connect / disconnect
  // ════════════════════════════════════════════════════════════════════════════

  /// BLE-only Muse connect — no pairing, no PIN, no createBond().
  Future<void> connectMuse(BluetoothDevice device) async {
    final rssi = _scannedDevices
        .where((d) => d.device.remoteId == device.remoteId)
        .map((d) => d.rssi)
        .firstOrNull ?? -80;
    final md = MuseDevice(id: device.remoteId.str, name: device.platformName, rssi: rssi);
    await connect(md);
  }

  /// Connect to a BLE device by MAC address — no pairing, no PIN, no createBond().
  ///
  /// Resolution order:
  ///   1. Already in scan cache → connectToDevice (knows kind).
  ///   2. Not cached → 4-second scan to find it, then connectToDevice.
  ///   3. Still not visible → connect directly by identifier (generic BLE).
  Future<void> connectByMac(String mac) async {
    _isConnecting = true;
    _error        = null;
    notifyListeners();

    try {
      // 1. Already seen in this scan session?
      final cached = _scannedDevices
          .where((d) => d.device.remoteId.str.toLowerCase() == mac.toLowerCase())
          .firstOrNull;

      if (cached != null) {
        debugPrint('[BLE MAC] $mac found in cache — connecting');
        await connectToDevice(cached.device);
        return;
      }

      // 2. Run a short 4-second scan to find the device by MAC.
      debugPrint('[BLE MAC] $mac not cached — scanning 4 s');
      await FlutterBluePlus.stopScan().catchError((_) {});

      final completer = Completer<BluetoothDevice?>();
      StreamSubscription? sub;
      sub = FlutterBluePlus.onScanResults.listen((results) {
        for (final r in results) {
          if (r.device.remoteId.str.toLowerCase() == mac.toLowerCase()) {
            final sd = ScannedDevice(
              device: r.device,
              rssi: r.rssi,
              kind: BleDeviceKindX.classify(r.device.platformName),
            );
            if (!_scannedDevices.any((d) => d.device.remoteId == r.device.remoteId)) {
              _scannedDevices = [..._scannedDevices, sd];
              notifyListeners();
            }
            if (!completer.isCompleted) completer.complete(r.device);
          }
        }
      });

      unawaited(FlutterBluePlus.startScan(timeout: const Duration(seconds: 4)));

      BluetoothDevice? found;
      try {
        found = await completer.future.timeout(const Duration(seconds: 4));
      } on TimeoutException {
        found = null;
      } finally {
        sub.cancel();
        await FlutterBluePlus.stopScan().catchError((_) {});
      }

      if (found != null) {
        debugPrint('[BLE MAC] Found $mac in scan — connecting');
        await connectToDevice(found);
        return;
      }

      // 3. Device not visible — connect directly by identifier (BLE only).
      debugPrint('[BLE MAC] $mac not visible after scan — connecting by identifier');
      final device = BluetoothDevice(remoteId: DeviceIdentifier(mac));
      await device.connect(autoConnect: false, timeout: const Duration(seconds: 15));
      await Future.delayed(const Duration(milliseconds: 500));
      await device.discoverServices();

      if (!_scannedDevices.any((d) => d.device.remoteId == device.remoteId)) {
        _scannedDevices = [
          ..._scannedDevices,
          ScannedDevice(
            device: device,
            rssi: -80,
            kind: BleDeviceKindX.classify(device.platformName),
          ),
        ];
      }
    } catch (e) {
      _error = 'Connection failed';
      debugPrint('[BLE MAC] connectByMac($mac) error: $e');
      rethrow;
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    final name = device.platformName;
    final kind = BleDeviceKindX.classify(name);

    switch (kind) {
      case BleDeviceKind.muse:
        await connectMuse(device);
      case BleDeviceKind.sentioHat:
        await _connectHat(device);
      case BleDeviceKind.other:
        await _connectGeneric(device);
    }
  }

  Future<void> disconnectDevice(BluetoothDevice device) async {
    if (_connectedMuse?.remoteId == device.remoteId) {
      await disconnectMuse();
    } else if (_connectedHat?.remoteId == device.remoteId) {
      await disconnectHat();
    } else {
      await device.disconnect().catchError((_) {});
    }
    notifyListeners();
  }

  Future<void> disconnectMuse() async {
    await disconnect();
  }

  Future<void> disconnectHat() async {
    for (final s in _hatSubs) s.cancel();
    _hatSubs.clear();
    if (_connectedHat != null) {
      await _connectedHat!.disconnect().catchError((_) {});
    }
    _connectedHat   = null;
    _hatCommandChar = null;
    notifyListeners();
  }

  Future<void> discoverServices(BluetoothDevice device) async {
    final services = await device.discoverServices();
    _deviceServices[device.remoteId.str] = services;
    notifyListeners();
  }

  Future<void> sendHatCommand(String command) async {
    final char = _hatCommandChar;
    if (char == null) throw Exception('SENTIO Hat not connected');
    await char.write(command.codeUnits);
  }

  /// Send a JSON payload to the Hat's LED characteristic.
  /// Uses allowLongWrite so payloads larger than the negotiated MTU are chunked
  /// automatically by flutter_blue_plus.
  Future<void> sendHatPayload(String json) async {
    final char = _hatCommandChar;
    if (char == null) throw Exception('SENTIO Hat not connected');
    final bytes = utf8.encode(json);
    debugPrint('[BLE Hat] sendHatPayload ${bytes.length} B → ${char.characteristicUuid}');
    await char.write(bytes, withoutResponse: false, allowLongWrite: true);
  }

  /// Send a SessionLedPattern to the Hat using the same payload contract as
  /// LedConfig — the Hat firmware only sees mode/brightness/speed/colors/pattern.
  Future<void> previewSessionPattern(dynamic pattern) async {
    final payload = jsonEncode(pattern.toJson());
    await sendHatPayload(payload);
  }

  // ── SENTIO Hat connect ─────────────────────────────────────────────────────
  Future<void> _connectHat(BluetoothDevice device) async {
    _error = null;
    notifyListeners();

    try {
      // Track unexpected disconnects
      _hatSubs.add(device.connectionState.listen((cs) {
        if (cs == BluetoothConnectionState.disconnected &&
            _connectedHat?.remoteId == device.remoteId) {
          for (final s in _hatSubs) s.cancel();
          _hatSubs.clear();
          _connectedHat   = null;
          _hatCommandChar = null;
          notifyListeners();
        }
      }));

      debugPrint('[BLE Hat] Connecting to ${device.platformName} (${device.remoteId}) — BLE only');
      await device.connect(autoConnect: false, timeout: const Duration(seconds: 15));

      final services = await device.discoverServices();
      _deviceServices[device.remoteId.str] = services;

      BluetoothService? hatService;
      for (final s in services) {
        if (s.serviceUuid.str128.toLowerCase() == _kHatServiceUUID) {
          hatService = s;
          break;
        }
      }

      if (hatService != null) {
        // Store command characteristic
        for (final c in hatService.characteristics) {
          if (c.characteristicUuid.str128.toLowerCase() == _kHatCommandUUID) {
            _hatCommandChar = c;
          }
          // Subscribe to status characteristic
          if (c.characteristicUuid.str128.toLowerCase() == _kHatStatusUUID) {
            try {
              await c.setNotifyValue(true);
              _hatSubs.add(c.onValueReceived.listen((value) {
                debugPrint('[SENTIO Hat] status: $value');
              }));
            } catch (_) {}
          }
        }
      }

      _connectedHat = device;
      notifyListeners();
    } catch (e) {
      for (final s in _hatSubs) s.cancel();
      _hatSubs.clear();
      _connectedHat   = null;
      _hatCommandChar = null;
      _error          = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _connectGeneric(BluetoothDevice device) async {
    _error = null;
    notifyListeners();
    try {
      await device.connect(timeout: const Duration(seconds: 15));
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // ── Internal helpers ───────────────────────────────────────────────────────
  void _cancelNewScan() {
    _scanTimer?.cancel();
    _scanTimer = null;
    for (final s in _scanSubs) s.cancel();
    _scanSubs.clear();
    _isScanning = false;
  }

  void _cleanup() {
    _scanTimer?.cancel();       _scanTimer      = null;
    _postTimer?.cancel();       _postTimer      = null;
    _reconnectTimer?.cancel();  _reconnectTimer = null;
    for (final s in _subs) s.cancel();
    _subs.clear();
  }

  void _setState(BLEState s) {
    _state = s;
    notifyListeners();
  }

  List<ScannedDevice> _sortDevices(List<ScannedDevice> devices) {
    return devices
      ..sort((a, b) {
        final kindCmp = a.kind.sortPriority.compareTo(b.kind.sortPriority);
        if (kindCmp != 0) return kindCmp;
        return b.rssi.compareTo(a.rssi); // stronger signal first
      });
  }

  @override
  void dispose() {
    _cleanup();
    _cancelNewScan();
    for (final s in _hatSubs) s.cancel();
    super.dispose();
  }
}

// ── MAC address validation ─────────────────────────────────────────────────────
bool isValidMac(String mac) {
  final re = RegExp(r'^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$');
  return re.hasMatch(mac);
}

// ── Android permission helper ──────────────────────────────────────────────────
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
    final anyPermanent =
        statuses.values.any((s) => s == PermissionStatus.permanentlyDenied);
    if (anyPermanent) openAppSettings();
  }

  return allGranted;
}
