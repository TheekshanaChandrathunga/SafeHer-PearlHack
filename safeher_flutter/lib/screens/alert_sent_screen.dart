import 'package:flutter/material.dart';
import '../models/contact_model.dart';
import '../services/alert_service.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import 'location_screen.dart';

class AlertSentScreen extends StatelessWidget {
  const AlertSentScreen({super.key, required this.alertId, required this.contacts});
  final String alertId;
  final List<EmergencyContact> contacts;

  @override
  Widget build(BuildContext context) {
    final alertService = AlertService(FirebaseService.instance, LocationService());
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.green),
                child: const Icon(Icons.check, color: Colors.white, size: 44),
              ),
              const SizedBox(height: 14),
              const Text('Alert Sent Successfully',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const Text('Help is on the way. Stay calm.', style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 16),
              ...contacts.map((c) => Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Text(c.name.isNotEmpty ? c.name[0] : '?')),
                      title: Text(c.name),
                      subtitle: Text(c.relationship),
                      trailing: const Text('Notified ✓', style: TextStyle(color: AppColors.green)),
                    ),
                  )),
              Card(
                color: AppColors.pink2,
                child: const ListTile(
                  leading: Icon(Icons.shield, color: AppColors.purple2),
                  title: Text('Authorities Notified.'),
                  subtitle: Text('Emergency services alerted.'),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: AppColors.purple,
                ),
                icon: const Icon(Icons.location_on),
                label: const Text('View Live Tracking'),
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LocationScreen()),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                onPressed: () {
                  alertService.resolveAlert(alertId);
                  Navigator.popUntil(context, (r) => r.isFirst);
                },
                child: const Text('I AM SAFE NOW'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
