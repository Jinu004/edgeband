import 'package:cloud_firestore/cloud_firestore.dart';

class CuttingLog {
  final String id;
  final double actualLength;
  final double targetLength;
  final double difference;
  final double waste;
  final double accuracy;
  final String deviceId;
  final int motorSpeed;
  final double rollerDiameter;
  final DateTime timestamp;

  CuttingLog({
    required this.id,
    required this.actualLength,
    required this.targetLength,
    required this.difference,
    required this.waste,
    required this.accuracy,
    required this.deviceId,
    required this.motorSpeed,
    required this.rollerDiameter,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'actualLength': actualLength,
      'targetLength': targetLength,
      'difference': difference,
      'waste': waste,
      'accuracy': accuracy,
      'deviceId': deviceId,
      'motorSpeed': motorSpeed,
      'rollerDiameter': rollerDiameter,
      'timestamp': timestamp,
    };
  }

  factory CuttingLog.fromMap(String id, Map<String, dynamic> data) {
    return CuttingLog(
      id: id,
      actualLength: (data['actualLength'] as num).toDouble(),
      targetLength: (data['targetLength'] as num).toDouble(),
      difference: (data['difference'] as num).toDouble(),
      waste: (data['waste'] as num).toDouble(),
      accuracy: (data['accuracy'] as num).toDouble(),
      deviceId: data['deviceId'] ?? '',
      motorSpeed: (data['motorSpeed'] as num).toInt(),
      rollerDiameter: (data['rollerDiameter'] as num).toDouble(),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }
}
