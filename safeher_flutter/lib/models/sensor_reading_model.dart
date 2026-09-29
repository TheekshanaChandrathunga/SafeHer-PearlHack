import 'package:cloud_firestore/cloud_firestore.dart';

/// One reading from the simulated Wokwi ESP32 wearable, read from
/// Firestore at `sensor_readings/{deviceId}`. This is separate from
/// [VitalsReading] (used by [AIDetectionService]'s on-device demo
/// generator) because it comes from an external, clearly-simulated
/// "device" rather than the phone itself.
class EspSensorReading {
  final String deviceId;
  final double heartRate;
  final String movement; // 'normal' | 'unusual' | 'inactive'
  final bool riskDetected;
  final String riskReason;
  final int scenario;
  final bool simulated;
  final DateTime? updatedAt; // Firestore server timestamp of the write

  EspSensorReading({
    required this.deviceId,
    required this.heartRate,
    required this.movement,
    required this.riskDetected,
    required this.riskReason,
    required this.scenario,
    required this.simulated,
    required this.updatedAt,
  });

  /// True once the reading is older than [maxAge] — used to show a
  /// "Sensor offline" state if the Wokwi simulation isn't running.
  bool isStale(Duration maxAge) {
    if (updatedAt == null) return true;
    return DateTime.now().difference(updatedAt!) > maxAge;
  }

  factory EspSensorReading.fromMap(
    Map<String, dynamic> map, {
    DateTime? receivedAt,
  }) {
    final ts = map['timestamp'];
    final parsedTimestamp = ts is Timestamp
        ? ts.toDate()
        : ts is DateTime
            ? ts
            : ts is String
                ? DateTime.tryParse(ts)
                : null;
    final updatedAt = parsedTimestamp != null && parsedTimestamp.year >= 2020
        ? parsedTimestamp
        : receivedAt;
    return EspSensorReading(
      deviceId: (map['device_id'] ?? 'unknown').toString(),
      heartRate: (map['heart_rate'] as num?)?.toDouble() ?? 0,
      movement: (map['movement'] ?? 'normal').toString(),
      riskDetected: map['risk_detected'] == true,
      riskReason: (map['risk_reason'] ?? 'none').toString(),
      scenario: (map['scenario'] as num?)?.toInt() ?? 0,
      simulated: map['simulated'] == true,
      updatedAt: updatedAt,
    );
  }
}
