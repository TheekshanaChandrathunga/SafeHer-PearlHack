import 'dart:async';
import 'package:flutter/material.dart';
import '../models/alert_model.dart';
import '../models/sensor_reading_model.dart';
import '../models/vitals_model.dart';
import '../services/ai_detection_service.dart';
import '../services/alert_service.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import '../widgets/sos_button.dart';
import '../widgets/vitals_card.dart';
import 'alert_countdown_screen.dart';
import 'alert_sent_screen.dart';
import 'fake_call_screen.dart';
import 'voice_sos_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _fb = FirebaseService.instance;
  late final AlertService _alertService = AlertService(_fb, LocationService());
  late final AIDetectionService _ai;

  double _hr = 78;
  final double _battery = 76;
  bool _dialogShowing = false;

  // ---- Simulated Wokwi ESP32 wearable (Firestore: sensor_readings/safeher-01) ----
  StreamSubscription<EspSensorReading?>? _espSub;
  EspSensorReading? _espReading;
  int _espConsecutiveRisk = 0;
  DateTime? _espCooldownUntil;
  static const _espStaleAfter = Duration(seconds: 10);
  static const _espRiskPersistReadings = 2; // avoid firing on one noisy tick
  static const _espCooldown = Duration(seconds: 30);
  static const _espHighHeartRateThreshold = 120.0;

  bool get _espConnected =>
      _espReading != null && !_espReading!.isStale(_espStaleAfter);

  /// Prefer the live simulated-hardware reading once it's flowing;
  /// otherwise fall back to the phone's own on-device demo generator
  /// so the existing "Simulate AI Alert" button keeps working.
  double get _displayHr => _espConnected ? _espReading!.heartRate : _hr;

  @override
  void initState() {
    super.initState();
    _ai = AIDetectionService(onDistress: _onAIDistress);
    _ai.start();
    _ai.stream.listen((VitalsReading r) {
      if (!mounted) return;
      setState(() => _hr = r.heartRate);
      _fb.pushVitals(
        heartRate: r.heartRate,
        accelMagnitude: r.accelMagnitude,
        battery: _battery,
      );
    });
    _espSub = _fb.watchDeviceSensor().listen(_onEspReading);
  }

  /// Handles each new reading from the simulated ESP32. Requires the
  /// risk flag to persist for [_espRiskPersistReadings] consecutive
  /// updates (debounce) and enforces a cooldown after an alert is
  /// raised, so a single noisy tick or a resolved alert doesn't spam
  /// the "Are you okay?" prompt.
  void _onEspReading(EspSensorReading? r) {
    if (!mounted) return;
    setState(() => _espReading = r);
    if (r == null) return;

    final highHeartRate = r.heartRate >= _espHighHeartRateThreshold;
    final riskDetected = r.riskDetected || highHeartRate;
    _espConsecutiveRisk = riskDetected ? _espConsecutiveRisk + 1 : 0;

    final inCooldown = _espCooldownUntil != null &&
        DateTime.now().isBefore(_espCooldownUntil!);
    if (_dialogShowing || inCooldown) return;

    if (_espConsecutiveRisk >= _espRiskPersistReadings) {
      _espConsecutiveRisk = 0;
      _onEspDistress(r);
    }
  }

  void _onEspDistress(EspSensorReading r) {
    _dialogShowing = true;
    _espCooldownUntil = DateTime.now().add(_espCooldown);
    final source = (r.riskReason == 'unusual_movement' ||
            r.riskReason == 'prolonged_inactivity')
        ? AlertSource.aiMotion
        : AlertSource.aiHeartRate;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Are You Okay?'),
        content: Text(
            'Simulated wearable (ESP32) noticed: ${r.riskReason.replaceAll('_', ' ')}\n'
            'Heart rate: ${r.heartRate.toStringAsFixed(0)} bpm · Movement: ${r.movement}'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _dialogShowing = false;
            },
            child: const Text("Yes, I'm Okay"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () {
              Navigator.pop(ctx);
              _dialogShowing = false;
              _openCountdown(source);
            },
            child: const Text('No, I need help'),
          ),
        ],
      ),
    );
    // Same 10s no-response fallback as the on-device AI prompt.
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _dialogShowing) {
        Navigator.of(context, rootNavigator: true).pop();
        _dialogShowing = false;
        _openCountdown(source);
      }
    });
  }

  /// Fired automatically by [AIDetectionService] once a sustained
  /// anomaly crosses the critical threshold — this is the "Are you
  /// okay?" prompt from the proposal.
  void _onAIDistress(DistressResult result) {
    if (_dialogShowing) return;
    _dialogShowing = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Critical Situation Detected'),
        content: Text('Are you safe?\nAI noticed: ${result.reason}'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _dialogShowing = false;
            },
            child: const Text("Yes, I'm Okay"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () {
              Navigator.pop(ctx);
              _dialogShowing = false;
              _openCountdown(AlertSource.aiHeartRate);
            },
            child: const Text('No, I need help'),
          ),
        ],
      ),
    );
    // If the user doesn't respond within 10s, treat it as "no answer"
    // and escalate automatically — matches the proposal's requirement
    // that fear/shock shouldn't block a response.
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _dialogShowing) {
        Navigator.of(context, rootNavigator: true).pop();
        _dialogShowing = false;
        _openCountdown(AlertSource.aiHeartRate);
      }
    });
  }

  Future<void> _openCountdown(AlertSource source) async {
    final confirmed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AlertCountdownScreen(source: source)),
    );
    if (confirmed == true) {
      final contacts = await _fb.watchContacts().first;
      final settings = await _fb.watchSettings().first;
      final alertId = await _alertService.triggerAlert(
        source: source,
        contacts: contacts,
        autoCall: settings['autoCall'] ?? true,
        notifyAuthorities: settings['notifyAuthorities'] ?? true,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AlertSentScreen(
              alertId: alertId, contacts: contacts.take(3).toList()),
        ),
      );
    }
  }

  @override
  void dispose() {
    _ai.dispose();
    _espSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          children: [
            VitalsRow(
              heartRate: _displayHr,
              battery: _battery,
              connected: _espReading == null ? true : _espConnected,
              heartRateAlert: _espConnected &&
                  _espReading!.heartRate >= _espHighHeartRateThreshold,
              movementLabel: _espReading == null
                  ? null
                  : _capitalize(_espReading!.movement),
              simulated: _espReading?.simulated ?? false,
            ),
            if (_espReading != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _espConnected
                      ? 'Live simulated ESP32 sensor (Wokwi) — not a real wearable'
                      : 'Simulated ESP32 sensor offline — showing last known reading',
                  style: TextStyle(
                    fontSize: 11,
                    color: _espConnected ? AppColors.muted : AppColors.red,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 20),
            Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                    colors: [Color(0xFF3EE06B), Color(0xFF16A34A)]),
              ),
              child: const Icon(Icons.shield, color: Colors.white, size: 52),
            ),
            const SizedBox(height: 12),
            const Text("You're Safe",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const Text('AI is monitoring your vitals',
                style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 24),
            SosButton(onTriggered: () => _openCountdown(AlertSource.manual)),
            const SizedBox(height: 12),
            const Text('Hold for 3 seconds to trigger alert',
                style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _ai.triggerSimulatedSpike,
              icon: const Icon(Icons.bolt),
              label: const Text('Simulate AI Alert'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _actionTile(
                        Icons.phone_in_talk,
                        'Fake call',
                        () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const FakeCallScreen()),
                            ))),
                const SizedBox(width: 10),
                Expanded(
                    child: _actionTile(
                        Icons.location_on, 'Share Location', _shareLocation)),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: _actionTile(
                  Icons.mic,
                  'Voice SOS',
                  () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const VoiceSosScreen()),
                      )),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareLocation() async {
    final position = await LocationService().getCurrentPosition();
    if (!mounted) return;
    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Location permission or GPS is unavailable.')),
      );
      return;
    }

    final contacts = await _fb.watchContacts().first;
    if (!mounted) return;
    if (contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add an emergency contact first.')),
      );
      return;
    }

    await AlertService(_fb, LocationService()).triggerAlert(
      source: AlertSource.location,
      contacts: contacts,
      autoCall: false,
      notifyAuthorities: false,
      latitude: position.latitude,
      longitude: position.longitude,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location sent to ${contacts.first.name}.')),
      );
    }
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  Widget _actionTile(IconData icon, String label, VoidCallback onTap) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: AppColors.purple),
              const SizedBox(height: 6),
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
