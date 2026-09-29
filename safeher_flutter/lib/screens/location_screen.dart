import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/alert_model.dart';
import '../services/alert_service.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});
  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  final _loc = LocationService();
  final _firebase = FirebaseService.instance;
  Position? _pos;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    final position = await _loc.getCurrentPosition();
    if (mounted) setState(() => _pos = position);
  }

  Future<void> _shareLocation() async {
    if (_sharing) return;
    setState(() => _sharing = true);

    final current = await _loc.getCurrentPosition();
    if (!mounted) return;
    if (current == null) {
      setState(() => _sharing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Current location is unavailable.')),
        );
      }
      return;
    }

    setState(() => _pos = current);
    final contacts = await _firebase.watchContacts().first;
    if (contacts.isEmpty) {
      setState(() => _sharing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add an emergency contact first.')),
      );
      return;
    }

    try {
      await AlertService(_firebase, _loc).triggerAlert(
        source: AlertSource.location,
        contacts: contacts,
        autoCall: false,
        notifyAuthorities: false,
        latitude: current.latitude,
        longitude: current.longitude,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Current location sent to ${contacts.first.name}.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _callEmergency() async {
    final phone = Uri(scheme: 'tel', path: '119');
    if (await canLaunchUrl(phone)) {
      await launchUrl(phone);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Calling is not available in this browser.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lat = _pos?.latitude.toStringAsFixed(6) ?? '—';
    final lng = _pos?.longitude.toStringAsFixed(6) ?? '—';
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Live Tracking',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: colors.onSurface)),
                const SizedBox(height: 4),
                const Row(children: [
                  Icon(Icons.circle, size: 10, color: AppColors.green),
                  SizedBox(width: 6),
                  Text('Live Tracking Active',
                      style: TextStyle(
                          color: AppColors.green, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 12),
                Container(
                  height: 220,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Center(
                    child:
                        Icon(Icons.navigation, size: 44, color: colors.primary),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Emergency Tracking',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: colors.onSurface)),
                        const Text('Location shared with your contacts',
                            style: TextStyle(
                                color: AppColors.muted, fontSize: 12)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                              color: colors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(10)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Lat: $lat',
                                  style: TextStyle(
                                      fontSize: 12, color: colors.onSurface)),
                              Text('Lng: $lng',
                                  style: TextStyle(
                                      fontSize: 12, color: colors.onSurface)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.share),
                      label: Text(_sharing ? 'Sending...' : 'Share Location'),
                      onPressed: _sharing ? null : _shareLocation,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.red),
                      icon: const Icon(Icons.call),
                      label: const Text('Call 119'),
                      onPressed: _callEmergency,
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
