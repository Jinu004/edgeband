import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:jv/src/screens/wifi_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/ble_provision_service.dart';

class BluetoothScanScreen extends StatefulWidget {
  const BluetoothScanScreen({super.key});

  @override
  State<BluetoothScanScreen> createState() => _BluetoothScanScreenState();
}

class _BluetoothScanScreenState extends State<BluetoothScanScreen>
    with TickerProviderStateMixin {
  final BleProvisionService bleService = BleProvisionService();

  List<BluetoothDevice> devices = [];
  BluetoothDevice? selectedDevice;
  String connectionStatus = "Not Connected";
  bool scanning = false;
  bool connecting = false;

  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _fadeController.forward();
    _checkPermissions();
  }

  /// Check and request necessary permissions
  Future<void> _checkPermissions() async {
    await Permission.location.request();
  }

  /// Scan for ESP32 devices
  Future<void> scanForDevices() async {
    setState(() {
      scanning = true;
    });

    _pulseController.repeat(reverse: true);

    devices = await bleService.scanForDevices();

    setState(() {
      scanning = false;
    });

    _pulseController.stop();
    _pulseController.reset();
  }

  /// Connect to selected ESP32
  Future<void> connectToDevice(BluetoothDevice device) async {
    setState(() {
      connecting = true;
      connectionStatus = "Connecting...";
    });

    try {
      await bleService.connectToDevice(device, (status) {
        setState(() {
          connectionStatus = status;
        });
      });

      setState(() {
        selectedDevice = device;
        connectionStatus = "Connected to ${device.name}";
        connecting = false;
      });

      // Show success message and navigate to WiFi setup after a short delay
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully connected to ${device.name}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // Navigate to WiFi setup screen after connection
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WiFiSetupScreen(
              connectedDevice: device,
              bleService: bleService,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        connectionStatus = "Connection failed: $e";
        connecting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _getStatusColor() {
    if (connectionStatus.contains("Connected")) return Colors.green;
    if (connectionStatus.contains("Connecting")) return Colors.orange;
    if (connectionStatus.contains("failed") || connectionStatus.contains("Failed")) return Colors.red;
    return Colors.grey;
  }

  IconData _getStatusIcon() {
    if (connectionStatus.contains("Connected")) return Icons.check_circle;
    if (connectionStatus.contains("Connecting")) return Icons.sync;
    if (connectionStatus.contains("failed") || connectionStatus.contains("Failed")) return Icons.error;
    return Icons.bluetooth;
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
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
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Machine Setup - Step 1',
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
                        Icons.bluetooth,
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
                        color: Color(0xFF3b82f6),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          '1',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 2,
                        color: Colors.grey.withOpacity(0.3),
                      ),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          '2',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Main content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
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
                              Icons.info_outline,
                              size: 32,
                              color: const Color(0xFF3b82f6),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Connect to Device',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'First, we need to connect to your ESP32 device via Bluetooth. Make sure your device is in pairing mode.',
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

                    // Scan section
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        width: double.infinity,
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
                          children: [
                            Icon(
                              scanning ? Icons.bluetooth_searching : Icons.bluetooth,
                              size: 48,
                              color: const Color(0xFF3b82f6),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Device Discovery',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Scan for nearby ESP32 devices',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: scanning
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
                                        'Scanning...',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                                  : ScaleTransition(
                                scale: scanning ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                                child: ElevatedButton.icon(
                                  onPressed: scanForDevices,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF3b82f6),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 4,
                                  ),
                                  icon: const Icon(Icons.search),
                                  label: const Text(
                                    'Scan for Devices',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Device list
                    if (devices.isNotEmpty)
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
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
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'Available Devices',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: devices.length,
                                separatorBuilder: (context, index) => Divider(
                                  color: Colors.grey.withOpacity(0.2),
                                  height: 1,
                                ),
                                itemBuilder: (context, index) {
                                  final device = devices[index];
                                  final isSelected = selectedDevice?.id == device.id;

                                  return Container(
                                    color: isSelected ? const Color(0xFF3b82f6).withOpacity(0.1) : null,
                                    child: ListTile(
                                      leading: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isSelected ? const Color(0xFF3b82f6) : Colors.grey.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.device_hub,
                                          color: isSelected ? Colors.white : Colors.grey,
                                          size: 20,
                                        ),
                                      ),
                                      title: Text(
                                        device.name.isNotEmpty ? device.name : "Unknown Device",
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                        ),
                                      ),
                                      subtitle: Text(
                                        device.id.toString(),
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                      trailing: isSelected
                                          ? const Icon(Icons.check_circle, color: Color(0xFF3b82f6))
                                          : connecting
                                          ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                          : TextButton(
                                        onPressed: () => connectToDevice(device),
                                        style: TextButton.styleFrom(
                                          backgroundColor: const Color(0xFF3b82f6).withOpacity(0.1),
                                          foregroundColor: const Color(0xFF3b82f6),
                                        ),
                                        child: const Text('Connect'),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 20),

                    // Status section
                    if (connectionStatus != "Not Connected")
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
                                _getStatusIcon(),
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