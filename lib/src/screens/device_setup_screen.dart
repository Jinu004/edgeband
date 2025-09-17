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
  bool connecting = false;
  bool provisioning = false;
  List<ScanResult> devices = [];
  ScanResult? selected;
  final ssidCtl = TextEditingController();
  final passCtl = TextEditingController();
  String status = '';
  bool showPassword = false;
  int currentStep = 0; // 0: scan, 1: credentials, 2: provision

  Future<void> doScan() async {
    setState(() {
      scanning = true;
      devices = [];
      status = 'Searching for nearby devices...';
      selected = null;
    });

    try {
      await bleService.startScan();
      setState(() {
        devices = bleService.found;
        status = devices.isEmpty
            ? 'No devices found. Make sure your device is in pairing mode.'
            : 'Found ${devices.length} device${devices.length > 1 ? 's' : ''}';
      });
    } catch (e) {
      setState(() {
        status = 'Failed to scan: $e';
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
        status = 'Please select a device first';
      });
      return;
    }

    if (ssidCtl.text.trim().isEmpty) {
      setState(() {
        status = 'Please enter Wi-Fi SSID';
      });
      return;
    }

    setState(() {
      connecting = true;
      status = 'Connecting to device...';
    });

    try {
      await bleService.stopScan();
      await bleService.connectToDevice(selected!.device);

      setState(() {
        connecting = false;
        provisioning = true;
        status = 'Sending Wi-Fi credentials...';
      });

      await bleService.provisionWifi(
        ssidCtl.text.trim(),
        passCtl.text.trim(),
      );

      setState(() {
        status = 'Device configured successfully!';
        currentStep = 2;
      });

      await bleService.disconnect();

      // Show success for a moment then navigate back
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pop(context);
        }
      });

    } catch (e) {
      setState(() {
        status = 'Configuration failed: $e';
      });
    } finally {
      setState(() {
        connecting = false;
        provisioning = false;
      });
    }
  }

  @override
  void dispose() {
    ssidCtl.dispose();
    passCtl.dispose();
    bleService.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text(
          'Device Setup',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            _buildHeaderSection(),

            const SizedBox(height: 32),

            // Step Indicator
            _buildStepIndicator(),

            const SizedBox(height: 32),

            // Device Scan Section
            _buildDeviceScanSection(),

            const SizedBox(height: 24),

            // Wi-Fi Credentials Section
            if (selected != null) _buildWifiCredentialsSection(),

            const SizedBox(height: 24),

            // Status Section
            _buildStatusSection(),

            const SizedBox(height: 32),

            // Action Button
            _buildActionButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.bluetooth, color: Colors.blue, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bluetooth Setup',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Configure your device Wi-Fi connection',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          _buildStepItem(0, 'Scan', Icons.bluetooth_searching, currentStep >= 0),
          Expanded(child: Container(height: 2, color: Colors.grey[200])),
          _buildStepItem(1, 'Connect', Icons.wifi, selected != null),
          Expanded(child: Container(height: 2, color: Colors.grey[200])),
          _buildStepItem(2, 'Done', Icons.check_circle, currentStep >= 2),
        ],
      ),
    );
  }

  Widget _buildStepItem(int step, String label, IconData icon, bool isActive) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isActive ? Colors.blue : Colors.grey[200],
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: isActive ? Colors.white : Colors.grey[500],
            size: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isActive ? Colors.blue : Colors.grey[500],
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceScanSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.devices, color: Colors.grey[600], size: 20),
                const SizedBox(width: 8),
                Text(
                  'Available Devices',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const Spacer(),
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: scanning ? Colors.grey[100] : Colors.blue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: scanning ? null : doScan,
                    icon: scanning
                        ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
                      ),
                    )
                        : const Icon(Icons.refresh, size: 18),
                    label: Text(
                      scanning ? 'Scanning...' : 'Scan',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: scanning ? Colors.grey[100] : Colors.blue,
                      foregroundColor: scanning ? Colors.grey[600] : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (devices.isNotEmpty) const Divider(height: 1),
          if (devices.isEmpty && !scanning)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.bluetooth_disabled, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No devices found',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Make sure your device is in pairing mode',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final result = devices[index];
              final isSelected = selected?.device.remoteId == result.device.remoteId;

              return Container(
                margin: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: index == devices.length - 1 ? 16 : 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
                ),
                child: ListTile(
                  onTap: () async {
                    setState(() => selected = result);
                    await bleService.stopScan();
                  },
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue : Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.bluetooth,
                      color: isSelected ? Colors.white : Colors.grey[600],
                      size: 20,
                    ),
                  ),
                  title: Text(
                    result.device.name.isEmpty ? 'Unknown Device' : result.device.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.blue : Colors.grey[800],
                    ),
                  ),
                  subtitle: Text(
                    result.device.remoteId.str,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected ? Colors.blue[700] : Colors.grey[600],
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Colors.blue)
                      : null,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWifiCredentialsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.wifi, color: Colors.grey[600], size: 20),
              const SizedBox(width: 8),
              Text(
                'Wi-Fi Credentials',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: ssidCtl,
            decoration: InputDecoration(
              labelText: 'Network Name (SSID)',
              hintText: 'Enter your Wi-Fi network name',
              prefixIcon: const Icon(Icons.wifi),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.blue, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: passCtl,
            obscureText: !showPassword,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter your Wi-Fi password',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(
                  showPassword ? Icons.visibility : Icons.visibility_off,
                  color: Colors.grey[600],
                ),
                onPressed: () => setState(() => showPassword = !showPassword),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.blue, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    if (status.isEmpty) return const SizedBox.shrink();

    Color statusColor = Colors.blue;
    IconData statusIcon = Icons.info;

    if (status.contains('error') || status.contains('Failed') || status.contains('failed')) {
      statusColor = Colors.red;
      statusIcon = Icons.error;
    } else if (status.contains('success') || status.contains('succeeded')) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (connecting || provisioning || scanning) {
      statusColor = Colors.orange;
      statusIcon = Icons.hourglass_empty;
    }

    return Container(
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    final canProvision = selected != null && ssidCtl.text.trim().isNotEmpty;
    final isLoading = connecting || provisioning;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: (canProvision && !isLoading) ? provision : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[300],
          disabledForegroundColor: Colors.grey[600],
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading) ...[
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Text(
              isLoading
                  ? (connecting ? 'Connecting...' : 'Configuring...')
                  : 'Configure Device',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}