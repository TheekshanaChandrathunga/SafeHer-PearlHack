import 'package:flutter/material.dart';

class VitalsRow extends StatelessWidget {
  const VitalsRow({
    super.key,
    required this.heartRate,
    required this.battery,
    required this.connected,
    this.movementLabel,
    this.simulated = false,
  });

  final double heartRate;
  final double battery;
  final bool connected;

  /// Optional: current movement state from the simulated ESP32
  /// wearable ('Normal' / 'Unusual' / 'Inactive'). When null, the
  /// battery tile is shown as before (local demo mode).
  final String? movementLabel;

  /// True once a reading has actually been received from the
  /// simulated Wokwi ESP32 device (as opposed to the phone's own
  /// on-device demo generator).
  final bool simulated;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _tile(context, '❤️ ${heartRate.toStringAsFixed(0)}', 'Normal'),
        const SizedBox(width: 10),
        movementLabel == null
            ? _tile(context, '🔋 ${battery.toStringAsFixed(0)}%', 'Wearable')
            : _tile(context, '🏃 $movementLabel',
                simulated ? 'Movement (simulated)' : 'Movement'),
        const SizedBox(width: 10),
        _tile(context, '📶', connected ? 'Connected' : 'Offline',
            color: connected ? Colors.green : Colors.grey),
      ],
    );
  }

  Widget _tile(BuildContext ctx, String value, String label, {Color? color}) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 11, color: color ?? Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
