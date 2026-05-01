import 'package:flutter_blue_plus/flutter_blue_plus.dart';

enum BleDeviceKind { muse, sentioHat, other }

extension BleDeviceKindX on BleDeviceKind {
  String get typeLabel => switch (this) {
        BleDeviceKind.muse => 'EEG Headband',
        BleDeviceKind.sentioHat => 'Smart LED Hat',
        BleDeviceKind.other => 'Bluetooth Device',
      };

  // Lower = higher priority in sorted device list
  int get sortPriority => switch (this) {
        BleDeviceKind.muse => 0,
        BleDeviceKind.sentioHat => 1,
        BleDeviceKind.other => 2,
      };

  static BleDeviceKind classify(String name) {
    if (name.contains('Muse')) return BleDeviceKind.muse;
    if (name.contains('SENTIO Hat')) return BleDeviceKind.sentioHat;
    return BleDeviceKind.other;
  }
}

class ScannedDevice {
  final BluetoothDevice device;
  final int rssi;
  final BleDeviceKind kind;

  const ScannedDevice({
    required this.device,
    required this.rssi,
    required this.kind,
  });

  String get name {
    final n = device.platformName;
    return n.isNotEmpty ? n : device.remoteId.str;
  }

  String get signalLabel {
    if (rssi >= -60) return 'Strong';
    if (rssi >= -75) return 'Medium';
    return 'Weak';
  }

  @override
  bool operator ==(Object other) =>
      other is ScannedDevice && other.device.remoteId == device.remoteId;

  @override
  int get hashCode => device.remoteId.hashCode;
}
