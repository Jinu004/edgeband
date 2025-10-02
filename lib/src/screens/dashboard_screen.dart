import 'dart:io';
import 'package:flutter/material.dart';
import 'package:jv/src/screens/cutting_log_screen.dart';
import 'package:jv/src/screens/settings%20screen.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/auth_provider.dart';
import '../providers/machine_provider.dart';
import '../models/machine_data.dart';
import 'device_setup_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  final machineId = 'machine-1';
  bool exporting = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final machineProv = Provider.of<MachineProvider>(context, listen: false);
    // Watch machine data updates
    machineProv.watch(machineId).listen((m) {
      if (m != null) machineProv.setCurrent(m);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> historyStream() {
    return FirebaseFirestore.instance
        .collection('machines')
        .doc(machineId)
        .collection('history')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> cuttingLogsStream() {
    return FirebaseFirestore.instance
        .collection('cuttingLogs')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots();
  }

  Future<Map<String, double>> getCuttingLogTotals() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final snapshot = await FirebaseFirestore.instance
          .collection('cuttingLogs')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
          .get();

      double dailyTotal = 0;
      double weeklyTotal = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final actualLength = (data['actualLength'] as num?)?.toDouble() ?? 0;
        final timestamp = (data['timestamp'] as Timestamp).toDate();

        if (timestamp.isAfter(today)) dailyTotal += actualLength;

        if (timestamp.isAfter(now.subtract(const Duration(days: 7)))) weeklyTotal += actualLength;
      }
      return {'daily': dailyTotal, 'weekly': weeklyTotal};
    } catch (e) {
      return {'daily': 0.0, 'weekly': 0.0};
    }
  }

  Future<void> exportExcel() async {
    setState(() => exporting = true);
    try {
      final cuttingLogsSnap = await FirebaseFirestore.instance
          .collection('cuttingLogs')
          .orderBy('timestamp')
          .get();

      final excel = Excel.createExcel();
      final cuttingSheet = excel['Sheet1'];

      final summarySheet = excel['Summary'];
      final totals = await getCuttingLogTotals();

      // Cutting Logs headers
      const cuttingHeaders = [
        'Date & Time',
        'Target Length (m)',
        // 'Actual Length (m)',
        // 'Accuracy (%)',
        // 'Cut Duration (s)',
      ];
      for (var i = 0; i < cuttingHeaders.length; i++) {
        cuttingSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value = cuttingHeaders[i];
        cuttingSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: '#E8F5E8',
          fontColorHex: '#2E7D32',
        );
      }

      int row = 1;
      for (var doc in cuttingLogsSnap.docs) {
        final data = doc.data();

        // Use formattedTime instead of timestamp
        final formattedTime = data['formattedTime'] as String? ?? '';

        cuttingSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = formattedTime;
        cuttingSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = data['targetLength'] ?? 0;
        // cuttingSheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = data['actualLength'] ?? 0;
        // cuttingSheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = data['accuracy'] ?? 0;
        // cuttingSheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = data['cutDuration'] ?? 0;
        row++;
      }

      // Summary sheet
      summarySheet.cell(CellIndex.indexByString('A1')).value = 'Summary Report';
      summarySheet.cell(CellIndex.indexByString('A1')).cellStyle = CellStyle(
        bold: true,
        fontSize: 16,
        backgroundColorHex: '#FFF3E0',
        fontColorHex: '#F57C00',
      );

      summarySheet.cell(CellIndex.indexByString('A3')).value = 'Export Date';
      summarySheet.cell(CellIndex.indexByString('B3')).value = DateTime.now().toIso8601String();
      summarySheet.cell(CellIndex.indexByString('A4')).value = 'Daily Total (m)';
      summarySheet.cell(CellIndex.indexByString('B4')).value = totals['daily']?.toStringAsFixed(2);
      summarySheet.cell(CellIndex.indexByString('A5')).value = 'Weekly Total (m)';
      summarySheet.cell(CellIndex.indexByString('B5')).value = totals['weekly']?.toStringAsFixed(2);
      summarySheet.cell(CellIndex.indexByString('A6')).value = 'Total Cutting Records';
      summarySheet.cell(CellIndex.indexByString('B6')).value = cuttingLogsSnap.docs.length;

      for (int r = 2; r < 7; r++) {
        summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r)).cellStyle = CellStyle(
          bold: true,
          fontColorHex: '#424242',
        );
      }

      final tmp = await getTemporaryDirectory();
      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final file = File('${tmp.path}/cutting_logs_$dateStr.xlsx');

      final excelBytes = excel.encode();
      if (excelBytes != null) {
        await file.writeAsBytes(excelBytes);
        await Share.shareXFiles([XFile(file.path)], text: 'Cutting Logs Excel Report');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Excel file exported successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Flexible(child: Text('Export failed: $e', overflow: TextOverflow.ellipsis)),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      setState(() => exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final machineProv = Provider.of<MachineProvider>(context);
    final MachineData? data = machineProv.current;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text(
          'Jv Interiors',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 28,
            color: Colors.black54,
            letterSpacing: 1.5,
            shadows: [
              Shadow(
                offset: Offset(1, 1),
                blurRadius: 3,
                color: Colors.black26,
              ),
            ],
            fontFamily: 'Montserrat',
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            tooltip: 'Settings',
          )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.blue[600],
              indicatorWeight: 4,
              labelColor: Colors.blue[600],
              unselectedLabelColor: Colors.grey[600],
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              tabs: const [
                Tab(icon: Icon(Icons.dashboard_outlined, size: 22), text: 'Status', height: 60),
                Tab(icon: Icon(Icons.analytics_outlined, size: 22), text: 'Sales History', height: 60),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _DashboardTab(data: data, machineId: machineId, exportExcel: exporting ? null : exportExcel, exporting: exporting),
          const CuttingLogsScreen(),
        ],
      ),
    );
  }
}

class _DashboardTab extends StatelessWidget {
  final MachineData? data;
  final String machineId;
  final Future<void> Function()? exportExcel;
  final bool exporting;

  const _DashboardTab({
    Key? key,
    required this.data,
    required this.machineId,
    required this.exportExcel,
    required this.exporting,
  }) : super(key: key);

  Stream<QuerySnapshot<Map<String, dynamic>>> cuttingLogsStream() {
    return FirebaseFirestore.instance
        .collection('cuttingLogs')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots();
  }

  Future<Map<String, double>> getCuttingLogTotals() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final snapshot = await FirebaseFirestore.instance
          .collection('cuttingLogs')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
          .get();

      double dailyTotal = 0;
      double weeklyTotal = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final actualLength = (data['actualLength'] as num?)?.toDouble() ?? 0;
        final timestamp = (data['timestamp'] as Timestamp).toDate();

        if (timestamp.isAfter(today)) dailyTotal += actualLength;

        if (timestamp.isAfter(now.subtract(const Duration(days: 7)))) weeklyTotal += actualLength;
      }
      return {'daily': dailyTotal, 'weekly': weeklyTotal};
    } catch (e) {
      return {'daily': 0.0, 'weekly': 0.0};
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Live Status Header
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: data?.isRunning == true ? Colors.green : Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                data?.isRunning == true ? 'Machine Running' : 'Machine Idle',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: data?.isRunning == true ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Status Cards Grid
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: cuttingLogsStream(),
            builder: (context, cuttingSnapshot) {
              double? latestActualLength;
              if (cuttingSnapshot.hasData && cuttingSnapshot.data!.docs.isNotEmpty) {
                final latestCut = cuttingSnapshot.data!.docs.first.data();
                latestActualLength = (latestCut['targetLength'] as num?)?.toDouble();
              }

              return FutureBuilder<Map<String, double>>(
                future: getCuttingLogTotals(),
                builder: (context, totalsSnapshot) {
                  final totals = totalsSnapshot.data ?? {'daily': 0.0, 'weekly': 0.0};

                  return GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.2,
                    children: [
                      _StatusCard(
                        title: 'Latest Cut Length',
                        value: latestActualLength != null
                            ? '${latestActualLength.toStringAsFixed(2)}'
                            : '—',
                        unit: 'm',
                        icon: Icons.content_cut,
                        color: Colors.blue,
                      ),
                      _StatusCard(
                        title: 'Today Total',
                        value: totals['daily']!.toStringAsFixed(2),
                        unit: 'm',
                        icon: Icons.today,
                        color: Colors.green,
                      ),
                      _StatusCard(
                        title: 'Weekly Total',
                        value: totals['weekly']!.toStringAsFixed(2),
                        unit: 'm',
                        icon: Icons.date_range,
                        color: Colors.purple,
                      ),
                      _StatusCard(
                        title: 'Machine Status',
                        value: data?.isRunning == true ? 'ACTIVE' : 'IDLE',
                        unit: '',
                        icon: data?.isRunning == true ? Icons.play_circle : Icons.pause_circle,
                        color: data?.isRunning == true ? Colors.green : Colors.orange,
                      ),
                    ],
                  );
                },
              );
            },
          ),

          const SizedBox(height: 32),

          // Quick Actions section
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const BluetoothScanScreen()),
                    );
                  },
                  icon: const Icon(Icons.settings),
                  label: const Text('Device Setup'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size.fromHeight(56),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: exporting ? null : exportExcel,
                  icon: exporting
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Icon(Icons.file_download),
                  label: Text(exporting ? 'Exporting...' : 'Export Excel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size.fromHeight(56),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Recent Cutting Activity Card
          _RecentCutsCard(),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _StatusCard({
    Key? key,
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(value,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                    overflow: TextOverflow.ellipsis),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 2),
                Text(unit, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentCutsCard extends StatelessWidget {
  const _RecentCutsCard({Key? key}) : super(key: key);


  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          children: [
            Icon(Icons.content_cut, color: Colors.grey[600], size: 20),
            const SizedBox(width: 8),
            Text('Recent Cuts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[800])),
          ],
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('cuttingLogs').orderBy('timestamp', descending: true).limit(3).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text('No recent cuts', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
              );
            }
            final docs = snapshot.data!.docs;
            return Column(
              children: docs.map((doc) {
                final cut = doc.data() as Map<String, dynamic>;
                final actualLength = (cut['actualLength'] as num?)?.toDouble() ?? 0;
                final targetLength = (cut['targetLength'] as num?)?.toDouble() ?? 0;
                final accuracy = (cut['accuracy'] as num?)?.toDouble() ?? 0;
                final formattedTimeRaw = cut['formattedTime'] as String? ?? '';

                // Parse and reformat to DD-MM-YY HH:MM
                String timeStr = 'Unknown time';
                if (formattedTimeRaw.isNotEmpty) {
                  try {
                    final parts = formattedTimeRaw.split(' ');
                    if (parts.length >= 2) {
                      final datePart = parts[0];
                      final timePart = parts[1];

                      final dateComponents = datePart.split('-');
                      final timeComponents = timePart.split(':');

                      if (dateComponents.length == 3 && timeComponents.length >= 2) {
                        final year = dateComponents[0].substring(2);
                        final month = dateComponents[1];
                        final day = dateComponents[2];
                        final hour = timeComponents[0];
                        final minute = timeComponents[1];
                        timeStr = '$day-$month-$year $hour:$minute';
                      }
                    }
                  } catch (e) {
                    timeStr = formattedTimeRaw;
                  }
                }

                Color accuracyColor = accuracy >= 95
                    ? Colors.green
                    : accuracy >= 90
                    ? Colors.orange
                    : Colors.red;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: accuracyColor, shape: BoxShape.circle)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Length: ${targetLength.toStringAsFixed(2)}m',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.calendar_today, size: 10, color: Colors.grey[500]),
                                const SizedBox(width: 4),
                                Text(
                                  timeStr.split(' ')[0], // Show only date: "02-10-25"
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(Icons.access_time, size: 10, color: Colors.grey[500]),
                                const SizedBox(width: 4),
                                Text(
                                  timeStr.split(' ').length > 1 ? timeStr.split(' ')[1] : '', // Show time: "15:01"
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: accuracyColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: Text('${accuracy.toStringAsFixed(1)}%', style: TextStyle(color: accuracyColor, fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 8),

      ]),
    );
  }
}
