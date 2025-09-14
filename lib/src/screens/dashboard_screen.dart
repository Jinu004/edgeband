import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/machine_provider.dart';
import '../models/machine_data.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final machineId = 'machine-1';
  final targetCtl = TextEditingController();
  final offsetCtl = TextEditingController();
  bool sending = false;

  @override
  void initState() {
    super.initState();
    final machineProv = Provider.of<MachineProvider>(context, listen: false);
    machineProv.watch(machineId).listen((m) {
      if (m != null) machineProv.setCurrent(m);
    });
  }

  @override
  void dispose() {
    targetCtl.dispose();
    offsetCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final machineProv = Provider.of<MachineProvider>(context);
    final MachineData? data = machineProv.current;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.history), onPressed: () => Navigator.pushNamed(context, '/history')),
          IconButton(icon: const Icon(Icons.logout), onPressed: () async {
            await auth.signOut();
            Navigator.pushReplacementNamed(context, '/login');
          }),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Text('Machine Status', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statTile('Current (mm)', data?.currentLength.toStringAsFixed(1) ?? '—'),
                    _statTile('Today (m)', ((data?.totalToday ?? 0) / 1000).toStringAsFixed(2)),
                    _statTile('Lifetime (m)', ((data?.lifetime ?? 0) / 1000).toStringAsFixed(1)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Status: '),
                    Text(data?.isRunning == true ? 'RUNNING' : 'IDLE', style: TextStyle(color: data?.isRunning == true ? Colors.green : Colors.orange)),
                  ],
                ),
              ]),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                const Text('Control Panel', style: TextStyle(fontSize: 16)),
                TextField(controller: targetCtl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Target length (mm)')),
                TextField(controller: offsetCtl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Offset ± (mm)')),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: sending ? null : () async {
                        final t = double.tryParse(targetCtl.text.trim());
                        final o = double.tryParse(offsetCtl.text.trim());
                        if (t == null) return;
                        setState(() => sending = true);
                        await machineProv.writeConfig(machineId, target: t, offset: o ?? 0, start: true);
                        setState(() => sending = false);
                      },
                      child: sending ? const CircularProgressIndicator() : const Text('Start Feed'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () async {
                      await machineProv.writeConfig(machineId, start: false);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stop sent')));
                    },
                    child: const Text('STOP'),
                  ),
                ])
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _statTile(String title, String value) {
    return Column(children: [Text(title), const SizedBox(height: 6), Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]);
  }
}
