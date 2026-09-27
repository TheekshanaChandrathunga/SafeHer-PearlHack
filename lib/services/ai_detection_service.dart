import 'dart:async';
import 'dart:math';
import '../models/vitals_model.dart';

/// Simulates the on-wearable / on-device AI panic-detection pipeline
/// described in the proposal: it continuously ingests heart-rate and
/// motion (accelerometer) readings, keeps a rolling personal baseline,
/// and flags distress using three simple, explainable detectors —
/// exactly the kind of lightweight model that would run on an ESP32 /
/// phone in real time. Swap [_syntheticStream] for a real
/// sensors_plus / BLE stream to move from simulation to production.
class AIDetectionService {
  AIDetectionService({this.onDistress});

  /// Called once a distress episode crosses the critical threshold.
  final void Function(DistressResult result)? onDistress;

  final _readings = <VitalsReading>[];
  static const _baselineWindow = 20; // rolling window for the baseline
  static const _sustainedTicks = 3; // consecutive abnormal ticks required

  int _consecutiveAbnormal = 0;
  int _stillnessTicks = 0;
  bool _postSpike = false;

  Timer? _timer;
  final _controller = StreamController<VitalsReading>.broadcast();
  final _rand = Random();
  bool _forceSpike = false;

  Stream<VitalsReading> get stream => _controller.stream;

  void start({Duration tick = const Duration(seconds: 2)}) {
    _timer?.cancel();
    _timer = Timer.periodic(tick, (_) => _emit());
  }

  void stop() => _timer?.cancel();

  /// Lets the UI's "Simulate AI Alert" button inject a synthetic
  /// distress spike on the next tick, mirroring what an ESP32 wearable
  /// would report during a real panic event.
  void triggerSimulatedSpike() => _forceSpike = true;

  void _emit() {
    final reading = _syntheticStream();
    _readings.add(reading);
    if (_readings.length > 200) _readings.removeAt(0);
    _controller.add(reading);
    final result = _analyse(reading);
    if (result.level == DistressLevel.critical) {
      onDistress?.call(result);
      _consecutiveAbnormal = 0; // reset after firing
    }
  }

  VitalsReading _syntheticStream() {
    final now = DateTime.now();
    double hr = 72 + _rand.nextDouble() * 8; // resting baseline 72-80
    double accel = 9.7 + _rand.nextDouble() * 0.6; // ~gravity, resting

    if (_forceSpike) {
      hr = 140 + _rand.nextDouble() * 25; // panic-level spike
      accel = 22 + _rand.nextDouble() * 10; // sudden violent motion
      _forceSpike = false;
      _postSpike = true;
    } else if (_postSpike) {
      // After a struggle, a real attack scenario often shows a
      // "stillness after spike" pattern (dropped phone / incapacitated).
      accel = 0.2 + _rand.nextDouble() * 0.3;
      hr = 110 + _rand.nextDouble() * 15;
    }

    return VitalsReading(
      timestamp: now,
      heartRate: hr,
      accelMagnitude: accel,
      batteryPercent: 76,
    );
  }

  DistressResult _analyse(VitalsReading r) {
    final window = _readings.length > _baselineWindow
        ? _readings.sublist(_readings.length - _baselineWindow)
        : _readings;
    final baselineHr = window.map((e) => e.heartRate).reduce((a, b) => a + b) /
        window.length;
    final variance = window
            .map((e) => pow(e.heartRate - baselineHr, 2))
            .reduce((a, b) => a + b) /
        window.length;
    final stdDev = sqrt(variance);

    // --- Detector 1: abnormal heart-rate spike ---
    final hrThreshold = baselineHr + max(20, 2.5 * stdDev);
    final hrAnomaly = r.heartRate > hrThreshold;

    // --- Detector 2: sudden violent motion (struggle) ---
    final motionAnomaly = r.accelMagnitude > 18;

    // --- Detector 3: prolonged stillness right after a spike (possible
    // incapacitation / dropped device) ---
    if (r.accelMagnitude < 1.0) {
      _stillnessTicks++;
    } else {
      _stillnessTicks = 0;
    }
    final fallLikeStillness = _postSpike && _stillnessTicks >= 3;

    final anomalyNow = hrAnomaly || motionAnomaly || fallLikeStillness;
    _consecutiveAbnormal = anomalyNow ? _consecutiveAbnormal + 1 : 0;

    double score = 0;
    final reasons = <String>[];
    if (hrAnomaly) {
      score += 45;
      reasons.add('elevated heart rate (${r.heartRate.toStringAsFixed(0)} bpm)');
    }
    if (motionAnomaly) {
      score += 35;
      reasons.add('sudden violent motion detected');
    }
    if (fallLikeStillness) {
      score += 30;
      reasons.add('stillness after motion spike (possible fall)');
    }
    score = min(score, 100);

    DistressLevel level;
    if (_consecutiveAbnormal >= _sustainedTicks && score >= 60) {
      level = DistressLevel.critical;
      _postSpike = false;
      _stillnessTicks = 0;
    } else if (score >= 30) {
      level = DistressLevel.elevated;
    } else {
      level = DistressLevel.normal;
    }

    return DistressResult(
      level,
      score,
      reasons.isEmpty ? 'within normal range' : reasons.join(', '),
    );
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}
