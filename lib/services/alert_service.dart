import 'package:url_launcher/url_launcher.dart';
import '../models/alert_model.dart';
import '../models/contact_model.dart';
import 'firebase_service.dart';
import 'location_service.dart';

/// Orchestrates what happens once distress is confirmed (manual hold,
/// AI heart-rate spike, motion/fall detection, or voice SOS):
/// grab location -> write alert to Firestore -> Cloud Function fans out
/// notifications -> optionally auto-call the first contact / local
/// emergency number.
class AlertService {
  AlertService(this._fb, this._loc);
  final FirebaseService _fb;
  final LocationService _loc;

  Future<String> triggerAlert({
    required AlertSource source,
    required List<EmergencyContact> contacts,
    required bool autoCall,
    required bool notifyAuthorities,
    String emergencyNumber = '119',
  }) async {
    final pos = await _loc.getCurrentPosition();

    final alert = SafetyAlert(
      id: '',
      source: source,
      status: AlertStatus.pending,
      lat: pos?.latitude,
      lng: pos?.longitude,
      createdAt: DateTime.now(),
    );
    final alertId = await _fb.createAlert(alert);

    // In production the Cloud Function in functions/index.js does the
    // actual push/SMS fan-out when this document is created; we also
    // mark contacts as targeted locally so the UI can show "Notified".
    await _fb.markContactsNotified(alertId, contacts.map((c) => c.id).toList());
    await _fb.updateAlertStatus(alertId, AlertStatus.sent);

    if (autoCall && contacts.isNotEmpty) {
      await _call(contacts.first.phone);
    } else if (notifyAuthorities) {
      await _call(emergencyNumber);
    }

    return alertId;
  }

  Future<void> resolveAlert(String alertId) =>
      _fb.updateAlertStatus(alertId, AlertStatus.resolved);

  Future<void> cancelAlert(String alertId) =>
      _fb.updateAlertStatus(alertId, AlertStatus.cancelled);

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}
