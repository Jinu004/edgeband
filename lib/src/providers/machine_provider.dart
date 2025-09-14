import 'package:flutter/material.dart';
import '../models/machine_data.dart';
import '../services/api_service.dart';

class MachineProvider extends ChangeNotifier {
  MachineData? current;
  final ApiService api = ApiService();

  void setCurrent(MachineData m) {
    current = m;
    notifyListeners();
  }

  Stream<MachineData?> watch(String machineId) => api.currentMachineStream(machineId);

  Future<void> writeConfig(String machineId, {double? target, double? offset, bool? start}) {
    return api.writeConfig(machineId, target: target, offset: offset, start: start);
  }
}
