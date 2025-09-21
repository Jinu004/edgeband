import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleProvisionService {
  // ESP32 UUIDs (replace with yours)



  // UUIDs matching ESP32 code
  final String serviceUUID = "12345678-1234-1234-1234-123456789abc";
  final String wifiCharUUID = "87654321-4321-4321-4321-cba987654321";
  final String statusCharUUID = "11223344-5566-7788-9900-aabbccddeeff";
  final String resetCharUUID = "99887766-5544-3322-1100-ffeeddccbbaa";


  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _wifiCharacteristic;
  BluetoothCharacteristic? _statusCharacteristic;
  BluetoothCharacteristic? _resetCharacteristic;

  final List<BluetoothDevice> devicesList = [];
  bool isConnected = false;

  /// Scan for devices advertising as ESP32
  Future<List<BluetoothDevice>> scanForDevices() async {
    devicesList.clear();

    // Start scanning
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));

    // Listen for scan results
    FlutterBluePlus.scanResults.listen((results) {
      for (var r in results) {
        // Add device if not already in list
        if (!devicesList.contains(r.device)) {
          devicesList.add(r.device);
          print("Found device: ${r.device.name} (${r.device.id})");
        }
      }
    });

    // Wait for scan duration
    await Future.delayed(const Duration(seconds: 8));

    // Stop scanning
    await FlutterBluePlus.stopScan();

    return devicesList;
  }


  /// Connect to a specific device
  Future<void> connectToDevice(BluetoothDevice device, void Function(String) onStatusUpdate) async {
    _connectedDevice = device;
    await device.connect();
    isConnected = true;

    List<BluetoothService> services = await device.discoverServices();
    for (BluetoothService service in services) {
      if (service.uuid.toString().toLowerCase() == serviceUUID.toLowerCase()) {
        for (BluetoothCharacteristic c in service.characteristics) {
          if (c.uuid.toString().toLowerCase() == wifiCharUUID.toLowerCase()) {
            _wifiCharacteristic = c;
          }
          if (c.uuid.toString().toLowerCase() == resetCharUUID.toLowerCase()) {
            _resetCharacteristic = c;
          }
          if (c.uuid.toString().toLowerCase() == statusCharUUID.toLowerCase()) {
            _statusCharacteristic = c;

            // Subscribe to notifications
            await c.setNotifyValue(true);
            c.value.listen((value) {
              final response = utf8.decode(value);
              onStatusUpdate(response); // pass to UI
            });
          }
        }
      }
    }

    if (_wifiCharacteristic == null || _statusCharacteristic == null) {
      throw Exception("ESP32 missing expected characteristics");
    }
  }

  /// Send Wi-Fi credentials as JSON
  Future<void> sendWifiCredentials(String ssid, String password) async {
    if (_wifiCharacteristic == null) {
      throw Exception("Not connected to ESP32");
    }

    final creds = {"ssid": ssid, "password": password};
    final jsonString = json.encode(creds);
    await _wifiCharacteristic!.write(utf8.encode(jsonString));
  }

  /// Clear saved credentials on ESP32
  Future<void> resetWifiCredentials() async {
    if (_resetCharacteristic == null) {
      throw Exception("Not connected to ESP32");
    }
    await _resetCharacteristic!.write([1]); // trigger reset
  }

  /// Disconnect
  Future<void> disconnect() async {
    await _connectedDevice?.disconnect();
    _connectedDevice = null;
    isConnected = false;
  }
}