/// Lightweight representation of a discovered Muse 2 BLE device.
class MuseDevice {
  final String id;    // BLE device ID (MAC on Android, UUID on iOS)
  final String name;
  final int rssi;

  const MuseDevice({required this.id, required this.name, required this.rssi});

  @override
  bool operator ==(Object other) => other is MuseDevice && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
