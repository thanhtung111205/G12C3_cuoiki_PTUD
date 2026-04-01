import 'dart:async';
import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

class ShakeDetector {
  final double shakeThresholdGravity;
  final Duration debounceDuration;
  final Duration shakeWindow; // window to count peaks
  final int shakeCount; // how many peaks within window to consider a shake
  final bool Function()? isLocked;

  StreamSubscription<AccelerometerEvent>? _sub;
  final StreamController<void> _onShakeController = StreamController.broadcast();
  final StreamController<void> _onIgnoredShakeController = StreamController.broadcast();

  DateTime? _lastShakeAt;
  final List<DateTime> _peakTimestamps = [];

  ShakeDetector({
    this.shakeThresholdGravity = 3.0,
    this.debounceDuration = const Duration(milliseconds: 800),
    this.shakeWindow = const Duration(milliseconds: 700),
    this.shakeCount = 2,
    this.isLocked,
  });

  Stream<void> get onShake => _onShakeController.stream;
  Stream<void> get onIgnoredShake => _onIgnoredShakeController.stream;

  void startListening() {
    stopListening();
    // use sensors_plus accelerometerEvents
    _sub = accelerometerEvents.listen((event) {
      _onAccelerometerEvent(event);
    });
  }

  void _onAccelerometerEvent(AccelerometerEvent event) {
    // Compute g-force (magnitude) from x,y,z
    final gX = event.x / 9.80665;
    final gY = event.y / 9.80665;
    final gZ = event.z / 9.80665;
    final gForce = sqrt(gX * gX + gY * gY + gZ * gZ);

    final now = DateTime.now();

    if (gForce > shakeThresholdGravity) {
      _peakTimestamps.add(now);
      // prune old peaks outside the window
      _peakTimestamps.removeWhere((t) => now.difference(t) > shakeWindow);

      // if we have enough peaks and debounce passed, trigger
      if (_peakTimestamps.length >= shakeCount) {
        if (_lastShakeAt == null || now.difference(_lastShakeAt!) > debounceDuration) {
          if (isLocked?.call() == true) {
            _onIgnoredShakeController.add(null);
          } else {
            _lastShakeAt = now;
            // Emit event
            _onShakeController.add(null);
          }
          // clear peaks to avoid immediate repeat
          _peakTimestamps.clear();
        }
      }
    }
  }

  void stopListening() {
    _sub?.cancel();
    _sub = null;
  }

  void dispose() {
    stopListening();
    _onShakeController.close();
    _onIgnoredShakeController.close();
  }
}
