class MachineData {
  final double currentLength; // mm
  final double totalToday; // mm
  final double lifetime; // mm
  final bool isRunning;
  final DateTime timestamp;

  MachineData({
    required this.currentLength,
    required this.totalToday,
    required this.lifetime,
    required this.isRunning,
    required this.timestamp,
  });

  factory MachineData.fromMap(Map<String, dynamic> m) {
    return MachineData(
      currentLength: (m['currentLength'] ?? 0).toDouble(),
      totalToday: (m['totalToday'] ?? 0).toDouble(),
      lifetime: (m['lifetime'] ?? 0).toDouble(),
      isRunning: (m['isRunning'] ?? false),
      timestamp: DateTime.parse(m['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() => {
        'currentLength': currentLength,
        'totalToday': totalToday,
        'lifetime': lifetime,
        'isRunning': isRunning,
        'timestamp': timestamp.toIso8601String(),
      };
}
