import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sale.dart';

class SalesService {
  final _salesRef = FirebaseFirestore.instance.collection('sales');

  Future<void> addSale(double length) async {
    await _salesRef.add({
      'length': length,
      'timestamp': DateTime.now(),
    });
  }

  /// Stream of sales ordered by time
  Stream<List<Sale>> getSales() {
    return _salesRef
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
          .map((d) => Sale.fromMap(d.id, d.data() as Map<String, dynamic>))
          .toList(),
    );
  }
}
