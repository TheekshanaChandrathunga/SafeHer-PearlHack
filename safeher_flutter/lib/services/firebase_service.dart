import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
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

  final FirebaseAuth? _auth = kIsWeb ? null : FirebaseAuth.instance;
  final FirebaseFirestore? _db = kIsWeb ? null : FirebaseFirestore.instance;
  final FirebaseMessaging? _messaging =
      kIsWeb ? null : FirebaseMessaging.instance;
  final List<EmergencyContact> _demoContacts = [];
  final Map<String, dynamic> _demoSettings = {
    'soundAlert': true,
    'autoCall': true,
    'shareLocation': true,
    'notifyAuthorities': true,
    'autoNightMode': true,
  };

  User? get currentUser => _auth?.currentUser;
  String get uid => _auth?.currentUser?.uid ?? 'anonymous';

  /// Anonymous sign-in is used so the demo works without a full
  /// phone/email verification flow; swap for FirebaseAuth phone auth
  /// in production (see README).
  Future<User?> ensureSignedIn() async {
    if (kIsWeb) return null;
    if (_auth!.currentUser != null) return _auth.currentUser;
    final cred = await _auth.signInAnonymously();
    await _db!.collection('users').doc(cred.user!.uid).set({
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
    if (kIsWeb) return;
    await _messaging!.requestPermission();
    final token = await _messaging.getToken();
    if (token == null) return;
    await _db!.collection('users').doc(uid).set(
      {'fcmToken': token},
      SetOptions(merge: true),
    );
  }

  // ---------------- Contacts ----------------

  CollectionReference<Map<String, dynamic>> get _contacts =>
      _db!.collection('users').doc(uid).collection('contacts');

  Stream<List<EmergencyContact>> watchContacts() {
    if (kIsWeb) return Stream.value(List.unmodifiable(_demoContacts));
    return _contacts.orderBy('name').snapshots().map((snap) => snap.docs
        .map((d) => EmergencyContact.fromMap(d.id, d.data()))
        .toList());
  }

  Future<void> addContact(EmergencyContact c) async {
    if (kIsWeb) {
      _demoContacts.add(EmergencyContact(
        id: 'demo-${_demoContacts.length + 1}',
        name: c.name,
        phone: c.phone,
        relationship: c.relationship,
        fcmToken: c.fcmToken,
      ));
      return;
    }
    await _contacts.add(c.toMap());
  }

  Future<void> updateContact(EmergencyContact c) async {
    if (kIsWeb) {
      final index = _demoContacts.indexWhere((contact) => contact.id == c.id);
      if (index >= 0) _demoContacts[index] = c;
      return;
    }
    await _contacts.doc(c.id).update(c.toMap());
  }

  Future<void> deleteContact(String id) async {
    if (kIsWeb) {
      _demoContacts.removeWhere((contact) => contact.id == id);
      return;
    }
    await _contacts.doc(id).delete();
  }

  // ---------------- Vitals ----------------

  Future<void> pushVitals({
    required double heartRate,
    required double accelMagnitude,
    required double battery,
  }) {
    if (kIsWeb) return Future.value();
    return _db!
        .collection('users')
        .doc(uid)
        .collection('vitals')
        .doc('latest')
        .set({
      'heartRate': heartRate,
      'accelMagnitude': accelMagnitude,
      'battery': battery,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------- Alerts ----------------

  Future<String> createAlert(SafetyAlert alert) async {
    if (kIsWeb) return 'demo-alert-${DateTime.now().millisecondsSinceEpoch}';
    final ref = await _db!
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
    if (kIsWeb) return Future.value();
    return _db!
        .collection('users')
        .doc(uid)
        .collection('alerts')
        .doc(alertId)
        .update({'status': status.name});
  }

  Future<void> markContactsNotified(String alertId, List<String> ids) {
    if (kIsWeb) return Future.value();
    return _db!
        .collection('users')
        .doc(uid)
        .collection('alerts')
        .doc(alertId)
        .update({'notifiedContactIds': ids});
  }

  Stream<List<SafetyAlert>> watchAlerts() {
    if (kIsWeb) return Stream.value(const []);
    return _db!
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
    if (kIsWeb) {
      _demoSettings
        ..clear()
        ..addAll(settings);
      return Future.value();
    }
    return _db!.collection('users').doc(uid).set(
      {'settings': settings},
      SetOptions(merge: true),
    );
  }

  Stream<Map<String, dynamic>> watchSettings() {
    if (kIsWeb) return Stream.value(Map.unmodifiable(_demoSettings));
    return _db!
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((d) => Map<String, dynamic>.from(d.data()?['settings'] ?? {}));
  }
}
