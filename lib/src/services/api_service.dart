import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/machine_data.dart';

class ApiService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String espBaseUrl; // optional: if you want to send direct commands to ESP on LAN

  ApiService({this.espBaseUrl = ''});

  // Save machine update that ESP32 will POST to cloud
  Future<void> saveMachineData(String machineId, MachineData data) async {
    final ref = _firestore.collection('machines').doc(machineId).collection('history').doc();
    await ref.set(data.toMap());
    // Also update a "current" document for quick dashboard
    await _firestore.collection('machines').doc(machineId).set({
      'current': data.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Get latest current snapshot
  Stream<MachineData?> currentMachineStream(String machineId) {
    final snapStream = _firestore.collection('machines').doc(machineId).snapshots();
    return snapStream.map((snap) {
      if (!snap.exists) return null;
      final map = (snap.data()?['current'] ?? {}) as Map<String, dynamic>;
      if (map.isEmpty) return null;
      return MachineData.fromMap(map);
    });
  }

  // Write control config (target/offset/start/stop) for ESP to fetch
  Future<void> writeConfig(String machineId, {double? target, double? offset, bool? start}) async {
    final doc = _firestore.collection('configs').doc(machineId);
    final data = <String, dynamic>{};
    if (target != null) data['target'] = target;
    if (offset != null) data['offset'] = offset;
    if (start != null) data['start'] = start;
    data['updatedAt'] = FieldValue.serverTimestamp();
    await doc.set(data, SetOptions(merge: true));
  }

  // Optional: send direct HTTPS command to ESP on LAN (if on same network)
  Future<http.Response> sendEspCommand(String path, Map<String, dynamic> body) {
    if (espBaseUrl.isEmpty) throw Exception('espBaseUrl not configured');
    final uri = Uri.parse('$espBaseUrl$path');
    return http.post(uri, body: jsonEncode(body), headers: {'Content-Type': 'application/json'});
  }
}
