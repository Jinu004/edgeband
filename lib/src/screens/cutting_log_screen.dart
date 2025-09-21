import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CuttingLogsScreen extends StatefulWidget {
  const CuttingLogsScreen({super.key});

  @override
  State<CuttingLogsScreen> createState() => _CuttingLogsScreenState();
}

class _CuttingLogsScreenState extends State<CuttingLogsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Get cuttingLogs collection stream
  Stream<QuerySnapshot> _cuttingLogsStream() {
    return FirebaseFirestore.instance
        .collection('cuttingLogs')
        .orderBy('formattedTime', descending: true)
        .snapshots();
  }

  /// Parse formattedTime string to DateTime
  DateTime _parseFormattedTime(String formattedTime) {
    try {
      // Remove 'IST' suffix and parse the datetime
      final cleanTime = formattedTime.replaceAll(' IST', '');
      return DateTime.parse(cleanTime);
    } catch (e) {
      // Fallback to current time if parsing fails
      return DateTime.now();
    }
  }

  /// Calculate daily / weekly / monthly totals
  Map<String, double> _calculateTotals(List<QueryDocumentSnapshot> docs) {
    double daily = 0;
    double weekly = 0;
    double monthly = 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final actualLength = (data['actualLength'] as num?)?.toDouble() ?? 0;
      final formattedTime = data['formattedTime'] as String? ?? '';
      final ts = _parseFormattedTime(formattedTime);

      // Daily
      if (ts.isAfter(today)) {
        daily += actualLength;
      }

      // Weekly (last 7 days)
      if (ts.isAfter(now.subtract(const Duration(days: 7)))) {
        weekly += actualLength;
      }

      // Monthly (this calendar month)
      if (ts.year == now.year && ts.month == now.month) {
        monthly += actualLength;
      }
    }

    return {
      "daily": daily,
      "weekly": weekly,
      "monthly": monthly,
    };
  }

  /// Build the header cards for totals
  Widget _buildSummaryCards(Map<String, double> totals) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _summaryCard("Daily", totals["daily"] ?? 0, const Color(0xFF3b82f6), Icons.today),
            const SizedBox(width: 12),
            _summaryCard("Weekly", totals["weekly"] ?? 0, const Color(0xFF10b981), Icons.date_range),
            const SizedBox(width: 12),
            _summaryCard("Monthly", totals["monthly"] ?? 0, const Color(0xFFf59e0b), Icons.calendar_month),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(String title, double value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: Colors.grey.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "${value.toStringAsFixed(2)}m",
              style: TextStyle(
                color: Colors.grey[800],
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build cutting logs history list
  Widget _buildCuttingLogsHistory(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) {
      return _buildEmptyState();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: Colors.grey.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3b82f6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.history,
                      color: Color(0xFF3b82f6),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Recent Activity',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${docs.length} entries',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ListView.separated(
              itemCount: docs.length > 50 ? 50 : docs.length, // Limit to 50 items for performance
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: Colors.grey.withOpacity(0.1),
                indent: 76,
              ),
              itemBuilder: (context, i) {
                final data = docs[i].data() as Map<String, dynamic>;
                final formattedTime = data['formattedTime'] as String? ?? '';
                final ts = _parseFormattedTime(formattedTime);
                final actualLength = (data['actualLength'] as num?)?.toDouble() ?? 0;
                final isToday = _isToday(ts);

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3b82f6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.content_cut,
                          color: Color(0xFF3b82f6),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  "${actualLength.toStringAsFixed(2)}m",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (isToday)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10b981).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      "TODAY",
                                      style: TextStyle(
                                        color: Color(0xFF10b981),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTimestamp(ts),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3b82f6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          "CUT",
                          style: TextStyle(
                            color: Color(0xFF3b82f6),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (docs.length > 50)
              Container(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    "Showing latest 50 entries",
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.content_cut,
                size: 48,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "No Cutting Logs Yet",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Start cutting to see your activity logs here",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  String _formatTimestamp(DateTime ts) {
    final now = DateTime.now();
    final difference = now.difference(ts);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(ts);
    } else if (difference.inDays == 1) {
      return 'Yesterday ${DateFormat('HH:mm').format(ts)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(ts);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
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
                    // IconButton(
                    //   onPressed: () => Navigator.pop(context),
                    //   icon: const Icon(
                    //     Icons.arrow_back_ios,
                    //     color: Colors.black,
                    //   ),
                    // ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Cutting Logs',
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
                        Icons.analytics,
                        color: Color(0xFF3b82f6),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Main Content
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _cuttingLogsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF3b82f6),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading data',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  final totals = _calculateTotals(docs);

                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        _buildSummaryCards(totals),
                        const SizedBox(height: 24),
                        _buildCuttingLogsHistory(docs),
                        const SizedBox(height: 20),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}