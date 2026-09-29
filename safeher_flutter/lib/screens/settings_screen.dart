import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _keys = {
    'soundAlert': ('Sound Alert', 'Play loud siren when SOS triggered', Icons.notifications_active),
    'autoCall': ('Auto Call', 'Automatically call first emergency contact', Icons.call),
    'shareLocation': ('Share Location', 'Include live location in alert message', Icons.location_on),
    'notifyAuthorities': ('Notify Authorities', 'Alert local emergency services', Icons.shield),
    'autoNightMode': ('Auto Night Mode', 'Enable after sunset', Icons.nightlight_round),
  };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<Map<String, dynamic>>(
        stream: FirebaseService.instance.watchSettings(),
        builder: (context, snap) {
          final settings = snap.data ?? {};
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              ThemeController.instance.applySettings(settings);
            }
          });
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Alert Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              ..._keys.entries.map((e) {
                final (title, desc, icon) = e.value;
                final val = settings[e.key] ?? true;
                return Card(
                  child: SwitchListTile(
                    secondary: Icon(icon),
                    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(desc, style: const TextStyle(fontSize: 12)),
                    value: val,
                    onChanged: (v) {
                      final next = Map<String, dynamic>.from(settings)..[e.key] = v;
                      ThemeController.instance.applySettings(next);
                      FirebaseService.instance.updateSettings(next);
                    },
                  ),
                );
              }),
              const SizedBox(height: 16),
              const Text('Wearable Device', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Card(
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: Color(0xFFC9F7D8), child: Icon(Icons.watch, color: Colors.green)),
                  title: Text('Safety Band Pro'),
                  subtitle: Text('Connected', style: TextStyle(color: Colors.green)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
