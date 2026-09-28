import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class FakeCallScreen extends StatefulWidget {
  const FakeCallScreen({super.key});

  @override
  State<FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen> {
  Timer? _timer;
  bool _connected = false;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _startCallTimer();
  }

  void _startCallTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  String get _duration {
    final minutes = (_seconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF17111B),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            const CircleAvatar(
              radius: 58,
              backgroundColor: AppColors.purple,
              child: Icon(Icons.person, color: Colors.white, size: 64),
            ),
            const SizedBox(height: 20),
            Text(
              _connected ? 'Connected' : 'Incoming call',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Mum',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _connected ? _duration : 'SafeHer emergency contact',
              style: const TextStyle(color: Colors.white60, fontSize: 15),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (!_connected)
                  _CallAction(
                    icon: Icons.call,
                    label: 'Answer',
                    color: Colors.green,
                    onPressed: () => setState(() => _connected = true),
                  ),
                _CallAction(
                  icon: Icons.call_end,
                  label: _connected ? 'End call' : 'Dismiss',
                  color: Colors.red,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 44),
          ],
        ),
      ),
    );
  }
}

class _CallAction extends StatelessWidget {
  const _CallAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FloatingActionButton(
          heroTag: label,
          backgroundColor: color,
          onPressed: onPressed,
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}
