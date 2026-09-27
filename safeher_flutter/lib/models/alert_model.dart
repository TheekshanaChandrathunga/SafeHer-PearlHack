import 'package:cloud_firestore/cloud_firestore.dart';

enum AlertSource { manual, aiHeartRate, aiMotion, aiFall, voice }

enum AlertStatus { pending, cancelled, sent, resolved }

class SafetyAlert {
  final String id;
  final AlertSource source;
  final AlertStatus status;
  final double? lat;
  final double? lng;
  final DateTime createdAt;
  final List<String> notifiedContactIds;

  SafetyAlert({
    required this.id,
    required this.source,
    required this.status,
    this.lat,
    this.lng,
    required this.createdAt,
    this.notifiedContactIds = const [],
  });

  Map<String, dynamic> toMap() => {
        'source': source.name,
        'status': status.name,
        'lat': lat,
        'lng': lng,
        'createdAt': FieldValue.serverTimestamp(),
        'notifiedContactIds': notifiedContactIds,
      };

  factory SafetyAlert.fromMap(String id, Map<String, dynamic> map) {
    return SafetyAlert(
      id: id,
      source: AlertSource.values.firstWhere(
        (e) => e.name == map['source'],
        orElse: () => AlertSource.manual,
      ),
      status: AlertStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => AlertStatus.pending,
      ),
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notifiedContactIds: List<String>.from(map['notifiedContactIds'] ?? []),
    );
  }
}
