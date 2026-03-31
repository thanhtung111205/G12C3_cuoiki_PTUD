import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// ShakeDetector - listens to accelerometer events and emits a simple "shake" event
/// when the acceleration exceeds a threshold. Includes debounce to prevent
/// multiple triggers in quick succession and requires multiple peaks within a
/// short window to reduce false positives.
class ShakeDetector {
  final double shakeThresholdGravity;
  final Duration debounceDuration;
  final Duration shakeWindow; // window to count peaks
  final int shakeCount; // how many peaks within window to consider a shake

  StreamSubscription<AccelerometerEvent>? _sub;
  final StreamController<void> _onShakeController = StreamController.broadcast();

  DateTime? _lastShakeAt;
  final List<DateTime> _peakTimestamps = [];

  ShakeDetector({
    this.shakeThresholdGravity = 3.0,
    this.debounceDuration = const Duration(seconds: 1),
    this.shakeWindow = const Duration(milliseconds: 700),
    this.shakeCount = 2,
  });

  Stream<void> get onShake => _onShakeController.stream;

  void startListening() {
    stopListening();
    _sub = accelerometerEvents.listen(_onAccelerometerEvent);
  }

  void _onAccelerometerEvent(AccelerometerEvent event) {
    // Compute g-force (magnitude) from x,y,z
    final gX = event.x / 9.80665;
    final gY = event.y / 9.80665;
    final gZ = event.z / 9.80665;
    final gForce = sqrt(gX * gX + gY * gY + gZ * gZ);

    final now = DateTime.now();

    if (gForce > shakeThresholdGravity) {
      // record this peak
      _peakTimestamps.add(now);
      // prune old peaks outside the window
      _peakTimestamps.removeWhere((t) => now.difference(t) > shakeWindow);

      // if we have enough peaks and debounce passed, trigger
      if (_peakTimestamps.length >= shakeCount) {
        if (_lastShakeAt == null || now.difference(_lastShakeAt!) > debounceDuration) {
          _lastShakeAt = now;
          // Haptic feedback
          HapticFeedback.mediumImpact();
          // Emit event
          _onShakeController.add(null);
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
  }
}
