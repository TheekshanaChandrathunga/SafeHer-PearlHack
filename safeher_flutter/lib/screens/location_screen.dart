import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});
  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  final _loc = LocationService();
  Position? _pos;

  @override
  void initState() {
    super.initState();
    _loc.getCurrentPosition().then((p) => setState(() => _pos = p));
  }

  @override
  Widget build(BuildContext context) {
    final lat = _pos?.latitude.toStringAsFixed(6) ?? '—';
    final lng = _pos?.longitude.toStringAsFixed(6) ?? '—';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Live Tracking', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Row(children: [
              Icon(Icons.circle, size: 10, color: AppColors.green),
              SizedBox(width: 6),
              Text('Live Tracking Active', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 12),
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: AppColors.pink2,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(child: Icon(Icons.navigation, size: 44, color: AppColors.purple)),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Emergency Tracking', style: TextStyle(fontWeight: FontWeight.w700)),
                    const Text('Location shared with your contacts', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(color: AppColors.pink, borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [Text('Lat: $lat', style: const TextStyle(fontSize: 12)), Text('Lng: $lng', style: const TextStyle(fontSize: 12))],
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
                  label: const Text('Share Link'),
                  onPressed: () {
                    if (_pos != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(_loc.mapsLink(_pos!.latitude, _pos!.longitude))),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.red),
                  icon: const Icon(Icons.call),
                  label: const Text('Call 119'),
                  onPressed: () => launchUrl(Uri(scheme: 'tel', path: '119')),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
