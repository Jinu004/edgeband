import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  String _selectedPeriod = "Daily";

  Stream<QuerySnapshot> _salesStream() {
    return FirebaseFirestore.instance
        .collection('sales')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: StreamBuilder<QuerySnapshot>(
        stream: _salesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading sales data...'),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading sales data',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: TextStyle(fontSize: 12, color: Colors.red[400]),
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
                  Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No sales data available',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sales records will appear here once generated',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          // Calculate sales totals
          final salesData = _calculateSales(docs);

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Section
                  Text(
                    'Sales Overview',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Track your production and sales performance',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Period Selector
                  _buildPeriodSelector(),

                  const SizedBox(height: 24),

                  // Sales Summary Cards
                  _buildSalesSummaryCards(salesData),

                  const SizedBox(height: 32),

                  // Sales History Section
                  _buildSalesHistory(docs),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPeriodSelector() {
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
          Icon(Icons.calendar_today, color: Colors.blue[600], size: 24),
          const SizedBox(width: 12),
          Text(
            'Time Period:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedPeriod,
                style: TextStyle(
                  color: Colors.grey[800],
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                items: const [
                  DropdownMenuItem(
                    value: "Daily",
                    child: Text("Today"),
                  ),
                  DropdownMenuItem(
                    value: "Weekly",
                    child: Text("This Week"),
                  ),
                  DropdownMenuItem(
                    value: "Monthly",
                    child: Text("This Month"),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedPeriod = val);
                  }
                },
                icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesSummaryCards(Map<String, double> salesData) {
    final selectedValue = salesData[_selectedPeriod] ?? 0;

    return Column(
      children: [
        // Main Selected Period Card
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[600]!, Colors.blue[500]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                spreadRadius: 0,
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.trending_up, color: Colors.white, size: 24),
                    ),
                    const Spacer(),
                    Text(
                      _selectedPeriod,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '${selectedValue.toStringAsFixed(2)} m',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getPeriodDescription(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Summary Stats Grid
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Daily',
                '${salesData['Daily']?.toStringAsFixed(1) ?? '0'} m',
                Icons.today,
                Colors.green,
                isSelected: _selectedPeriod == 'Daily',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Weekly',
                '${salesData['Weekly']?.toStringAsFixed(1) ?? '0'} m',
                Icons.date_range,
                Colors.orange,
                isSelected: _selectedPeriod == 'Weekly',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Monthly',
                '${salesData['Monthly']?.toStringAsFixed(1) ?? '0'} m',
                Icons.calendar_month,
                Colors.purple,
                isSelected: _selectedPeriod == 'Monthly',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {bool isSelected = false}) {
    return GestureDetector(
      onTap: () => setState(() => _selectedPeriod = title),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isSelected ? Border.all(color: color, width: 2) : null,
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
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSalesHistory(List<QueryDocumentSnapshot> docs) {
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
                Icon(Icons.receipt_long, color: Colors.grey[600], size: 20),
                const SizedBox(width: 8),
                Text(
                  'Sales History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${docs.length} records',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: docs.length > 10 ? 10 : docs.length, // Show max 10 items
            itemBuilder: (_, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              if (data['length'] == null || data['timestamp'] == null) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange[400], size: 20),
                      const SizedBox(width: 12),
                      const Text(
                        "Invalid sale entry",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              final ts = (data['timestamp'] as Timestamp).toDate();
              final length = (data['length'] as num).toDouble();

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  border: i < (docs.length > 10 ? 9 : docs.length - 1)
                      ? Border(bottom: BorderSide(color: Colors.grey[100]!))
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.sell,
                        color: Colors.green,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${length.toStringAsFixed(2)} m',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('MMM dd, yyyy • HH:mm').format(ts),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'SOLD',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (docs.length > 10)
            Container(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'Showing 10 of ${docs.length} records',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Map<String, double> _calculateSales(List<QueryDocumentSnapshot> docs) {
    double daily = 0;
    double weekly = 0;
    double monthly = 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['length'] == null || data['timestamp'] == null) continue;

      final length = (data['length'] as num).toDouble();
      final ts = (data['timestamp'] as Timestamp).toDate();

      // Daily
      if (ts.isAfter(today)) {
        daily += length;
      }

      // Weekly (last 7 days)
      if (ts.isAfter(now.subtract(const Duration(days: 7)))) {
        weekly += length;
      }

      // Monthly (same month)
      if (ts.year == now.year && ts.month == now.month) {
        monthly += length;
      }
    }

    return {
      'Daily': daily,
      'Weekly': weekly,
      'Monthly': monthly,
    };
  }

  String _getPeriodDescription() {
    switch (_selectedPeriod) {
      case 'Daily':
        return 'Sales generated today';
      case 'Weekly':
        return 'Sales in the last 7 days';
      case 'Monthly':
        return 'Sales this month';
      default:
        return 'Total sales';
    }
  }
}