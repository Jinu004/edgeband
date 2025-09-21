import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cutting_log.dart';

class CuttingLogService {
  final _logsRef = FirebaseFirestore.instance.collection('cuttingLogs');

  /// Add new cutting log
  Future<void> addLog({
    required double actualLength,
    required double targetLength,
    required double difference,
    required double waste,
    required double accuracy,
    required String deviceId,
    required int motorSpeed,
    required double rollerDiameter,
  }) async {
    await _logsRef.add({
      'actualLength': actualLength,
      'targetLength': targetLength,
      'difference': difference,
      'waste': waste,
      'accuracy': accuracy,
      'deviceId': deviceId,
      'motorSpeed': motorSpeed,
      'rollerDiameter': rollerDiameter,
      'timestamp': DateTime.now(),
    });
  }

  /// Stream all cutting logs in descending order
  Stream<List<CuttingLog>> getLogs() {
    return _logsRef
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
          .map((d) => CuttingLog.fromMap(d.id, d.data() as Map<String, dynamic>))
          .toList(),
    );
  }
}
