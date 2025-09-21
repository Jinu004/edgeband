import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:wifi_scan/wifi_scan.dart';
import '../services/ble_provision_service.dart';

class WiFiSetupScreen extends StatefulWidget {
  final BluetoothDevice connectedDevice;
  final BleProvisionService bleService;

  const WiFiSetupScreen({
    super.key,
    required this.connectedDevice,
    required this.bleService,
  });

  @override
  State<WiFiSetupScreen> createState() => _WiFiSetupScreenState();
}

class _WiFiSetupScreenState extends State<WiFiSetupScreen>
    with TickerProviderStateMixin {
  List<WiFiAccessPoint> wifiNetworks = [];
  WiFiAccessPoint? selectedWifiNetwork;
  String connectionStatus = "Ready to scan WiFi networks";
  String password = "";

  final passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool scanningWifi = false;
  bool sendingCredentials = false;
  bool _obscurePassword = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _fadeController.forward();

    // Automatically scan for WiFi networks when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scanForWifiNetworks();
    });
  }

  /// Scan for WiFi networks
  Future<void> scanForWifiNetworks() async {
    setState(() {
      scanningWifi = true;
      wifiNetworks = [];
      connectionStatus = "Scanning for WiFi networks...";
    });

    try {
      final canGetScannedResults = await WiFiScan.instance.canGetScannedResults();
      if (canGetScannedResults != CanGetScannedResults.yes) {
        throw Exception('WiFi scanning not supported');
      }

      final canStartScan = await WiFiScan.instance.canStartScan();
      if (canStartScan == CanStartScan.yes) {
        await WiFiScan.instance.startScan();
        await Future.delayed(const Duration(seconds: 3));
      }

      final results = await WiFiScan.instance.getScannedResults();

      final uniqueNetworks = <String, WiFiAccessPoint>{};
      for (final network in results) {
        if (network.ssid.isNotEmpty) {
          final existing = uniqueNetworks[network.ssid];
          if (existing == null || network.level > existing.level) {
            uniqueNetworks[network.ssid] = network;
          }
        }
      }

      final sortedNetworks = uniqueNetworks.values.toList()
        ..sort((a, b) => b.level.compareTo(a.level));

      setState(() {
        wifiNetworks = sortedNetworks;
        scanningWifi = false;
        connectionStatus = "Found ${sortedNetworks.length} WiFi networks";
      });
    } catch (e) {
      setState(() {
        scanningWifi = false;
        connectionStatus = "Failed to scan WiFi networks: $e";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to scan WiFi networks: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Send Wi-Fi credentials to ESP32
  Future<void> provisionWifi() async {
    if (!_formKey.currentState!.validate() || selectedWifiNetwork == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a WiFi network and enter password'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      sendingCredentials = true;
      connectionStatus = "Sending credentials to device...";
    });

    password = passwordController.text.trim();

    try {
      await widget.bleService.sendWifiCredentials(selectedWifiNetwork!.ssid, password);

      setState(() {
        sendingCredentials = false;
        connectionStatus = "Credentials sent successfully! Device is connecting to WiFi...";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wi-Fi credentials sent successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Show completion dialog
      _showCompletionDialog();

    } catch (e) {
      setState(() {
        sendingCredentials = false;
        connectionStatus = "Failed to send credentials: $e";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send credentials: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 28,
              ),
              SizedBox(width: 12),
              Text('Setup Complete!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your device has been successfully configured:'),
              SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.bluetooth, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(child: Text('Connected to ${widget.connectedDevice.name}')),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.wifi, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Expanded(child: Text('WiFi: ${selectedWifiNetwork!.ssid}')),
                ],
              ),
              SizedBox(height: 16),
              Text(
                'Your device should now be connected to the WiFi network. You can disconnect from Bluetooth.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Go back to previous screen
                Navigator.of(context).pop(); // Go back to main screen
              },
              child: Text('Done'),
            ),
          ],
        );
      },
    );
  }

  /// Disconnect and go back
  Future<void> goBack() async {
    await widget.bleService.disconnect();
    Navigator.pop(context);
  }

  int _getWifiSignalIcon(int level) {
    if (level >= -50) return 4;
    if (level >= -60) return 3;
    if (level >= -70) return 2;
    if (level >= -80) return 1;
    return 0;
  }

  IconData _getWifiIcon(int signalLevel) {
    switch (signalLevel) {
      case 4: return Icons.signal_wifi_4_bar;
      case 3: return Icons.signal_wifi_4_bar;
      case 2: return Icons.network_wifi_2_bar;
      case 1: return Icons.network_wifi_1_bar;
      default: return Icons.signal_wifi_off;
    }
  }

  Color _getStatusColor() {
    if (connectionStatus.contains("successfully") || connectionStatus.contains("Complete")) return Colors.green;
    if (connectionStatus.contains("Scanning") || connectionStatus.contains("Sending")) return Colors.orange;
    if (connectionStatus.contains("Failed") || connectionStatus.contains("failed")) return Colors.red;
    return Colors.blue;
  }

  @override
  void dispose() {
    _fadeController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Custom App Bar
            FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: goBack,
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Machine Setup - Step 2',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3b82f6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.wifi,
                        color: Color(0xFF3b82f6),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Progress indicator
            FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 2,
                        color: const Color(0xFF3b82f6),
                      ),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFF3b82f6),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          '2',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Device info card
            FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.bluetooth_connected,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Connected Device',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            widget.connectedDevice.name.isNotEmpty
                                ? widget.connectedDevice.name
                                : "Unknown Device",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),

            // Main content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Instruction card
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3b82f6).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF3b82f6).withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.wifi_find,
                              size: 32,
                              color: const Color(0xFF3b82f6),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Configure WiFi',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Now select your WiFi network and enter the password to connect your device to the internet.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // WiFi Networks section
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.2),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.wifi,
                                      color: Color(0xFF3b82f6),
                                      size: 24,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'WiFi Networks',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                                TextButton.icon(
                                  onPressed: scanningWifi ? null : scanForWifiNetworks,
                                  icon: scanningWifi
                                      ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                      : const Icon(Icons.refresh),
                                  label: Text(scanningWifi ? 'Scanning...' : 'Refresh'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            if (wifiNetworks.isEmpty && !scanningWifi)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Text(
                                    'No WiFi networks found. Tap refresh to scan again.',
                                    style: TextStyle(color: Colors.grey),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                            else if (scanningWifi)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Column(
                                    children: [
                                      CircularProgressIndicator(),
                                      SizedBox(height: 12),
                                      Text(
                                        'Scanning for WiFi networks...',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              Container(
                                constraints: const BoxConstraints(maxHeight: 250),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: wifiNetworks.length,
                                  separatorBuilder: (context, index) => Divider(
                                    color: Colors.grey.withOpacity(0.2),
                                    height: 1,
                                  ),
                                  itemBuilder: (context, index) {
                                    final network = wifiNetworks[index];
                                    final isSelected = selectedWifiNetwork?.ssid == network.ssid;
                                    final signalLevel = _getWifiSignalIcon(network.level);

                                    return Container(
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFF3b82f6).withOpacity(0.1) : null,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: ListTile(
                                        leading: Icon(
                                          _getWifiIcon(signalLevel),
                                          color: isSelected ? const Color(0xFF3b82f6) : Colors.grey,
                                        ),
                                        title: Text(
                                          network.ssid,
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                          ),
                                        ),
                                        subtitle: Row(
                                          children: [
                                            Icon(
                                              network.capabilities.contains('WEP') || network.capabilities.contains('WPA')
                                                  ? Icons.lock_outline
                                                  : Icons.lock_open_outlined,
                                              size: 14,
                                              color: Colors.grey,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${network.level} dBm',
                                              style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                        trailing: isSelected
                                            ? const Icon(Icons.check_circle, color: Color(0xFF3b82f6))
                                            : null,
                                        onTap: () {
                                          setState(() {
                                            selectedWifiNetwork = network;
                                          });
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Wi-Fi password form
                    if (selectedWifiNetwork != null)
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.2),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.lock_outline,
                                      color: Color(0xFF3b82f6),
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'WiFi Password',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                          ),
                                          Text(
                                            'Network: ${selectedWifiNetwork!.ssid}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Password field
                                TextFormField(
                                  controller: passwordController,
                                  obscureText: _obscurePassword,
                                  style: const TextStyle(color: Colors.black),
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    labelStyle: const TextStyle(color: Colors.grey),
                                    prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                        color: Colors.grey,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFF3b82f6), width: 2),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey.withOpacity(0.05),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter WiFi password';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),

                                // Send credentials button
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: sendingCredentials
                                      ? Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF3b82f6).withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Center(
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            'Sending Credentials...',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                      : ElevatedButton.icon(
                                    onPressed: provisionWifi,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF3b82f6),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 4,
                                    ),
                                    icon: const Icon(Icons.send, size: 18),
                                    label: const Text(
                                      'Connect Device to WiFi',
                                      style: TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 20),

                    // Status section
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _getStatusColor().withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getStatusColor().withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              scanningWifi || sendingCredentials
                                  ? Icons.sync
                                  : connectionStatus.contains("successfully")
                                  ? Icons.check_circle
                                  : connectionStatus.contains("Failed")
                                  ? Icons.error
                                  : Icons.info,
                              color: _getStatusColor(),
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                connectionStatus,
                                style: TextStyle(
                                  color: _getStatusColor(),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}