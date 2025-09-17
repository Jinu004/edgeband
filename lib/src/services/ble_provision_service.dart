import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleProvisionService {

  // Replace these UUIDs with your ESP32’s values
  static const String serviceUuid = "12345678-1234-5678-1234-56789abcdef0";
  static const String scanCharUuid = "abc1";
  static const String credCharUuid = "abc2";
  static const String statusCharUuid = "abc3";

  final List<ScanResult> found = [];
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _scanChar;
  BluetoothCharacteristic? _credChar;
  BluetoothCharacteristic? _statusChar;

  /// Start scanning for devices
  Future<void> startScan() async {
    found.clear();
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    await for (final results in FlutterBluePlus.scanResults) {
      for (var r in results) {
        if (!found.any((d) => d.device.remoteId == r.device.remoteId)) {
          found.add(r);
        }
      }
    }
  }

  /// Stop scanning
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  /// Connect to selected device
  Future<void> connectToDevice(BluetoothDevice device) async {
    _connectedDevice = device;
    await device.connect(autoConnect: false);

    List<BluetoothService> services = await device.discoverServices();
    for (var s in services) {
      if (s.uuid.toString() == serviceUuid) {
        for (var c in s.characteristics) {
          if (c.uuid.toString().endsWith(scanCharUuid)) {
            _scanChar = c;
          }
          if (c.uuid.toString().endsWith(credCharUuid)) {
            _credChar = c;
          }
          if (c.uuid.toString().endsWith(statusCharUuid)) {
            _statusChar = c;
          }
        }
      }
    }

    if (_scanChar == null || _credChar == null || _statusChar == null) {
      throw Exception("Device missing expected characteristics");
    }
  }

  /// Provision Wi-Fi credentials
  Future<void> provisionWifi(String ssid, String password) async {
    if (_credChar == null || _statusChar == null) {
      throw Exception("Not connected to device");
    }

    final creds = "$ssid|$password";
    await _credChar!.write(creds.codeUnits, withoutResponse: true);

    // Optional: wait and check status
    await Future.delayed(const Duration(seconds: 3));
    final statusData = await _statusChar!.read();
    final status = String.fromCharCodes(statusData);

    if (status.toLowerCase().contains("fail")) {
      throw Exception("Wi-Fi connection failed");
    }
  }

  /// Disconnect
  Future<void> disconnect() async {
    await _connectedDevice?.disconnect();
    _connectedDevice = null;
  }
}
