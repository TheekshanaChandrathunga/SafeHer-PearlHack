import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../models/contact_model.dart';
import '../models/alert_model.dart';
import '../models/sensor_reading_model.dart';

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

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
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
  bool _useDemoData = false;
  final StreamController<List<EmergencyContact>> _demoContactsController =
      StreamController<List<EmergencyContact>>.broadcast();
  final StreamController<Map<String, dynamic>> _demoSettingsController =
      StreamController<Map<String, dynamic>>.broadcast();

  void _emitDemoContacts() {
    if (!kIsWeb) return;
    _demoContactsController.add(List.unmodifiable(_demoContacts));
  }

  void _emitDemoSettings() {
    if (!kIsWeb) return;
    _demoSettingsController.add(Map.unmodifiable(_demoSettings));
  }

  bool _isPermissionError(Object error) {
    if (error is FirebaseException) {
      final code = error.code.toLowerCase();
      return code.contains('permission') || code.contains('unavailable');
    }
    final text = error.toString().toLowerCase();
    return text.contains('permission') || text.contains('insufficient permissions');
  }

  User? get currentUser => _auth.currentUser;
  String get uid => _auth.currentUser?.uid ?? 'demo-user-001';

  /// Anonymous sign-in is used so the demo works without a full
  /// phone/email verification flow; swap for FirebaseAuth phone auth
  /// in production (see README).
  Future<User?> ensureSignedIn() async {
    if (_auth.currentUser != null) return _auth.currentUser;

    try {
      final cred = await _auth.signInAnonymously();
      final user = cred.user;
      if (user == null) return null;

      await _db.collection('users').doc(user.uid).set({
        'createdAt': FieldValue.serverTimestamp(),
        'settings': {
          'soundAlert': true,
          'autoCall': true,
          'shareLocation': true,
          'notifyAuthorities': true,
          'autoNightMode': true,
        },
      }, SetOptions(merge: true));
      _useDemoData = false;
      return user;
    } catch (error, stackTrace) {
      _useDemoData = false;
      debugPrint('Firebase anonymous sign-in failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> registerPushToken() async {
    if (kIsWeb || _messaging == null) return;
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
    if (_useDemoData) {
      _emitDemoContacts();
      return _demoContactsController.stream;
    }

    return _contacts.orderBy('name').snapshots().map((snap) => snap.docs
        .map((d) => EmergencyContact.fromMap(d.id, d.data()))
        .toList()).handleError((error) {
      if (_isPermissionError(error)) {
        _useDemoData = true;
        return List.unmodifiable(_demoContacts);
      }
      throw error;
    });
  }

  Future<void> addContact(EmergencyContact c) async {
    if (_useDemoData) {
      final local = EmergencyContact(
        id: c.id.isNotEmpty ? c.id : 'local-${DateTime.now().millisecondsSinceEpoch}',
        name: c.name,
        phone: c.phone,
        relationship: c.relationship,
        fcmToken: c.fcmToken,
      );
      final idx = _demoContacts.indexWhere((item) => item.id == local.id || item.phone == local.phone);
      if (idx == -1) {
        _demoContacts.add(local);
      } else {
        _demoContacts[idx] = local;
      }
      _emitDemoContacts();
      return;
    }

    try {
      await _contacts.add(c.toMap());
    } catch (error) {
      if (!_isPermissionError(error)) rethrow;
      _useDemoData = true;
      final local = EmergencyContact(
        id: c.id.isNotEmpty ? c.id : 'local-${DateTime.now().millisecondsSinceEpoch}',
        name: c.name,
        phone: c.phone,
        relationship: c.relationship,
        fcmToken: c.fcmToken,
      );
      final idx = _demoContacts.indexWhere((item) => item.id == local.id || item.phone == local.phone);
      if (idx == -1) {
        _demoContacts.add(local);
      } else {
        _demoContacts[idx] = local;
      }
      _emitDemoContacts();
    }
  }

  Future<void> updateContact(EmergencyContact c) async {
    if (_useDemoData) {
      final idx = _demoContacts.indexWhere((item) => item.id == c.id);
      if (idx == -1) {
        _demoContacts.add(c);
      } else {
        _demoContacts[idx] = c;
      }
      _emitDemoContacts();
      return;
    }

    try {
      await _contacts.doc(c.id).update(c.toMap());
    } catch (error) {
      if (!_isPermissionError(error)) rethrow;
      _useDemoData = true;
      final idx = _demoContacts.indexWhere((item) => item.id == c.id);
      if (idx == -1) {
        _demoContacts.add(c);
      } else {
        _demoContacts[idx] = c;
      }
      _emitDemoContacts();
    }
  }

  Future<void> deleteContact(String id) async {
    if (_useDemoData) {
      _demoContacts.removeWhere((item) => item.id == id);
      _emitDemoContacts();
      return;
    }

    try {
      await _contacts.doc(id).delete();
    } catch (error) {
      if (!_isPermissionError(error)) rethrow;
      _useDemoData = true;
      _demoContacts.removeWhere((item) => item.id == id);
      _emitDemoContacts();
    }
  }

  // ---------------- Vitals ----------------

  Future<void> pushVitals({
    required double heartRate,
    required double accelMagnitude,
    required double battery,
  }) {
    if (_useDemoData) return Future.value();
    return _db
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
    if (_useDemoData) return 'demo-alert-${DateTime.now().millisecondsSinceEpoch}';
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
    if (_useDemoData) return Future.value();
    return _db
        .collection('users')
        .doc(uid)
        .collection('alerts')
        .doc(alertId)
        .update({'status': status.name});
  }

  Future<void> markContactsNotified(String alertId, List<String> ids) {
    if (_useDemoData) return Future.value();
    return _db
        .collection('users')
        .doc(uid)
        .collection('alerts')
        .doc(alertId)
        .update({'notifiedContactIds': ids});
  }

  Stream<List<SafetyAlert>> watchAlerts() {
    if (_useDemoData) return Stream.value(const []);
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

  // ---------------- Simulated ESP32 wearable (Wokwi) ----------------
  //
  // Separate top-level collection, not nested under a specific user,
  // because the simulated device authenticates as its own anonymous
  // Firebase user (see the Wokwi sketch) and doesn't know the app
  // user's uid. This is the SAME Firestore project/database as the
  // rest of the app — no new backend is introduced. See firestore.rules
  // for the matching read/write rule.

  /// Streams the latest simulated reading for [deviceId]
  /// (default `safeher-01`), or null if it does not exist yet.
  Stream<EspSensorReading?> watchDeviceSensor(
      {String deviceId = 'safeher-01'}) {
    return _db
        .collection('sensor_readings')
        .doc(deviceId)
        .snapshots()
        .map((doc) => doc.data() == null
            ? null
            : EspSensorReading.fromMap(
                doc.data()!,
                receivedAt: DateTime.now(),
              ));
  }

  // ---------------- Settings ----------------

  Future<void> updateSettings(Map<String, dynamic> settings) async {
    if (_useDemoData) {
      _demoSettings.clear();
      _demoSettings.addAll(Map<String, dynamic>.from(settings));
      _emitDemoSettings();
      return;
    }

    try {
      await _db.collection('users').doc(uid).set(
        {'settings': settings},
        SetOptions(merge: true),
      );
    } catch (error) {
      if (!_isPermissionError(error)) rethrow;
      _useDemoData = true;
      _demoSettings.clear();
      _demoSettings.addAll(Map<String, dynamic>.from(settings));
      _emitDemoSettings();
    }
  }

  Stream<Map<String, dynamic>> watchSettings() {
    if (_useDemoData) {
      _emitDemoSettings();
      return _demoSettingsController.stream;
    }

    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((d) => Map<String, dynamic>.from(d.data()?['settings'] ?? {}))
        .handleError((error) {
          if (_isPermissionError(error)) {
            _useDemoData = true;
            return Map<String, dynamic>.from(_demoSettings);
          }
          throw error;
        });
  }
}
