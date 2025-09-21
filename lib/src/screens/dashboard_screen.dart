import 'dart:io';
import 'package:flutter/material.dart';
import 'package:jv/src/screens/cutting_log_screen.dart';
import 'package:jv/src/screens/settings%20screen.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
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
  final targetCtl = TextEditingController();
  final offsetCtl = TextEditingController();
  bool sending = false;
  bool exporting = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final machineProv = Provider.of<MachineProvider>(context, listen: false);
    machineProv.watch(machineId).listen((m) {
      if (m != null) machineProv.setCurrent(m);
    });
  }

  @override
  void dispose() {
    targetCtl.dispose();
    offsetCtl.dispose();
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

  // Get the latest cutting log for actual length
  Stream<QuerySnapshot<Map<String, dynamic>>> cuttingLogsStream() {
    return FirebaseFirestore.instance
        .collection('cuttingLogs')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots();
  }

  // Get daily total from cutting logs
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

        // Daily total
        if (timestamp.isAfter(today)) {
          dailyTotal += actualLength;
        }

        // Weekly total (last 7 days)
        if (timestamp.isAfter(now.subtract(const Duration(days: 7)))) {
          weeklyTotal += actualLength;
        }
      }

      return {
        'daily': dailyTotal,
        'weekly': weeklyTotal,
      };
    } catch (e) {
      return {'daily': 0.0, 'weekly': 0.0};
    }
  }

  Future<void> exportCsv() async {
    setState(() => exporting = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('machines')
          .doc(machineId)
          .collection('history')
          .orderBy('timestamp')
          .get();

      final rows = <List<dynamic>>[];
      rows.add(['timestamp', 'currentLength_mm', 'totalToday_mm', 'lifetime_mm', 'isRunning']);

      for (var d in snap.docs) {
        final m = d.data() as Map<String, dynamic>;
        rows.add([
          m['timestamp'] ?? '',
          m['currentLength'] ?? 0,
          m['totalToday'] ?? 0,
          m['lifetime'] ?? 0,
          m['isRunning'] ?? false
        ]);
      }

      final csv = const ListToCsvConverter().convert(rows);
      final tmp = await getTemporaryDirectory();
      final file = File('${tmp.path}/machine_${machineId}_history.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles([XFile(file.path)], text: 'Machine $machineId history CSV');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('CSV exported successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Text('Export failed: $e'),
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
    final auth = Provider.of<AuthProvider>(context);
    final machineProv = Provider.of<MachineProvider>(context);
    final MachineData? data = machineProv.current;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(actions: [
        IconButton(onPressed: (){
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsScreen()),
          );

        }, icon: Icon(Icons.settings))
      ],
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text(
          'Machine Dashboard',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.blue[600],
              indicatorWeight: 3,
              labelColor: Colors.blue[600],
              unselectedLabelColor: Colors.grey[600],
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              tabs: const [
                Tab(
                  icon: Icon(Icons.dashboard_outlined, size: 22),
                  text: 'Status',
                  height: 60,
                ),
                Tab(
                  icon: Icon(Icons.analytics_outlined, size: 22),
                  text: 'Sales History',
                  height: 60,
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDashboardTab(data, machineProv),
          const CuttingLogsScreen(),
        ],
      ),
    );
  }

  Widget _buildDashboardTab(MachineData? data, MachineProvider machineProv) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Header with Live Indicator
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
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

          // Status Cards Grid with Actual Length from Cutting Logs
          StreamBuilder<QuerySnapshot>(
            stream: cuttingLogsStream(),
            builder: (context, cuttingSnapshot) {
              double? latestActualLength;

              if (cuttingSnapshot.hasData && cuttingSnapshot.data!.docs.isNotEmpty) {
                final latestCut = cuttingSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                latestActualLength = (latestCut['actualLength'] as num?)?.toDouble();
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
                      _buildStatusCard(
                        'Latest Cut Length',
                        latestActualLength != null
                            ? '${latestActualLength.toStringAsFixed(2)}'
                            : '—',
                        'm',
                        Icons.content_cut,
                        Colors.blue,
                      ),
                      _buildStatusCard(
                        'Today Total',
                        '${totals['daily']!.toStringAsFixed(2)}',
                        'm',
                        Icons.today,
                        Colors.green,
                      ),
                      _buildStatusCard(
                        'Weekly Total',
                        '${totals['weekly']!.toStringAsFixed(2)}',
                        'm',
                        Icons.date_range,
                        Colors.purple,
                      ),
                      _buildStatusCard(
                        'Machine Status',
                        data?.isRunning == true ? 'ACTIVE' : 'IDLE',
                        '',
                        data?.isRunning == true ? Icons.play_circle : Icons.pause_circle,
                        data?.isRunning == true ? Colors.green : Colors.orange,
                      ),
                    ],
                  );
                },
              );
            },
          ),

          const SizedBox(height: 32),

          // Quick Actions Section
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'Device Setup',
                  Icons.settings,
                  Colors.blue,
                      () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const BluetoothScanScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  'Export Data',
                  Icons.download,
                  Colors.green,
                  exporting ? null : exportCsv,
                  isLoading: exporting,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Recent Cutting Activity Card (from cutting logs instead of machine history)
          _buildRecentCuttingActivityCard(),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String title, String value, String unit, IconData icon, Color color) {
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 2),
                  Text(
                    unit,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String text, IconData icon, Color color, VoidCallback? onPressed, {bool isLoading = false}) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: isLoading
            ? SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        )
            : Icon(icon, size: 20),
        label: Text(
          isLoading ? 'Loading...' : text,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentCuttingActivityCard() {
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.content_cut, color: Colors.grey[600], size: 20),
                const SizedBox(width: 8),
                Text(
                  'Recent Cuts',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('cuttingLogs')
                  .orderBy('timestamp', descending: true)
                  .limit(3)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            'No recent cuts',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final recentDocs = snapshot.data!.docs;

                return Column(
                  children: recentDocs.map((doc) {
                    final cutData = doc.data() as Map<String, dynamic>;
                    final actualLength = (cutData['actualLength'] as num?)?.toDouble() ?? 0;
                    final targetLength = (cutData['targetLength'] as num?)?.toDouble() ?? 0;
                    final accuracy = (cutData['accuracy'] as num?)?.toDouble() ?? 0;
                    final timestamp = cutData['timestamp'] as Timestamp?;

                    // Format timestamp
                    String timeStr = 'Unknown time';
                    if (timestamp != null) {
                      final dateTime = timestamp.toDate();
                      final now = DateTime.now();
                      final difference = now.difference(dateTime);

                      if (difference.inMinutes < 1) {
                        timeStr = 'Just now';
                      } else if (difference.inHours < 1) {
                        timeStr = '${difference.inMinutes}m ago';
                      } else if (difference.inDays < 1) {
                        timeStr = '${difference.inHours}h ago';
                      } else {
                        timeStr = '${difference.inDays}d ago';
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: accuracy >= 95 ? Colors.green :
                              accuracy >= 90 ? Colors.orange : Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Length:   ${targetLength.toStringAsFixed(2)}m',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: accuracy >= 95 ? Colors.green.withOpacity(0.1) :
                              accuracy >= 90 ? Colors.orange.withOpacity(0.1) :
                              Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${accuracy.toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: accuracy >= 95 ? Colors.green :
                                accuracy >= 90 ? Colors.orange : Colors.red,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _tabController.animateTo(1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'View All Cuts',
                    style: TextStyle(
                      color: Colors.blue[600],
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: Colors.blue[600],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    return Container(
      color: Colors.grey[50],
      child: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Machine History',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Complete activity log',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildActionButton(
                  'Export',
                  Icons.download,
                  Colors.green,
                  exporting ? null : exportCsv,
                  isLoading: exporting,
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: historyStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading history',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No history data available',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final m = docs[index].data() as Map<String, dynamic>;
                    final timestamp = m['timestamp'] ?? '';
                    final currentLength = m['currentLength']?.toString() ?? '0';
                    final isRunning = m['isRunning'] ?? false;
                    final totalToday = ((m['totalToday'] ?? 0) / 1000).toStringAsFixed(2);
                    final lifetime = ((m['lifetime'] ?? 0) / 1000).toStringAsFixed(1);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 0,
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: isRunning ? Colors.green : Colors.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(
                          'Current: ${currentLength}mm',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                timestamp,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Today: ${totalToday}m • Lifetime: ${lifetime}m',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isRunning ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isRunning ? 'RUNNING' : 'IDLE',
                            style: TextStyle(
                              color: isRunning ? Colors.green : Colors.orange,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}