import 'package:flutter/material.dart';

class VitalsRow extends StatelessWidget {
  const VitalsRow({
    super.key,
    required this.heartRate,
    required this.battery,
    required this.connected,
  });

  final double heartRate;
  final double battery;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _tile(context, '❤️ ${heartRate.toStringAsFixed(0)}', 'Normal'),
        const SizedBox(width: 10),
        _tile(context, '🔋 ${battery.toStringAsFixed(0)}%', 'Wearable'),
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
