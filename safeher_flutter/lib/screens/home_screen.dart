import 'package:flutter/material.dart';
import '../models/alert_model.dart';
import '../models/contact_model.dart';
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
  final bool _connected = true;
  bool _dialogShowing = false;

  @override
  void initState() {
    super.initState();
    _ai = AIDetectionService(onDistress: _onAIDistress);
    _ai.start();
    _ai.stream.listen((VitalsReading r) {
      setState(() => _hr = r.heartRate);
      _fb.pushVitals(
        heartRate: r.heartRate,
        accelMagnitude: r.accelMagnitude,
        battery: _battery,
      );
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
      if (_dialogShowing) {
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          children: [
            VitalsRow(heartRate: _hr, battery: _battery, connected: _connected),
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
                    child:
                        _actionTile(Icons.phone_in_talk, 'Fake call', () {})),
                const SizedBox(width: 10),
                Expanded(
                    child: _actionTile(
                        Icons.location_on, 'Share Location', () {})),
              ],
            ),
            const SizedBox(height: 10),
            _actionTile(Icons.mic, 'Voice SOS',
                () => _openCountdown(AlertSource.voice)),
          ],
        ),
      ),
    );
  }

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
