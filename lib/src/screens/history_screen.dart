import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final machineId = 'machine-1';
  bool exporting = false;

  Stream<QuerySnapshot<Map<String, dynamic>>> historyStream() {
    return FirebaseFirestore.instance
        .collection('history')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> exportCsv() async {
    setState(() => exporting = true);
    final snap = await FirebaseFirestore.instance.collection('machines').doc(machineId).collection('history').orderBy('timestamp').get();
    final rows = <List<dynamic>>[];
    rows.add(['timestamp','currentLength_mm','totalToday_mm','lifetime_mm','isRunning']);
    for (var d in snap.docs) {
      final m = d.data() as Map<String, dynamic>;
      rows.add([m['timestamp'] ?? '', m['currentLength'] ?? 0, m['totalToday'] ?? 0, m['lifetime'] ?? 0, m['isRunning'] ?? false]);
    }
    final csv = const ListToCsvConverter().convert(rows);
    final tmp = await getTemporaryDirectory();
    final file = File('${tmp.path}/machine_${machineId}_history.csv');
    await file.writeAsString(csv);
    await Share.shareXFiles([XFile(file.path)], text: 'Machine $machineId history CSV');
    setState(() => exporting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('History')),
        body: Column(children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: historyStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (c, i) {
                    final m = docs[i].data() as Map<String, dynamic>;
                    return ListTile(
                      title: Text('Current: ${m['currentLength']} mm'),
                      subtitle: Text('${m['timestamp']} • Running: ${m['isRunning']}'),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton(
              onPressed: exporting ? null : exportCsv,
              child: exporting ? const CircularProgressIndicator() : const Text('Export CSV'),
            ),
          ),
        ]));
  }
}
