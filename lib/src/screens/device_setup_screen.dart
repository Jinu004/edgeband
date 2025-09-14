import 'package:flutter/material.dart';
import '../services/ble_provision_service.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class DeviceSetupScreen extends StatefulWidget {
  const DeviceSetupScreen({super.key});

  @override
  State<DeviceSetupScreen> createState() => _DeviceSetupScreenState();
}

class _DeviceSetupScreenState extends State<DeviceSetupScreen> {
  final BleProvisionService bleService = BleProvisionService();
  bool scanning = false;
  List<ScanResult> devices = [];
  ScanResult? selected;
  final ssidCtl = TextEditingController();
  final passCtl = TextEditingController();
  String status = '';

  Future<void> doScan() async {
    setState(() {
      scanning = true;
      devices = [];
      status = 'Scanning...';
    });
    try {
      await bleService.startScan();
      setState(() {
        devices = bleService.found;
        status = 'Scan complete';
      });
    } catch (e) {
      setState(() {
        status = 'Scan error: $e';
      });
    } finally {
      setState(() {
        scanning = false;
      });
    }
  }

  Future<void> provision() async {
    if (selected == null) {
      setState(() {
        status = 'Select a device first';
      });
      return;
    }

    setState(() {
      status = 'Connecting...';
    });

    try {
      // ✅ stop scanning before connecting
      await bleService.stopScan();

      // ✅ connect to the actual BluetoothDevice
      await bleService.connectToDevice(selected!.device);

      setState(() {
        status = 'Provisioning...';
      });

      // ✅ send credentials
      await bleService.provisionWifi(
        ssidCtl.text.trim(),
        passCtl.text.trim(),
      );

      setState(() {
        status = 'Provision succeeded';
      });

      await bleService.disconnect();
    } catch (e) {
      setState(() {
        status = 'Provision error: $e';
      });
    }
  }

  @override
  void dispose() {
    ssidCtl.dispose();
    passCtl.dispose();
    bleService.stopScan(); // ✅ ensure scan stops when leaving screen
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Device Setup (BLE)')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: scanning ? null : doScan,
              child: Text(scanning ? 'Scanning...' : 'Scan for Devices'),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: devices.length,
                itemBuilder: (c, i) {
                  final r = devices[i];
                  return ListTile(
                    title: Text(
                        r.device.name.isEmpty ? r.device.remoteId.str : r.device.name),
                    subtitle: Text(r.device.remoteId.str),
                    selected: selected?.device.remoteId == r.device.remoteId,
                    onTap: () async {
                      setState(() => selected = r);
                      await bleService.stopScan(); // ✅ stop scanning on selection
                    },
                  );
                },
              ),
            ),
            TextField(
              controller: ssidCtl,
              decoration: const InputDecoration(labelText: 'Wi-Fi SSID'),
            ),
            TextField(
              controller: passCtl,
              decoration: const InputDecoration(labelText: 'Wi-Fi Password'),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: provision,
              child: const Text('Send Credentials'),
            ),
            const SizedBox(height: 8),
            Text(status),
          ],
        ),
      ),
    );
  }
}
