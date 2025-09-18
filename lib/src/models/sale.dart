import 'package:cloud_firestore/cloud_firestore.dart';

class Sale {
  final String id;
  final double length; // length of edgeband in meters
  final DateTime timestamp;

  Sale({
    required this.id,
    required this.length,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'length': length,
      'timestamp': timestamp,
    };
  }

  factory Sale.fromMap(String id, Map<String, dynamic> data) {
    return Sale(
      id: id,
      length: (data['length'] as num).toDouble(),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }
}
