class VitalsReading {
  final DateTime timestamp;
  final double heartRate; // bpm
  final double accelMagnitude; // m/s^2, resultant of x,y,z minus gravity
  final double batteryPercent;

  VitalsReading({
    required this.timestamp,
    required this.heartRate,
    required this.accelMagnitude,
    required this.batteryPercent,
  });
}

enum DistressLevel { normal, elevated, critical }

class DistressResult {
  final DistressLevel level;
  final double score; // 0-100
  final String reason;
  DistressResult(this.level, this.score, this.reason);
}
