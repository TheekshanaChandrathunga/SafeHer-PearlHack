import 'dart:async';
import 'package:flutter/material.dart';
import '../models/alert_model.dart';

class AlertCountdownScreen extends StatefulWidget {
  const AlertCountdownScreen(
      {super.key, required this.source, this.seconds = 5});
  final AlertSource source;
  final int seconds;

  @override
  State<AlertCountdownScreen> createState() => _AlertCountdownScreenState();
}

class _AlertCountdownScreenState extends State<AlertCountdownScreen> {
  late int _count = widget.seconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _count--);
      if (_count <= 0) {
        t.cancel();
        Navigator.pop(context, true);
      }
    });
  }

  String get _chipLabel {
    switch (widget.source) {
      case AlertSource.aiHeartRate:
      case AlertSource.aiMotion:
      case AlertSource.aiFall:
        return 'AI detected distress';
      case AlertSource.voice:
        return 'Voice SOS triggered';
      case AlertSource.location:
        return 'Location sharing triggered';
      case AlertSource.manual:
        return 'Manual SOS triggered';
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDC2626),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 16,
              left: 20,
              child: Chip(
                label: Text(_chipLabel,
                    style: const TextStyle(color: Colors.white)),
                backgroundColor: Colors.white24,
              ),
            ),
            Positioned(
              top: 12,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context, false),
                style: IconButton.styleFrom(backgroundColor: Colors.white24),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 130,
                    height: 130,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: Colors.white24),
                    child: const Icon(Icons.warning_amber_rounded,
                        color: Colors.white, size: 52),
                  ),
                  const SizedBox(height: 16),
                  const Text('Emergency Alert',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800)),
                  const Text('Sending alert in...',
                      style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 18),
                  Container(
                    width: 170,
                    height: 170,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white38, width: 6),
                    ),
                    child: Text('$_count',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 60,
                            fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 16),
                  const Text('Tap the ✕ button to cancel',
                      style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 20),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFDC2626),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed: () {
                      _timer?.cancel();
                      Navigator.pop(context, true);
                    },
                    child: const Text('Send Alert Now',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
