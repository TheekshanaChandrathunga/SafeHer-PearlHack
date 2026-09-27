import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SosButton extends StatefulWidget {
  const SosButton({
    super.key,
    required this.onTriggered,
    this.holdDuration = const Duration(seconds: 3),
  });

  final VoidCallback onTriggered;
  final Duration holdDuration;

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _holding = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.holdDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onTriggered();
          _reset();
        }
      });
  }

  void _start() {
    setState(() => _holding = true);
    _controller.forward(from: 0);
  }

  void _reset() {
    setState(() => _holding = false);
    _controller.reset();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _start(),
      onLongPressEnd: (_) => _reset(),
      onLongPressCancel: _reset,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xFFFF6B5E), Color(0xFFE11D1D)],
              ),
              boxShadow: _holding
                  ? [
                      BoxShadow(
                        color: AppColors.red.withOpacity(.5 * (1 - _controller.value)),
                        blurRadius: 30,
                        spreadRadius: 20 * _controller.value,
                      )
                    ]
                  : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 36),
                const SizedBox(height: 4),
                Text(
                  _holding ? 'HOLD...' : 'SOS',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
