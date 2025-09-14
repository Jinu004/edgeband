import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleProvisionService {
  StreamSubscription<List<ScanResult>>? _scanSub;
  final List<ScanResult> found = [];
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _wifiChar;

  /// Start scanning for BLE devices
  Future<void> startScan({Duration duration = const Duration(seconds: 6)}) async {
    found.clear();
    await _scanSub?.cancel();

    await FlutterBluePlus.startScan(
      timeout: duration,
      continuousUpdates: true,
      androidUsesFineLocation: true,
    );

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        if (!found.any((e) => e.device.remoteId == r.device.remoteId)) {
          found.add(r);
        }
      }
    });
  }

  /// Stop scanning
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();
    _scanSub = null;
  }

  /// Connect to selected device
  Future<void> connectToDevice(BluetoothDevice device) async {
    _connectedDevice = device;
    await device.connect();

    // Discover services & characteristics
    List<BluetoothService> services = await device.discoverServices();
    for (var s in services) {
      for (var c in s.characteristics) {
        // replace with your ESP32's custom UUID
        if (c.properties.write && c.uuid.toString().contains("fff1")) {
          _wifiChar = c;
        }
      }
    }
  }

  /// Send Wi-Fi credentials over BLE
  Future<void> provisionWifi(String ssid, String password) async {
    if (_wifiChar == null) {
      throw Exception("WiFi characteristic not found");
    }
    final payload = jsonEncode({
      "ssid": ssid,
      "password": password,
    });
    await _wifiChar!.write(utf8.encode(payload), withoutResponse: false);
  }

  /// Disconnect from device
  Future<void> disconnect() async {
    await _connectedDevice?.disconnect();
    _connectedDevice = null;
    _wifiChar = null;
  }
}
