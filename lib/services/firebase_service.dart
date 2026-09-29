import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/contact_model.dart';
import '../models/alert_model.dart';

/// Wraps all Firebase access for the app: auth, Firestore data,
/// and FCM token registration. Firestore layout:
///
/// users/{uid}
///   name, phone, settings: {soundAlert, autoCall, shareLocation,
///                            notifyAuthorities, autoNightMode}
///   fcmToken
///   users/{uid}/contacts/{contactId}
///   users/{uid}/alerts/{alertId}
///   users/{uid}/vitals/latest   (single doc, overwritten each reading)
class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _messaging = FirebaseMessaging.instance;

  User? get currentUser => _auth.currentUser;
  String get uid => _auth.currentUser?.uid ?? 'anonymous';

  /// Anonymous sign-in is used so the demo works without a full
  /// phone/email verification flow; swap for FirebaseAuth phone auth
  /// in production (see README).
  Future<User?> ensureSignedIn() async {
    if (_auth.currentUser != null) return _auth.currentUser;
    final cred = await _auth.signInAnonymously();
    await _db.collection('users').doc(cred.user!.uid).set({
      'createdAt': FieldValue.serverTimestamp(),
      'settings': {
        'soundAlert': true,
        'autoCall': true,
        'shareLocation': true,
        'notifyAuthorities': true,
        'autoNightMode': true,
      },
    }, SetOptions(merge: true));
    return cred.user;
  }

  Future<void> registerPushToken() async {
    await _messaging.requestPermission();
    final token = await _messaging.getToken();
    if (token == null) return;
    await _db.collection('users').doc(uid).set(
      {'fcmToken': token},
      SetOptions(merge: true),
    );
  }

  // ---------------- Contacts ----------------

  CollectionReference<Map<String, dynamic>> get _contacts =>
      _db.collection('users').doc(uid).collection('contacts');

  Stream<List<EmergencyContact>> watchContacts() {
    return _contacts.orderBy('name').snapshots().map((snap) => snap.docs
        .map((d) => EmergencyContact.fromMap(d.id, d.data()))
        .toList());
  }

  Future<void> addContact(EmergencyContact c) =>
      _contacts.add(c.toMap());

  Future<void> updateContact(EmergencyContact c) =>
      _contacts.doc(c.id).update(c.toMap());

  Future<void> deleteContact(String id) => _contacts.doc(id).delete();

  // ---------------- Vitals ----------------

  Future<void> pushVitals({
    required double heartRate,
    required double accelMagnitude,
    required double battery,
  }) {
    return _db.collection('users').doc(uid).collection('vitals').doc('latest').set({
      'heartRate': heartRate,
      'accelMagnitude': accelMagnitude,
      'battery': battery,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------- Alerts ----------------

  Future<String> createAlert(SafetyAlert alert) async {
    final ref = await _db
        .collection('users')
        .doc(uid)
        .collection('alerts')
        .add(alert.toMap());
    // A Cloud Function (functions/index.js) triggers on this document's
    // creation and fans out FCM push notifications + can call an SMS
    // provider (e.g. Twilio) to each emergency contact.
    return ref.id;
  }

  Future<void> updateAlertStatus(String alertId, AlertStatus status) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('alerts')
        .doc(alertId)
        .update({'status': status.name});
  }

  Future<void> markContactsNotified(String alertId, List<String> ids) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('alerts')
        .doc(alertId)
        .update({'notifiedContactIds': ids});
  }

  Stream<List<SafetyAlert>> watchAlerts() {
    return _db
        .collection('users')
        .doc(uid)
        .collection('alerts')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => SafetyAlert.fromMap(d.id, d.data())).toList());
  }

  // ---------------- Settings ----------------

  Future<void> updateSettings(Map<String, dynamic> settings) {
    return _db.collection('users').doc(uid).set(
      {'settings': settings},
      SetOptions(merge: true),
    );
  }

  Stream<Map<String, dynamic>> watchSettings() {
    return _db.collection('users').doc(uid).snapshots().map(
        (d) => Map<String, dynamic>.from(d.data()?['settings'] ?? {}));
  }
}
